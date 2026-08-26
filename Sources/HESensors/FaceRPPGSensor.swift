import Foundation
import HECore
import HESignal

#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreVideo)
import CoreVideo
#endif
#if canImport(QuartzCore)
import QuartzCore
#endif

/// Contactless **facial rPPG** via the front camera + Vision (`.facialRPPG`).
///
/// Each front-camera frame is run through a Vision face detector to find a face
/// rectangle; we take a forehead/cheek ROI from it and emit the ROI's mean green
/// value as a `.green` `SignalSample` (the green channel carries the strongest
/// remote-PPG signal). Screening-grade only.
///
/// On the Simulator (no front camera) this falls back to synthetic green frames;
/// on a real device a camera that cannot run (permission denied, configuration
/// failure) ends the stream immediately so the UI reports the sensor as
/// unavailable instead of quietly measuring a mock.
@MainActor
public final class FaceRPPGSensor: NSObject, CardioSensor {

    public nonisolated var modality: Modality { .facialRPPG }

    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var fallback: MockFaceRPPGSensor?

    #if canImport(AVFoundation)
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "com.heartelfie.camera.rppg")
    #endif

    public override init() { super.init() }

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        #if canImport(AVFoundation) && canImport(Vision)
        // Camera permission comes first: prompt if undetermined; if denied or
        // restricted, return a stream that finishes immediately — the view model
        // maps a stream that ends during preparing/coaching to
        // `.sensorUnavailable`. Never measure a mock in place of a denied camera.
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            status = AVCaptureDevice.authorizationStatus(for: .video)
        }
        guard status == .authorized else { return Self.finishedStream() }
        if configureSession() {
            await startSession()
            // Guard against a configured-but-not-running session (camera busy),
            // which would otherwise return a stream that never emits and hang the UI.
            guard session.isRunning else {
                return await unavailableStream()
            }
            let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in await self?.stop() }
            }
            return stream
        }
        #endif
        return await unavailableStream()
    }

    /// What to hand back when the camera cannot run: synthetic frames keep the
    /// flow usable on the Simulator, but a real device gets an immediately
    /// finished stream so the UI surfaces `.sensorUnavailable` — never mock data.
    private func unavailableStream() async -> AsyncStream<SignalFrame> {
        #if targetEnvironment(simulator) || !(canImport(AVFoundation) && canImport(Vision))
        return await startFallback()
        #else
        return Self.finishedStream()
        #endif
    }

    /// A stream that ends immediately, signalling "no sensor" to the view model.
    private static func finishedStream() -> AsyncStream<SignalFrame> {
        AsyncStream { $0.finish() }
    }

    public func stop() async {
        #if canImport(AVFoundation)
        await stopSession()
        #endif
        continuation?.finish()
        continuation = nil
        if let fallback { await fallback.stop() }
        fallback = nil
    }

    private func startFallback() async -> AsyncStream<SignalFrame> {
        let mock = MockFaceRPPGSensor()
        fallback = mock
        return await mock.start()
    }

    #if canImport(AVFoundation) && canImport(Vision)
    /// Configure the front-camera capture graph. Returns `false` when no front
    /// camera is usable, signalling an unavailable camera.
    /// Idempotent: existing inputs/outputs are removed so `start()` can be called
    /// again on the same instance without spuriously reporting unavailability.
    private func configureSession() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return false }

        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        session.sessionPreset = .vga640x480 // enough for a stable face ROI mean.
        defer { session.commitConfiguration() }

        guard session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        session.addOutput(output)
        return true
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

