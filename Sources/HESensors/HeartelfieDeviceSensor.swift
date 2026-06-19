import Foundation
import HECore
import HESignal

/// A `CardioSensor` backed by the connected Heartelfie hardware device.
///
/// Parameterized by a **device** modality (`.deviceMultiWavelengthPPG`,
/// `.deviceECG`, `.deviceBioZ`). It does not talk to CoreBluetooth itself — it
/// simply forwards frames from the shared `HeartelfieBLEManager.stream(for:)`,
/// which owns the GATT session described by `HeartelfieConfig.BLE`.
///
/// These modalities are clinical-grade `.measurement` and are the *only* legitimate
/// source of ECG, clinical SpO₂, and hemoglobin — never the phone.
public actor HeartelfieDeviceSensor: CardioSensor {

    public nonisolated let modality: Modality

    private let ble: HeartelfieBLEManager
    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var pumpTask: Task<Void, Never>?

    /// - Parameters:
    ///   - modality: a device modality. Passing a phone modality is a programmer
    ///     error; the sensor will simply produce no frames.
    ///   - ble: the shared BLE manager that owns the device session.
    public init(modality: Modality, ble: HeartelfieBLEManager) {
        precondition(modality.requiresDevice, "HeartelfieDeviceSensor requires a device modality")
        self.modality = modality
        self.ble = ble
    }

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        let modality = self.modality
        let ble = self.ble

        // `makeStream` hands back the continuation directly, so we assign it under
        // actor isolation rather than inside a `@Sendable` build closure.
        let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
        // Pull from the BLE manager's per-modality stream and forward frames.
        pumpTask = Task {
            let inner = await ble.stream(for: modality)
            for await frame in inner {
                continuation.yield(frame)
            }
            continuation.finish()
        }
        return stream
    }

    public func stop() async {
        pumpTask?.cancel()
        pumpTask = nil
        continuation?.finish()
        continuation = nil
    }
}

/// Simulator/no-hardware twin of `HeartelfieDeviceSensor`.
///
/// Emits synthetic frames for the given device modality directly via
/// `HESignal.SyntheticSignal`, in real time at the modality's nominal rate, with no
/// BLE dependency. Used by `SensorFactory` when simulating, and when no BLE manager
/// is supplied.
public actor MockHeartelfieDeviceSensor: CardioSensor {

    public nonisolated let modality: Modality

    private let heartRateBPM: Double
    private let seed: UInt64
    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var pumpTask: Task<Void, Never>?

    public init(modality: Modality, heartRateBPM: Double = 70, seed: UInt64 = 909) {
        precondition(modality.requiresDevice, "MockHeartelfieDeviceSensor requires a device modality")
        self.modality = modality
        self.heartRateBPM = heartRateBPM
        self.seed = seed
    }

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        let modality = self.modality
        let sampleRate = modality.nominalSampleRate
        let hr = heartRateBPM
        let seed = self.seed

        let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
        pumpTask = Task {
            await Self.pump(
                modality: modality, sampleRate: sampleRate,
                heartRateBPM: hr, seed: seed, into: continuation
            )
        }
        return stream
    }

    public func stop() async {
        pumpTask?.cancel()
        pumpTask = nil
        continuation?.finish()
        continuation = nil
    }

    /// Synthesize 1-second buffers and emit their samples in real time, looping
    /// until cancelled. Static so it captures no actor state across suspensions.
    private static func pump(
        modality: Modality,
        sampleRate: Double,
        heartRateBPM: Double,
        seed: UInt64,
        into continuation: AsyncStream<SignalFrame>.Continuation
    ) async {
        let framePeriodNS = UInt64(1_000_000_000 / max(sampleRate, 1))
        let epoch = Date().timeIntervalSince1970
        var sampleIndex = 0
        var batch = 0

        while !Task.isCancelled {
            let batchSeed = seed &+ (UInt64(truncatingIfNeeded: batch) &* 104_729)
            let buffers = synthesize(
                modality: modality, sampleRate: sampleRate,
                heartRateBPM: heartRateBPM, seed: batchSeed
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

    private static func synthesize(
        modality: Modality, sampleRate: Double, heartRateBPM: Double, seed: UInt64
    ) -> [(channel: SignalChannel, values: [Double])] {
        switch modality {
        case .deviceMultiWavelengthPPG:
            let ir = SyntheticSignal.ppg(
                durationSeconds: 1.0, sampleRate: sampleRate,
                heartRateBPM: heartRateBPM, hrvMS: 18, noise: 0.004,
                baselineWander: 0.03, seed: seed
            )
            return [
                (.infrared, ir),
                (.infrared2, ir.map { 0.94 * $0 }),
                (.red, ir.map { 0.78 * $0 })
            ]
        case .deviceECG:
            let ecg = SyntheticSignal.ecg(
                durationSeconds: 1.0, sampleRate: sampleRate,
                heartRateBPM: heartRateBPM, hrvMS: 22, noise: 0.01,
                baselineWander: 0.02, seed: seed
            )
            return [(.ecg, ecg)]
        case .deviceBioZ:
            let count = Int(sampleRate)
            var rng = SeededGenerator(seed: seed)
            var values = [Double](repeating: 0, count: max(count, 0))
            for i in 0..<values.count {
                let t = Double(i) / sampleRate
                values[i] = 480.0 + 6.0 * sin(2 * .pi * 0.25 * t) + 0.5 * rng.nextGaussian()
            }
            return [(.bioImpedance, values)]
        default:
            return []
        }
    }
}
