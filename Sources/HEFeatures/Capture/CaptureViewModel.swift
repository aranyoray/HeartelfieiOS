import Foundation
import Observation
import HECore
import HESignal
import HESensors
import HEML

/// Drives one capture through the full pipeline and exposes live state for the
/// capture UI:
///
/// `acquire (sensor stream) → live SQI coaching → countdown → capture window →
///  SQI gate → filter + feature-extract → infer → CardioReading`
///
/// A capture is abortable, and a poor-SQI signal blocks completion with specific,
/// actionable coaching instead of producing a (never-fabricated) metric.
@MainActor
@Observable
public final class CaptureViewModel {

    public enum Phase: Equatable {
        case idle
        case preparing
        case coaching          // streaming; waiting for good signal / user to start
        case capturing
        case processing
        case completed(CardioReading)
        case failed(CaptureError)
    }

    public let modality: Modality
    public private(set) var phase: Phase = .idle
    /// Most-recent samples of the primary channel for the live waveform view.
    public private(set) var liveWaveform: [Double] = []
    /// Live signal-quality estimate used to coach the user before/while capturing.
    public private(set) var liveQuality: SignalQuality?
    /// Current live heart-rate estimate (for the pulse animation), if resolvable.
    /// Recomputed on the coaching cadence in `ingest`, not on every UI read.
    public private(set) var liveBPM: Double?
    /// 0...1 progress through the capture window.
    public private(set) var captureProgress: Double = 0
    public private(set) var elapsedSeconds: Double = 0

    // Dependencies
    private let sensors: SensorProviding
    private let inference: any InferenceProviding
    private let profile: HealthProfile?
    private let skinTone: MonkSkinTone?
    private let onComplete: (CardioReading) async throws -> Void

    // Pipeline state
    private let processor = SignalProcessor()
    private var sensor: (any CardioSensor)?
    private var streamTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var channelBuffers: [SignalChannel: [Double]] = [:]
    private var timestamps: [TimeInterval] = []
    private var captureStartTimestamp: TimeInterval?
    private var isFinishing = false
    /// True while we are intentionally stopping the sensor, so the stream's natural
    /// end (from our own `stop()`) isn't mistaken for an unexpected drop.
    private var isTearingDown = false

    /// Length of the capture window in seconds (modality minimum + a small margin).
    private var captureWindow: Double { ClinicalConfig.minimumCaptureSeconds(for: modality) + 2 }

    public init(
        modality: Modality,
        sensors: SensorProviding,
        inference: any InferenceProviding,
        profile: HealthProfile?,
        skinTone: MonkSkinTone?,
        onComplete: @escaping (CardioReading) async throws -> Void
    ) {
        self.modality = modality
        self.sensors = sensors
        self.inference = inference
        self.profile = profile
        self.skinTone = skinTone
        self.onComplete = onComplete
    }

    // MARK: - Public control

    /// Start the sensor stream and enter live coaching.
    public func begin() async {
        guard phase == .idle || isFailed else { return }
        await stopSensor()
        resetBuffers()
        phase = .preparing
        let sensor = sensors.sensor(for: modality)
        self.sensor = sensor
        let stream = await sensor.start()
        phase = .coaching
        streamTask = Task { [weak self] in
            for await frame in stream {
                self?.ingest(frame)
            }
            guard !Task.isCancelled else { return }
            await self?.streamEnded()
        }
    }

    /// Begin the capture window (typically after a short countdown in the UI).
    public func startCapture() {
        guard phase == .coaching else { return }
        // Collect a fresh window so the processed signal is just the capture, but
        // keep the live waveform/quality/BPM on screen — clearing them here makes
        // the UI regress to "waiting for signal" for a second mid-save.
        channelBuffers.removeAll()
        timestamps.removeAll()
        captureStartTimestamp = nil
        captureProgress = 0
        elapsedSeconds = 0
        isFinishing = false
        phase = .capturing
        startWatchdog()
    }

