import Foundation
import HECore
import HESignal

#if canImport(CoreMotion)
import CoreMotion
#endif

/// **Seismocardiography / gyrocardiography** via the accelerometer + gyroscope
/// (`.scg`). The phone rests on the chest; each heartbeat produces tiny body-surface
/// vibrations the IMU picks up.
///
/// Emits two channels per update: the acceleration-vector magnitude on
/// `.accelMagnitude` and the rotation-rate magnitude on `.gyroMagnitude`, at the
/// modality's nominal ~100 Hz. Screening-grade, experimental.
///
/// Falls back to synthetic SCG when CoreMotion is unavailable or device motion
/// isn't available (e.g. the Simulator).
public actor MotionSCGSensor: CardioSensor {

    public nonisolated var modality: Modality { .scg }

    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var fallback: MockMotionSCGSensor?

    #if canImport(CoreMotion)
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    #endif

    public init() {}

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        #if canImport(CoreMotion)
        if motion.isDeviceMotionAvailable {
            return startDeviceMotion()
        }
        #endif
        return await startFallback()
    }

    public func stop() async {
        #if canImport(CoreMotion)
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        #endif
        continuation?.finish()
        continuation = nil
        if let fallback { await fallback.stop() }
        fallback = nil
    }

    private func startFallback() async -> AsyncStream<SignalFrame> {
        let mock = MockMotionSCGSensor()
        fallback = mock
        return await mock.start()
    }

    #if canImport(CoreMotion)
    /// Start ~100 Hz device-motion updates. CoreMotion delivers `CMDeviceMotion`
    /// (non-`Sendable`) on `queue`; we extract Sendable `Double` magnitudes inside
    /// the handler and feed the actor via a continuation, so nothing non-Sendable
    /// crosses an isolation boundary.
    private func startDeviceMotion() -> AsyncStream<SignalFrame> {
        let sampleRate = modality.nominalSampleRate   // ~100 Hz
        motion.deviceMotionUpdateInterval = 1.0 / sampleRate
        queue.maxConcurrentOperationCount = 1

        let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
        motion.startDeviceMotionUpdates(to: queue) { data, _ in
            guard let data else { return }
            // User acceleration excludes gravity — the SCG component we want.
            let a = data.userAcceleration
            let r = data.rotationRate
            let accelMag = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            let gyroMag = (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot()
            let timestamp = Date().timeIntervalSince1970
            let frame = SignalFrame(timestamp: timestamp, samples: [
                SignalSample(timestamp: timestamp, value: accelMag, channel: .accelMagnitude),
                SignalSample(timestamp: timestamp, value: gyroMag, channel: .gyroMagnitude)
            ])
            // `frame` is Sendable; forward it onto the actor's stream.
            continuation.yield(frame)
        }
        return stream
    }
    #endif
}

/// Simulator/no-hardware twin of `MotionSCGSensor`.
///
/// Emits ~100 Hz synthetic SCG on `.accelMagnitude` (plus a correlated, smaller
/// `.gyroMagnitude`). We reuse the band-limited `SyntheticSignal.ppg` pulse train as
/// a low-noise stand-in for the per-beat seismic complex.
public actor MockMotionSCGSensor: CardioSensor {

    public nonisolated var modality: Modality { .scg }

    private let heartRateBPM: Double
    private let seed: UInt64
    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var pumpTask: Task<Void, Never>?

    public init(heartRateBPM: Double = 64, seed: UInt64 = 31) {
        self.heartRateBPM = heartRateBPM
        self.seed = seed
    }

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        let sampleRate = modality.nominalSampleRate   // ~100 Hz
        let hr = heartRateBPM
        let seed = self.seed
        let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
        pumpTask = Task {
            await Self.pump(sampleRate: sampleRate, heartRateBPM: hr, seed: seed, into: continuation)
        }
        return stream
    }

    public func stop() async {
        pumpTask?.cancel()
        pumpTask = nil
        continuation?.finish()
        continuation = nil
    }

    private static func pump(
        sampleRate: Double, heartRateBPM: Double, seed: UInt64,
        into continuation: AsyncStream<SignalFrame>.Continuation
    ) async {
        let framePeriodNS = UInt64(1_000_000_000 / max(sampleRate, 1))
        let epoch = Date().timeIntervalSince1970
        var sampleIndex = 0
        var batch = 0

        while !Task.isCancelled {
            // Low-noise pulse train as a stand-in for the seismic beat complex.
            let pulse = SyntheticSignal.ppg(
                durationSeconds: 1.0, sampleRate: sampleRate,
                heartRateBPM: heartRateBPM, hrvMS: 24, noise: 0.006,
                motionArtifact: 0.0, baselineWander: 0.01,
                seed: seed &+ UInt64(batch &* 15_485_863 % 1_000_003)
            )
            for i in 0..<pulse.count {
                if Task.isCancelled { break }
                let timestamp = epoch + Double(sampleIndex) / sampleRate
                let accel = 0.02 * pulse[i]          // small g-scale vibration.
                let gyro = 0.01 * pulse[i]           // correlated rotation.
                let frame = SignalFrame(timestamp: timestamp, samples: [
                    SignalSample(timestamp: timestamp, value: accel, channel: .accelMagnitude),
                    SignalSample(timestamp: timestamp, value: gyro, channel: .gyroMagnitude)
                ])
                continuation.yield(frame)
                sampleIndex += 1
                try? await Task.sleep(nanoseconds: framePeriodNS)
            }
            batch += 1
        }
        continuation.finish()
    }
}
