import Foundation
import HECore

#if canImport(HealthKit)
import HealthKit
#endif

/// Errors surfaced by the HealthKit bridge.
public enum HealthKitError: Error, Sendable, CustomStringConvertible {
    /// HealthKit is not available on this device/platform (e.g. iPad, simulator
    /// without Health, or a non-Apple build).
    case unavailable
    /// Authorization has not been granted for the requested types.
    case notAuthorized
    /// A required `HKObjectType` could not be constructed.
    case typeUnavailable

    public var description: String {
        switch self {
        case .unavailable: return "HealthKit is not available on this device."
        case .notAuthorized: return "HealthKit access has not been authorized."
        case .typeUnavailable: return "A required HealthKit type was unavailable."
        }
    }
}

#if canImport(HealthKit)

/// Bridges Heartelfie readings to and from Apple HealthKit.
///
/// **Read** scope: heart rate, HRV (SDNN), resting heart rate, blood oxygen,
/// respiratory rate, and (as optional, supplementary context) the availability of
/// Apple Watch ECG samples.
///
/// **Write** scope: heart rate, HRV (SDNN), blood oxygen, respiratory rate only.
///
/// - Important: Heartelfie's custom waveforms and device-only metrics (hemoglobin,
///   anemia risk, perfusion index, hydration, beat timing, rhythm-irregularity %,
///   murmur flag) are **not** representable as standard HealthKit sample types and
///   are therefore never written to HealthKit — they live only in the encrypted
///   on-device store. ``write(reading:)`` silently skips them.
///
/// `@MainActor` because `HKHealthStore` callbacks and authorization UI are
/// main-actor friendly and we keep all access serialised there.
@MainActor
public final class HealthKitBridge {

    private let store = HKHealthStore()

    public init() {}

    // MARK: - Type sets

