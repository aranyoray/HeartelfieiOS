import Foundation
import HECore
import HESignal

/// A fully synthetic stand-in for the real Heartelfie hardware peripheral.
///
/// `HeartelfieBLEManager` drives this instead of CoreBluetooth whenever it is
/// running simulated (developer "simulate device" toggle, or simply because the
/// Simulator has no Bluetooth). It reproduces the parts of the device the rest of
/// the app cares about:
///
/// * a multi-wavelength PPG stream (`.infrared`, `.infrared2`, `.red`),
/// * an ECG stream (`.ecg`),
/// * a bio-impedance stream (`.bioImpedance`),
/// * and the ambient device telemetry — connection progression, battery level,
///   firmware revision, and a realistic contact transition (`.poor` → `.good`).
///
/// All of the streams are produced from `HESignal.SyntheticSignal` so they are
/// deterministic and exercise the downstream DSP/SQI without any hardware.
///
/// In production the matching wiring lives behind the real GATT characteristics
/// declared in `HeartelfieConfig.BLE`; this type intentionally mirrors that shape
/// (one async stream per characteristic) so swapping in CoreBluetooth notifications
/// is a drop-in change.
actor MockHeartelfiePeripheral {

    /// Telemetry the manager republishes as a `DeviceState`.
    struct Telemetry: Sendable, Hashable {
        var connection: DeviceState.Connection
        var contact: DeviceState.Contact
        var batteryLevel: Double?
        var firmwareVersion: String?
        var deviceName: String?
    }

    // MARK: - Configuration

    /// Firmware revision the mock reports over the firmware characteristic.
    static let firmwareVersion = "1.4.2-sim"

    private let heartRateBPM: Double
    private let seed: UInt64

    // MARK: - Lifecycle state

    private var connectTask: Task<Void, Never>?
    private var contactTask: Task<Void, Never>?
    private var streamTasks: [Modality: Task<Void, Never>] = [:]

    /// Continuations for whoever is observing telemetry transitions.
    private var telemetryContinuations: [UUID: AsyncStream<Telemetry>.Continuation] = [:]

    /// Latest telemetry snapshot, replayed to new telemetry subscribers.
    private var latest = Telemetry(
        connection: .disconnected,
        contact: .unknown,
        batteryLevel: nil,
        firmwareVersion: nil,
        deviceName: HeartelfieConfig.deviceName
    )

    init(heartRateBPM: Double = 68, seed: UInt64 = 0xFE40_BEEF_CAFE_1234) {
        self.heartRateBPM = heartRateBPM
        self.seed = seed
    }

    // MARK: - Telemetry subscription

    /// A stream of telemetry transitions. The current snapshot is replayed first so
    /// late subscribers immediately observe the present state.
    func telemetryStream() -> AsyncStream<Telemetry> {
        // `makeStream` keeps the continuation registration under actor isolation.
        let id = UUID()
        let (stream, continuation) = AsyncStream<Telemetry>.makeStream()
        continuation.yield(latest)
        telemetryContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeTelemetryContinuation(id) }
        }
        return stream
    }

    private func removeTelemetryContinuation(_ id: UUID) {
        telemetryContinuations[id] = nil
    }

    private func publish(_ telemetry: Telemetry) {
        latest = telemetry
        for continuation in telemetryContinuations.values {
            continuation.yield(telemetry)
        }
    }

    // MARK: - Connection lifecycle

    /// Simulate the scan → connect → connected progression with a realistic contact
    /// settle. Mirrors what the BLE delegate callbacks would drive on real hardware.
    func startConnecting() {
        guard connectTask == nil else { return }
        connectTask = Task { [weak self] in
            guard let self else { return }
            await self.publish(Telemetry(
                connection: .scanning, contact: .unknown,
                batteryLevel: nil, firmwareVersion: nil,
                deviceName: HeartelfieConfig.deviceName
            ))
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }

            await self.publish(Telemetry(
                connection: .connecting, contact: .unknown,
                batteryLevel: nil, firmwareVersion: nil,
                deviceName: HeartelfieConfig.deviceName
            ))
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }

            // "Connected": battery + firmware become known, contact starts poor.
            await self.publish(Telemetry(
                connection: .connected, contact: .poor,
                batteryLevel: 0.82,
                firmwareVersion: MockHeartelfiePeripheral.firmwareVersion,
                deviceName: HeartelfieConfig.deviceName
            ))
            await self.startContactSettle()
        }
    }

    /// After connecting, contact realistically improves from `.poor` to `.good`
    /// once the user settles the finger/electrodes, then holds.
    private func startContactSettle() {
        contactTask?.cancel()
        contactTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            await self.updateContact(.good)
        }
    }

    private func updateContact(_ contact: DeviceState.Contact) {
        guard latest.connection == .connected else { return }
        publish(Telemetry(
            connection: latest.connection,
            contact: contact,
            batteryLevel: latest.batteryLevel,
            firmwareVersion: latest.firmwareVersion,
            deviceName: latest.deviceName
        ))
    }

    /// Tear everything down and report disconnected.
    func disconnect() {
        connectTask?.cancel(); connectTask = nil
        contactTask?.cancel(); contactTask = nil
        for task in streamTasks.values { task.cancel() }
        streamTasks.removeAll()
        publish(Telemetry(
            connection: .disconnected, contact: .unknown,
            batteryLevel: latest.batteryLevel, firmwareVersion: nil,
            deviceName: HeartelfieConfig.deviceName
        ))
    }

    // MARK: - Signal streams (one per device modality / GATT characteristic)

    /// Produce a synthetic frame stream for the given device modality. On real
    /// hardware this is fed by notifications on the matching characteristic in
    /// `HeartelfieConfig.BLE` (`ppgStreamCharacteristic` / `ecgStreamCharacteristic`
    /// / `bioZStreamCharacteristic`).
    func signalStream(for modality: Modality) -> AsyncStream<SignalFrame> {
        let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
        // Replace any prior stream task for this modality.
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runSignal(for: modality, into: continuation)
        }
        replaceStreamTask(task, for: modality)
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.cancelStreamTask(for: modality) }
        }
        return stream
    }

    private func replaceStreamTask(_ task: Task<Void, Never>, for modality: Modality) {
        streamTasks[modality]?.cancel()
        streamTasks[modality] = task
    }

    private func cancelStreamTask(for modality: Modality) {
        streamTasks[modality]?.cancel()
        streamTasks[modality] = nil
    }

    /// The actual synthetic-frame pump for one device modality. Generates a short
    /// buffer of samples at the modality's nominal rate, emits them in real time,
    /// then regenerates — looping until the stream is torn down.
    private func runSignal(
        for modality: Modality,
        into continuation: AsyncStream<SignalFrame>.Continuation
    ) async {
        let sampleRate = modality.nominalSampleRate
        let bufferSeconds = 1.0
        let framePeriodNS = UInt64(1_000_000_000 / max(sampleRate, 1))
        let epoch = Date().timeIntervalSince1970
        var sampleIndex = 0
        var batch = 0

        while !Task.isCancelled {
            // Vary the seed per batch so successive buffers don't repeat verbatim.
            let batchSeed = seed &+ (UInt64(truncatingIfNeeded: batch) &* 7919)
            let buffers = synthesize(
                modality: modality, durationSeconds: bufferSeconds,
                sampleRate: sampleRate, seed: batchSeed
            )
            let count = buffers.first?.values.count ?? 0

            for i in 0..<count {
                if Task.isCancelled { break }
                let timestamp = epoch + Double(sampleIndex) / sampleRate
                let samples = buffers.map {
                    SignalSample(timestamp: timestamp, value: $0.values[i], channel: $0.channel)
                }
                continuation.yield(SignalFrame(timestamp: timestamp, samples: samples))
                sampleIndex += 1
                try? await Task.sleep(nanoseconds: framePeriodNS)
            }
            batch += 1
        }
        continuation.finish()
    }

    /// Build the per-channel synthetic buffers for a device modality.
    private func synthesize(
        modality: Modality, durationSeconds: Double, sampleRate: Double, seed: UInt64
    ) -> [(channel: SignalChannel, values: [Double])] {
        switch modality {
        case .deviceMultiWavelengthPPG:
            // Multi-wavelength PPG: an IR base plus a second IR wavelength and a red
            // channel. The fixed inter-channel scaling yields a plausible
            // ratio-of-ratios for downstream SpO₂/hemoglobin estimation (computed
            // elsewhere — we only emit raw signal here).
            let ir = SyntheticSignal.ppg(
                durationSeconds: durationSeconds, sampleRate: sampleRate,
                heartRateBPM: heartRateBPM, hrvMS: 18, noise: 0.004,
                baselineWander: 0.03, seed: seed
            )
            let ir2 = ir.map { 0.94 * $0 }
            let red = ir.map { 0.78 * $0 }
            return [(.infrared, ir), (.infrared2, ir2), (.red, red)]

        case .deviceECG:
            let ecg = SyntheticSignal.ecg(
                durationSeconds: durationSeconds, sampleRate: sampleRate,
                heartRateBPM: heartRateBPM, hrvMS: 22, noise: 0.01,
                baselineWander: 0.02, seed: seed
            )
            return [(.ecg, ecg)]

        case .deviceBioZ:
            // BioZ varies slowly; model it as a near-DC impedance with a small
            // respiration-coupled ripple plus low noise around a baseline (ohms).
            let count = Int(durationSeconds * sampleRate)
            var rng = SeededGenerator(seed: seed)
            let baseline = 480.0
            var values = [Double](repeating: 0, count: max(count, 0))
            for i in 0..<values.count {
                let t = Double(i) / sampleRate
                let respiration = 6.0 * sin(2 * .pi * 0.25 * t)
                values[i] = baseline + respiration + 0.5 * rng.nextGaussian()
            }
            return [(.bioImpedance, values)]

        default:
            // Non-device modalities are not produced by the peripheral.
            return []
        }
    }
}
