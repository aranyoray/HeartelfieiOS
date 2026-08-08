import Foundation
import HECore
import HESignal

#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreVideo)
import CoreVideo
#endif

/// Transmissive **finger PPG** via the rear camera + torch (`.fingerPPG`).
///
/// At `start()` the rear camera streams video frames; for each frame we compute the
/// mean of the red, green, and blue components of the pixel buffer and emit a
/// `SignalFrame` carrying three `SignalSample`s (`.red`, `.green`, `.blue`). The
/// torch is switched on at start and off at stop. Phone PPG is wellness-grade
/// `.screening` — never an ECG.
///
/// If AVFoundation is unavailable (or there is no usable capture device, e.g. the
/// Simulator) this falls back to synthetic frames so the type always works.
@MainActor
public final class CameraPPGSensor: NSObject, CardioSensor {

    public nonisolated var modality: Modality { .fingerPPG }

    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var fallback: MockCameraPPGSensor?

    #if canImport(AVFoundation)
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "com.heartelfie.camera.ppg")
    private var captureDevice: AVCaptureDevice?
    #endif

    public override init() { super.init() }

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        #if canImport(AVFoundation)
        if configureSession() {
            enableTorch(true)
            await startSession()
            // Configuration can succeed yet the session still fail to start (camera
            // busy, resource contention). Without this guard we'd return a stream
            // that never emits and the capture UI would hang — fall back to the mock.
            guard session.isRunning else {
                enableTorch(false)
                return await startFallback()
            }
            let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in await self?.stop() }
            }
            return stream
        }
        #endif
        // No camera available — behave like the mock.
        return await startFallback()
    }

    public func stop() async {
        #if canImport(AVFoundation)
        enableTorch(false)
        await stopSession()
        #endif
        continuation?.finish()
        continuation = nil
        if let fallback { await fallback.stop() }
        fallback = nil
    }

    // MARK: - Fallback

    private func startFallback() async -> AsyncStream<SignalFrame> {
        let mock = MockCameraPPGSensor()
        fallback = mock
        return await mock.start()
    }

    #if canImport(AVFoundation)
    // MARK: - Capture session setup

    /// Build the rear-camera capture graph. Returns `false` if no usable device is
    /// present (Simulator, permission revoked), signalling a fallback to the mock.
    private func configureSession() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output)
        else { return false }

        session.beginConfiguration()
        session.sessionPreset = .low // PPG needs only a low-res mean, not detail.
        session.addInput(input)
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        session.addOutput(output)
        session.commitConfiguration()
        captureDevice = device
        return true
    }

    /// Toggle the torch, which provides the constant illumination transmissive PPG
    /// depends on. Guarded so devices without a torch simply skip it.
    private func enableTorch(_ on: Bool) {
        guard let device = captureDevice, device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }
        if on {
            try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        } else {
            device.torchMode = .off
        }
    }

    /// Start the capture session on the dedicated capture queue, not the main actor.
    /// `startRunning()` blocks for 100s of milliseconds; running it on `@MainActor`
    /// stalls the UI. Awaits completion so the caller can read `session.isRunning`.
    private func startSession() async {
        nonisolated(unsafe) let session = self.session
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sampleQueue.async {
                session.startRunning()
                cont.resume()
            }
        }
    }

    /// Stop the session off the main actor for the same reason as `startSession()`.
    private func stopSession() async {
        nonisolated(unsafe) let session = self.session
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sampleQueue.async {
                if session.isRunning { session.stopRunning() }
                cont.resume()
            }
        }
    }
    #endif
}

