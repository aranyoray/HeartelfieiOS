import Foundation
import HECore
import HESignal

#if canImport(AVFoundation)
import AVFoundation
#endif

/// **Phonocardiography** (heart sounds) via the microphone (`.pcg`).
///
/// An `AVAudioEngine` input tap captures the mic; for each buffer we compute a
/// short-window RMS envelope (decimated toward the modality's nominal rate) and emit
/// `.audio` samples. This is a *screening*, experimental feature — heart sounds, not
/// a diagnosis.
///
/// Falls back to a synthetic S1/S2 envelope when AVFoundation is unavailable or the
/// audio engine can't start (e.g. the Simulator).
public actor MicPCGSensor: CardioSensor {

    public nonisolated var modality: Modality { .pcg }

    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var fallback: MockMicPCGSensor?

    #if canImport(AVFoundation)
    private let engine = AVAudioEngine()
    private var isTapInstalled = false
    #endif

    public init() {}

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        #if canImport(AVFoundation)
        if let stream = startEngine() {
            return stream
        }
        #endif
        return await startFallback()
    }

    public func stop() async {
        #if canImport(AVFoundation)
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        if engine.isRunning { engine.stop() }
        #if os(iOS)
        // Best-effort release of the audio session; ignore errors on teardown.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        #endif
        continuation?.finish()
        continuation = nil
        if let fallback { await fallback.stop() }
        fallback = nil
    }

    private func startFallback() async -> AsyncStream<SignalFrame> {
        let mock = MockMicPCGSensor()
        fallback = mock
        return await mock.start()
    }

    #if canImport(AVFoundation)
    /// Install an input tap and start the engine. Returns `nil` if the engine can't
    /// start, signalling a fallback to synthetic frames.
    ///
    /// The tap block runs on a realtime audio thread and computes RMS over fixed
    /// windows, emitting one `.audio` sample per window toward the modality's
    /// nominal rate. Only Sendable `Double`s leave the block.
    private func startEngine() -> AsyncStream<SignalFrame>? {
        #if os(iOS)
        // A record-capable audio session must be active before the input node has a
        // valid format/route. If this fails (e.g. the Simulator), we fall back.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
        } catch {
            return nil
        }
        #endif

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let inputSampleRate = format.sampleRate
        guard inputSampleRate > 0 else { return nil }

        // Decimate the input toward the PCG nominal rate via RMS windows.
        let targetRate = modality.nominalSampleRate          // ~2000 Hz
        let windowSize = max(Int(inputSampleRate / targetRate), 1)

        let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self,
                  let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }
            let samples = channelData[0]

            // Compute one RMS envelope value per window of `windowSize` samples.
            var envelope: [Double] = []
            envelope.reserveCapacity(frameLength / windowSize + 1)
            var i = 0
            while i < frameLength {
                let end = min(i + windowSize, frameLength)
                var sumSq = 0.0
                for j in i..<end {
                    let v = Double(samples[j])
                    sumSq += v * v
                }
                let n = max(end - i, 1)
                envelope.append((sumSq / Double(n)).squareRoot())
                i += windowSize
            }

            let base = Date().timeIntervalSince1970
            let envelopeCopy = envelope   // Sendable [Double] crossing into the actor.
            Task { await self.emit(envelope: envelopeCopy, baseTimestamp: base, rate: targetRate) }
        }
        isTapInstalled = true

        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            isTapInstalled = false
            return nil
        }
        return stream
    }

    /// Forward a decimated RMS envelope as `.audio` frames at the target rate.
    private func emit(envelope: [Double], baseTimestamp: Double, rate: Double) {
        guard let continuation else { return }
        for (k, value) in envelope.enumerated() {
            let timestamp = baseTimestamp + Double(k) / rate
            continuation.yield(SignalFrame(timestamp: timestamp, value: value, channel: .audio))
        }
    }
    #endif
}

/// Simulator/no-hardware twin of `MicPCGSensor`.
///
/// Emits a synthetic heart-sound envelope on `.audio`: two thumps per beat (S1 then
/// the slightly softer S2), at the modality's nominal rate.
public actor MockMicPCGSensor: CardioSensor {

    public nonisolated var modality: Modality { .pcg }

    private let heartRateBPM: Double
    private let seed: UInt64
    private var continuation: AsyncStream<SignalFrame>.Continuation?
    private var pumpTask: Task<Void, Never>?

    public init(heartRateBPM: Double = 66, seed: UInt64 = 53) {
        self.heartRateBPM = heartRateBPM
        self.seed = seed
    }

    public func start() async -> AsyncStream<SignalFrame> {
        await stop()
        // Emit a manageable decimated rate for the synthetic envelope (the true
        // 2000 Hz nominal rate is unnecessary for a demo envelope and would burn
        // CPU). 200 Hz preserves S1/S2 timing clearly.
        let sampleRate = min(modality.nominalSampleRate, 200)
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
        let rr = 60.0 / max(heartRateBPM, 1)         // beat-to-beat interval (s).
        var rng = SeededGenerator(seed: seed)
        var sampleIndex = 0

        // Continuous time-based synthesis so beats stay phase-correct across loops.
        while !Task.isCancelled {
            let t = Double(sampleIndex) / sampleRate
            let phase = t.truncatingRemainder(dividingBy: rr)
            // S1 (lub) near phase 0; S2 (dub) ~0.32 of the cycle later, softer.
            let s1 = Self.thump(phase - 0.02, width: 0.035) * 1.0
            let s2 = Self.thump(phase - rr * 0.32, width: 0.030) * 0.6
            let noise = 0.02 * rng.nextGaussian()
            let value = max(s1 + s2 + abs(noise), 0)
            let timestamp = epoch + t
            continuation.yield(SignalFrame(timestamp: timestamp, value: value, channel: .audio))
            sampleIndex += 1
            try? await Task.sleep(nanoseconds: framePeriodNS)
        }
        continuation.finish()
    }

    /// A short Gaussian "thump" envelope centered at `dt == 0`.
    private static func thump(_ dt: Double, width: Double) -> Double {
        exp(-(dt * dt) / (2 * width * width))
    }
}