    /// Wall-clock backstop. The timestamp-driven finish in `ingest` only fires when a
    /// new frame arrives, so if frames stall mid-window the capture would hang forever.
    /// This guarantees it resolves within the window plus a grace margin.
    private func startWatchdog() {
        watchdogTask?.cancel()
        let deadline = captureWindow + 4
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(deadline))
            guard let self, !Task.isCancelled else { return }
            await self.captureDeadlineReached()
        }
    }

    /// Resolve a capture whose frames stopped arriving. Process what we have if it is
    /// enough for the SQI gate to judge; otherwise fail with a clear timeout.
    private func captureDeadlineReached() async {
        guard phase == .capturing, !isFinishing else { return }
        isFinishing = true
        // Only hand the buffer to the SQI gate if it can plausibly pass the
        // minimum-duration check; a short stall should surface as a timeout, not
        // a guaranteed-to-fail quality rejection.
        if elapsedSeconds >= ClinicalConfig.minimumCaptureSeconds(for: modality) {
            await finishCapture()
        } else {
            await stopSensor()
            phase = .failed(.timeout)
        }
    }

    /// The sensor stream finished. If it ended while we were still waiting for signal
    /// or mid-capture, the source dropped (camera stalled) — surface it instead of
    /// leaving the UI stuck. Ignored during intentional teardown.
    private func streamEnded() async {
        guard !isTearingDown else { return }
        switch phase {
        case .preparing, .coaching:
            await stopSensor()
            phase = .failed(.sensorUnavailable)
        case .capturing:
            await captureDeadlineReached()
        default:
            break
        }
    }

    /// Finish the capture window early at the user's request. Only honored once
    /// the modality's minimum signal length has been collected, so the SQI gate
    /// still sees enough data to judge the reading honestly.
    public func finishEarly() async {
        guard phase == .capturing, !isFinishing else { return }
        guard elapsedSeconds >= ClinicalConfig.minimumCaptureSeconds(for: modality) else { return }
        isFinishing = true
        await finishCapture()
    }

    /// Seconds still required before an early finish produces a valid reading.
    public var secondsUntilFinishAllowed: Double {
        max(0, ClinicalConfig.minimumCaptureSeconds(for: modality) - elapsedSeconds)
    }

    /// Abort the capture and tear down the sensor.
    public func abort() async {
        await stopSensor()
        phase = .idle
        resetBuffers()
    }

    /// Retry after a poor-quality or failed capture.
    public func retry() async {
        await stopSensor()
        phase = .idle
        await begin()
    }

    // MARK: - Streaming

    private func ingest(_ frame: SignalFrame) {
        // A long timestamp gap (backgrounding, camera stall, face lost) means the
        // buffer is no longer one continuous signal — never splice across it.
        if let last = timestamps.last, frame.timestamp - last > 2.0 {
            if phase == .capturing, !isFinishing {
                isFinishing = true
                Task {
                    await stopSensor()
                    phase = .failed(.timeout)
                }
                return
            }
            if phase == .coaching {
                // Restart the coaching buffer so the stitched signal never
                // feeds the live BPM estimate.
                resetBuffers()
            }
        }

        for sample in frame.samples {
            channelBuffers[sample.channel, default: []].append(sample.value)
        }
        timestamps.append(frame.timestamp)

        let primaryChannel = SignalProcessor.primaryChannel(for: modality)
        let primary = channelBuffers[primaryChannel] ?? channelBuffers.values.first ?? []
        liveWaveform = Array(primary.suffix(180))

        // Live coaching ~ every 15 new samples once we have a little signal.
        if primary.count > 30, primary.count % 15 == 0 {
            updateLiveQuality(primary: primary)
            updateLiveBPM()
        }

        if phase == .capturing {
            if captureStartTimestamp == nil { captureStartTimestamp = frame.timestamp }
            if let start = captureStartTimestamp {
                elapsedSeconds = max(0, frame.timestamp - start)
                captureProgress = min(elapsedSeconds / captureWindow, 1.0)
                if elapsedSeconds >= captureWindow, !isFinishing {
                    isFinishing = true
                    Task { await finishCapture() }
                }
            }
        }
    }

    /// Effective sample rate from observed timestamps, falling back to nominal.
    /// Clamped to a physically plausible band: one bad timestamp can push the
    /// estimate past Nyquist limits and destabilize the bandpass biquad.
    private var sampleRate: Double {
        guard let first = timestamps.first, let last = timestamps.last,
              last > first, timestamps.count > 1 else {
            return modality.nominalSampleRate
        }
        let estimated = Double(timestamps.count - 1) / (last - first)
        guard (3.0...120.0).contains(estimated) else { return modality.nominalSampleRate }
        return estimated
    }

    private func updateLiveQuality(primary: [Double]) {
        let band = FilterBand.passband(for: modality)
        let sr = sampleRate
        let filtered = BandpassFilter(lowHz: band.low, highHz: band.high, sampleRate: sr).filtfilt(primary)
        let quality = SQIClassifier().evaluate(
            raw: primary,
            filtered: filtered,
            sampleRate: sr,
            durationSeconds: Double(primary.count) / sr,
            modality: modality
        )
        // During coaching the buffer is short by design — don't nag about duration.
        // Everything else — notably the classifier's saturation veto (finger
        // pressed too hard) — carries into acceptability, so the live coach never
        // shows green for a signal the gate is guaranteed to reject.
        let issues = phase == .capturing ? quality.issues : quality.issues.filter { $0 != .tooShort }
        liveQuality = SignalQuality(
            sqi: quality.sqi,
            isAcceptable: quality.sqi >= ClinicalConfig.sqiAcceptanceThreshold
                && !issues.contains(.saturation),
            issues: issues
        )
    }

    /// Refresh the live heart-rate estimate from the recent waveform. Runs on the
    /// same cadence as `updateLiveQuality` so the DSP cost is bounded per frame.
    private func updateLiveBPM() {
        guard liveWaveform.count > 40 else {
            liveBPM = nil
            return
        }
        let band = FilterBand.passband(for: modality)
        let sr = sampleRate
        let filtered = BandpassFilter(lowHz: band.low, highHz: band.high, sampleRate: sr).filtfilt(liveWaveform)
        let peaks = PeakDetector().peakIndices(in: filtered, sampleRate: sr)
        let rr = PeakDetector().rrIntervalsMS(peakIndices: peaks, sampleRate: sr)
        liveBPM = RRMetrics(rrIntervalsMS: rr, minBeats: 2)?.heartRateBPM
    }

    // MARK: - Finish + process

    private func finishCapture() async {
        guard phase == .capturing else { return }
        phase = .processing

        let channels = channelBuffers
        let sr = sampleRate
        await stopSensor()

        // SQI gate + DSP features (runs on a background task to keep UI smooth).
        let processor = self.processor
        let modality = self.modality
        let profile = self.profile
        let result = await Task.detached {
            processor.process(channels: channels, sampleRate: sr, modality: modality, profile: profile)
        }.value
        // The user may have aborted while processing ran — don't let a cancelled
        // capture resolve to `.completed` (and fire `onComplete`) behind them.
        guard phase == .processing else { return }

        switch result {
        case .failure(let error):
            phase = .failed(error)

        case .success(let processed):
            // On-device inference can refine DSP metrics of the same kind
            // (finger-PPG rhythm screen). Inferred rows replace DSP rows.
            let inferred = await inference.infer(
                modality: modality,
                channels: channels,
                sampleRate: sr,
                profile: profile,
                skinTone: skinTone
            )
            // Same abort re-check after the inference await.
            guard phase == .processing else { return }

            let metrics = CardioMetric.merging(processed.metrics, withInferred: inferred.metrics)
            let didApplyInference = metrics.contains { merged in
                inferred.metrics.contains { $0.kind == merged.kind && $0.id == merged.id }
            }
            let provenance = didApplyInference ? inferred.provenance : Provenance.onDeviceDSP
            let confidence = inferred.confidence ?? processed.confidence
            let interpretation = inferred.interpretation
                ?? Self.interpretation(metrics: metrics, confidence: confidence, tier: modality.tier)

            let reading = CardioReading(
                modality: modality,
                metrics: metrics,
                confidence: confidence,
                signalQuality: processed.signalQuality,
                provenance: provenance,
                interpretation: interpretation,
                monkSkinTone: skinTone,
                waveformPreview: processed.cleanWaveform
            )
            // Only mark completed once the reading is actually persisted; a save
            // failure is surfaced instead of silently dropping the reading.
            do {
                try await onComplete(reading)
                phase = .completed(reading)
            } catch {
                phase = .failed(.persistenceFailure)
            }
        }
    }

    /// Compose a concise, explicitly non-diagnostic interpretation string.
    static func interpretation(metrics: [CardioMetric], confidence: Confidence, tier: MeasurementTier) -> String {
        let risk = metrics.map(\.risk).max() ?? .unknown
        var parts: [String] = []
        if confidence.isLow {
            parts.append("Confidence was low, so treat this as a rough screen and try again when you can.")
        }
        parts.append(risk.guidance)
        if tier == .screening {
            parts.append(Disclaimers.screening)
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Teardown

    private func stopSensor() async {
        isTearingDown = true
        watchdogTask?.cancel()
        watchdogTask = nil
        streamTask?.cancel()
        streamTask = nil
        if let sensor { await sensor.stop() }
        sensor = nil
    }

    private func resetBuffers() {
        channelBuffers.removeAll()
        timestamps.removeAll()
        captureStartTimestamp = nil
        // Clear the live UI state too, so a retry/begin never shows a stale
        // "looking good" coach or a stale-enabled save button.
        liveWaveform = []
        liveQuality = nil
        liveBPM = nil
        isFinishing = false
        isTearingDown = false
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    // MARK: - Convenience for the UI

    public var completedReading: CardioReading? {
        if case .completed(let reading) = phase { return reading }
        return nil
    }

    public var failureError: CaptureError? {
        if case .failed(let error) = phase { return error }
        return nil
    }
}