#if canImport(AVFoundation)
extension CameraPPGSensor: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Per-frame callback (on `sampleQueue`).
    ///
    /// We do all non-`Sendable` work here — the `CMSampleBuffer`/`CVPixelBuffer`
    /// never escape this method — and emit only plain `Double` channel means
    /// through the `Sendable` continuation.
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestamp = presentation.isValid
            ? CMTimeGetSeconds(presentation)
            : Date().timeIntervalSince1970

        guard let means = Self.channelMeans(of: pixelBuffer) else { return }
        let frame = SignalFrame(timestamp: timestamp, samples: [
            SignalSample(timestamp: timestamp, value: means.red, channel: .red),
            SignalSample(timestamp: timestamp, value: means.green, channel: .green),
            SignalSample(timestamp: timestamp, value: means.blue, channel: .blue)
        ])

        // `continuation` is only mutated on the main actor; reading the cached
        // value here would race, so hop to the main actor to forward. The frame is
        // `Sendable` so this crosses the boundary safely.
        Task { @MainActor [weak self] in
            self?.continuation?.yield(frame)
        }
    }

    /// Compute the mean R, G, B over a (subsampled) BGRA pixel buffer.
    ///
    /// **This is where pixel-buffer averaging happens.** We lock the buffer,
    /// stride across rows/columns (subsampling for speed — a fingertip PPG only
    /// needs the spatial average, not every pixel), accumulate each colour
    /// component, and divide by the sample count. BGRA byte order is B, G, R, A.
    nonisolated static func channelMeans(
        of pixelBuffer: CVPixelBuffer
    ) -> (red: Double, green: Double, blue: Double)? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0 else { return nil }

        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let strideX = max(width / 64, 1)   // subsample columns
        let strideY = max(height / 64, 1)  // subsample rows

        var sumR = 0.0, sumG = 0.0, sumB = 0.0
        var count = 0
        var y = 0
        while y < height {
            let row = y * bytesPerRow
            var x = 0
            while x < width {
                let p = row + x * 4
                sumB += Double(ptr[p + 0])  // B
                sumG += Double(ptr[p + 1])  // G
                sumR += Double(ptr[p + 2])  // R
                count += 1
                x += strideX
            }
            y += strideY
        }
        guard count > 0 else { return nil }
        return (sumR / Double(count), sumG / Double(count), sumB / Double(count))
    }
}
#endif

/// Simulator/no-hardware twin of `CameraPPGSensor`.
///
/// Emits ~30 Hz synthetic finger-PPG frames from `HESignal.SyntheticSignal.ppg`.
/// The green plane carries the base PPG; the red plane is a scaled variant and the
/// blue plane a smaller one, so a plausible ratio-of-ratios exists for downstream
/// (screening-grade) SpO₂ estimation.
public actor MockCameraPPGSensor: CardioSensor {

    public nonisolated var modality: Modality { .fingerPPG }

    private let heartRateBPM: Double
    private let seed: UInt64
    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var pumpTask: Task<Void, Never>?

    public init(heartRateBPM: Double = 72, seed: UInt64 = 11) {
        self.heartRateBPM = heartRateBPM
        self.seed = seed
    }

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        let sampleRate = modality.nominalSampleRate   // ~30 Hz
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
            let green = SyntheticSignal.ppg(
                durationSeconds: 1.0, sampleRate: sampleRate,
                heartRateBPM: heartRateBPM, hrvMS: 28, noise: 0.01,
                motionArtifact: 0.0, baselineWander: 0.05,
                seed: seed &+ (UInt64(truncatingIfNeeded: batch) &* 2_654_435)
            )
            // DC-offset the planes to camera-like 0...255 levels and scale colours
            // so a ratio-of-ratios is recoverable downstream.
            for i in 0..<green.count {
                if Task.isCancelled { break }
                let timestamp = epoch + Double(sampleIndex) / sampleRate
                let g = 140.0 + 40.0 * green[i]
                let r = 180.0 + 55.0 * green[i] * 0.85
                let b = 90.0 + 20.0 * green[i] * 0.5
                let frame = SignalFrame(timestamp: timestamp, samples: [
                    SignalSample(timestamp: timestamp, value: r, channel: .red),
                    SignalSample(timestamp: timestamp, value: g, channel: .green),
                    SignalSample(timestamp: timestamp, value: b, channel: .blue)
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
