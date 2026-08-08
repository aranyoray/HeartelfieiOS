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
        case countdown(Int)
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
    /// 0...1 progress through the capture window.
    public private(set) var captureProgress: Double = 0
    public private(set) var elapsedSeconds: Double = 0

    // Dependencies
    private let sensors: SensorProviding
    private let inference: any InferenceProviding
    private let profile: HealthProfile?
    private let skinTone: MonkSkinTone?
    private let onComplete: (CardioReading) async -> Void

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
        onComplete: @escaping (CardioReading) async -> Void
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
            // Stream ended. If it ended while we were still waiting/capturing, the
            // source dropped (camera stalled, device disconnected) — surface it
            // instead of leaving the UI stuck.
            await self?.streamEnded()
        }
    }

    /// Begin the capture window (typically after a short countdown in the UI).
    public func startCapture() {
        guard phase == .coaching else { return }
        // Collect a fresh window so the processed signal is just the capture.
        resetBuffers()
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
        let primary = channelBuffers[SignalProcessor.primaryChannel(for: modality)]
            ?? channelBuffers.values.first ?? []
        if primary.count > 30 {
            await finishCapture()
        } else {
            await stopSensor()
            phase = .failed(.timeout)
        }
    }

    /// The sensor stream finished. If it ended while we were still waiting for signal
    /// or mid-capture, the source dropped (camera stalled, device disconnected) —
    /// surface it instead of leaving the UI stuck. Ignored during intentional teardown.
    private func streamEnded() async {
        guard !isTearingDown else { return }
        switch phase {
        case .preparing, .coaching, .countdown:
            phase = .failed(modality.requiresDevice ? .contactLost : .sensorUnavailable)
        case .capturing:
            await captureDeadlineReached()
        default:
            break
        }
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
    private var sampleRate: Double {
        guard let first = timestamps.first, let last = timestamps.last,
              last > first, timestamps.count > 1 else {
            return modality.nominalSampleRate
        }
        return Double(timestamps.count - 1) / (last - first)
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
        let issues = phase == .capturing ? quality.issues : quality.issues.filter { $0 != .tooShort }
        liveQuality = SignalQuality(
            sqi: quality.sqi,
            isAcceptable: quality.sqi >= ClinicalConfig.sqiAcceptanceThreshold,
            issues: issues
        )
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

        switch result {
        case .failure(let error):
            phase = .failed(error)

        case .success(let processed):
            // Inference adds device-only clinical metrics (cloud) or an on-device
            // rhythm screen; phone DSP metrics already came from the processor.
            let inferred = await inference.infer(
                modality: modality,
                channels: channels,
                sampleRate: sr,
                profile: profile,
                skinTone: skinTone
            )

            var metrics = processed.metrics
            for metric in inferred.metrics where !metrics.contains(where: { $0.kind == metric.kind }) {
                metrics.append(metric)
            }

            let provenance = inferred.metrics.isEmpty ? Provenance.onDeviceDSP : inferred.provenance
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
            phase = .completed(reading)
            await onComplete(reading)
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
        isFinishing = false
        isTearingDown = false
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    // MARK: - Convenience for the UI

    /// Current live heart-rate estimate (for the pulse animation), if resolvable.
    public var liveBPM: Double? {
        guard liveWaveform.count > 40 else { return nil }
        let band = FilterBand.passband(for: modality)
        let sr = sampleRate
        let filtered = BandpassFilter(lowHz: band.low, highHz: band.high, sampleRate: sr).filtfilt(liveWaveform)
        let peaks = PeakDetector().peakIndices(in: filtered, sampleRate: sr)
        let rr = PeakDetector().rrIntervalsMS(peakIndices: peaks, sampleRate: sr)
        return RRMetrics(rrIntervalsMS: rr, minBeats: 2)?.heartRateBPM
    }

    public var completedReading: CardioReading? {
        if case .completed(let reading) = phase { return reading }
        return nil
    }

    public var failureError: CaptureError? {
        if case .failed(let error) = phase { return error }
        return nil
    }
}