    /// Quantity types Heartelfie reads from HealthKit.
    public static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let t = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { types.insert(t) }
        // Apple Watch ECG (supplementary context only).
        if #available(iOS 14.0, *) {
            types.insert(HKObjectType.electrocardiogramType())
        }
        return types
    }

    /// Quantity types Heartelfie writes to HealthKit (a strict subset of reads).
    public static var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        if let t = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { types.insert(t) }
        return types
    }

    // MARK: - Authorization

    /// Requests read + write authorization for the supported types.
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
    }

    // MARK: - Reads

    /// Most recent heart-rate sample, in bpm.
    public func latestHeartRate() async -> Double? {
        await latestQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    /// HRV (SDNN) samples over the last `days` days as a trend series, in ms.
    public func recentHRV(days: Int) async -> [TimeSeriesPoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        let unit = HKUnit.secondUnit(with: .milli)
        return await timeSeries(type, unit: unit, days: days)
    }

    /// Most recent resting heart rate, in bpm.
    public func restingHeartRate() async -> Double? {
        await latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    /// Most recent blood-oxygen sample, as a percentage (0–100).
    public func latestBloodOxygen() async -> Double? {
        // HealthKit stores oxygen saturation as a 0...1 fraction; surface as %.
        guard let fraction = await latestQuantity(.oxygenSaturation, unit: .percent()) else { return nil }
        return fraction * 100.0
    }

    /// Most recent respiratory rate, in breaths/min.
    public func latestRespiratoryRate() async -> Double? {
        await latestQuantity(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    /// Whether any Apple Watch ECG samples are available (supplementary context).
    public func appleWatchECGAvailable() async -> Bool {
        guard #available(iOS 14.0, *) else { return false }
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let type = HKObjectType.electrocardiogramType()
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples?.isEmpty == false))
            }
            store.execute(query)
        }
    }

    // MARK: - Writes

    /// Writes the HealthKit-supported sample types contained in `reading`
    /// (heart rate, HRV SDNN, blood oxygen, respiratory rate). Device-only and
    /// custom metrics (hemoglobin, waveforms, etc.) are silently skipped because
    /// HealthKit has no standard type for them.
    public func write(reading: CardioReading) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }

        var samples: [HKSample] = []
        for metric in reading.metrics {
            if let sample = Self.makeSample(metric: metric, timestamp: reading.timestamp) {
                samples.append(sample)
            }
        }
        guard !samples.isEmpty else { return }
        try await store.save(samples)
    }

    /// Maps a single ``CardioMetric`` to an `HKQuantitySample`, or `nil` if the
    /// metric has no HealthKit-writable counterpart. Performs unit conversions
    /// from Heartelfie's units to HealthKit's expected units.
    private static func makeSample(metric: CardioMetric, timestamp: Date) -> HKQuantitySample? {
        switch metric.kind {
        case .heartRate:
            guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
            let unit = HKUnit.count().unitDivided(by: .minute())
            return quantitySample(type: type, unit: unit, value: metric.value, date: timestamp)

        case .hrvSDNN:
            guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
            // Heartelfie stores SDNN in ms; HealthKit expects time (use ms unit).
            let unit = HKUnit.secondUnit(with: .milli)
            return quantitySample(type: type, unit: unit, value: metric.value, date: timestamp)

        case .spo2Estimate, .spo2Clinical:
            guard let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return nil }
            // Heartelfie stores % (0–100); HealthKit expects a 0...1 fraction.
            let unit = HKUnit.percent()
            return quantitySample(type: type, unit: unit, value: metric.value / 100.0, date: timestamp)

        case .respiratoryRate:
            guard let type = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
            let unit = HKUnit.count().unitDivided(by: .minute())
            return quantitySample(type: type, unit: unit, value: metric.value, date: timestamp)

        // No standard HealthKit type — kept only in the encrypted store.
        case .hrvRMSSD, .rhythmIrregularity, .hemoglobin, .anemiaRisk,
             .perfusionIndex, .hydration:
            return nil
        }
    }

    private static func quantitySample(
        type: HKQuantityType,
        unit: HKUnit,
        value: Double,
        date: Date
    ) -> HKQuantitySample {
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        return HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
    }

    // MARK: - Query helpers

    /// Latest single sample's value for a quantity identifier in the given unit.
    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }

        return await withCheckedContinuation { continuation in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: sort
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    /// Trend series of a quantity type within the last `days` days, converted to
    /// `unit`. The `HKQuantitySample` values are reduced to Sendable
    /// `TimeSeriesPoint`s *inside* the query handler so no non-Sendable HealthKit
    /// objects cross back into the actor-isolated context.
    private func timeSeries(_ type: HKQuantityType, unit: HKUnit, days: Int) async -> [TimeSeriesPoint] {
        guard HKHealthStore.isHealthDataAvailable(), days > 0 else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])

        return await withCheckedContinuation { continuation in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { _, samples, _ in
                let points = (samples as? [HKQuantitySample] ?? []).map {
                    TimeSeriesPoint(date: $0.startDate, value: $0.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: points)
            }
            store.execute(query)
        }
    }
}

#else

// MARK: - Non-HealthKit stub (keeps the module compiling everywhere)

/// No-op ``HealthKitBridge`` for platforms without HealthKit. Every read returns
/// `nil`/empty and writes throw ``HealthKitError/unavailable`` so callers can
/// degrade gracefully. The public surface matches the real bridge exactly.
@MainActor
public final class HealthKitBridge {
    public init() {}

    public func requestAuthorization() async throws {
        throw HealthKitError.unavailable
    }

    public func latestHeartRate() async -> Double? { nil }
    public func recentHRV(days: Int) async -> [TimeSeriesPoint] { [] }
    public func restingHeartRate() async -> Double? { nil }
    public func latestBloodOxygen() async -> Double? { nil }
    public func latestRespiratoryRate() async -> Double? { nil }
    public func appleWatchECGAvailable() async -> Bool { false }

    public func write(reading: CardioReading) async throws {
        throw HealthKitError.unavailable
    }
}

#endif