#if canImport(AVFoundation) && canImport(Vision)
extension FaceRPPGSensor: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Per-frame callback (on `sampleQueue`). Runs face detection synchronously,
    /// extracts the forehead/cheek ROI mean green, and forwards a `.green` frame.
    /// All non-`Sendable` Vision/CoreVideo work stays inside this method.
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        // Fallback must share the PTS host clock — a wall-clock (epoch) fallback
        // would put one frame ~1.7e9 s away and garble the rate estimate.
        let timestamp = presentation.isValid
            ? CMTimeGetSeconds(presentation)
            : CACurrentMediaTime()

        // Find a face rectangle with Vision; if none, skip this frame.
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        try? handler.perform([request])
        guard let face = (request.results)?.first else { return }

        // Vision boxes are normalized with origin bottom-left. Take a forehead/cheek
        // ROI: upper-middle portion of the face box.
        let box = face.boundingBox
        let roi = CGRect(
            x: box.minX + box.width * 0.30,
            y: box.minY + box.height * 0.55,
            width: box.width * 0.40,
            height: box.height * 0.30
        )

        guard let green = Self.meanGreen(of: pixelBuffer, normalizedROI: roi) else { return }
        let frame = SignalFrame(timestamp: timestamp, value: green, channel: .green)
        Task { @MainActor [weak self] in
            self?.continuation?.yield(frame)
        }
    }

    /// Mean green over a normalized ROI of a BGRA pixel buffer. Converts the
    /// bottom-left normalized rect into top-left pixel coordinates, then subsamples
    /// and averages the green byte (index 1 in BGRA).
    nonisolated static func meanGreen(
        of pixelBuffer: CVPixelBuffer, normalizedROI roi: CGRect
    ) -> Double? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0 else { return nil }

        // Normalized (bottom-left) → pixel (top-left). Convert CGFloat ROI
        // components to Double explicitly (CGFloat and Double don't mix implicitly).
        let minX = Double(roi.minX), maxX = Double(roi.maxX)
        let minY = Double(roi.minY), maxY = Double(roi.maxY)
        let x0 = max(Int(minX * Double(width)), 0)
        let x1 = min(Int(maxX * Double(width)), width)
        let yTop = max(Int((1.0 - maxY) * Double(height)), 0)
        let yBot = min(Int((1.0 - minY) * Double(height)), height)
        guard x1 > x0, yBot > yTop else { return nil }

        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let strideX = max((x1 - x0) / 32, 1)
        let strideY = max((yBot - yTop) / 32, 1)

        var sumG = 0.0
        var count = 0
        var y = yTop
        while y < yBot {
            let row = y * bytesPerRow
            var x = x0
            while x < x1 {
                sumG += Double(ptr[row + x * 4 + 1])  // G in BGRA
                count += 1
                x += strideX
            }
            y += strideY
        }
        guard count > 0 else { return nil }
        return sumG / Double(count)
    }
}
#endif

/// Simulator/no-hardware twin of `FaceRPPGSensor`.
///
/// Emits ~30 Hz synthetic green PPG with a bit more noise than the finger sensor,
/// reflecting the lower SNR of contactless facial rPPG.
public actor MockFaceRPPGSensor: CardioSensor {

    public nonisolated var modality: Modality { .facialRPPG }

    private let heartRateBPM: Double
    private let seed: UInt64
    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var pumpTask: Task<Void, Never>?

    public init(heartRateBPM: Double = 68, seed: UInt64 = 23) {
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
            // More noise + baseline wander than finger PPG (lower SNR).
            let green = SyntheticSignal.ppg(
                durationSeconds: 1.0, sampleRate: sampleRate,
                heartRateBPM: heartRateBPM, hrvMS: 30, noise: 0.05,
                motionArtifact: 0.02, baselineWander: 0.12,
                seed: seed &+ (UInt64(truncatingIfNeeded: batch) &* 40_503)
            )
            for i in 0..<green.count {
                if Task.isCancelled { break }
                let timestamp = epoch + Double(sampleIndex) / sampleRate
                let g = 130.0 + 18.0 * green[i] // camera-like green level.
                continuation.yield(SignalFrame(timestamp: timestamp, value: g, channel: .green))
                sampleIndex += 1
                try? await Task.sleep(nanoseconds: framePeriodNS)
            }
            batch += 1
        }
        continuation.finish()
    }
}
