import Foundation
import HECore

/// The DSP-computable result of one capture: metrics the on-device signal pipeline
/// can derive itself (HR, HRV, rhythm, respiration).
public struct ProcessedSignal: Sendable {
    public let metrics: [CardioMetric]
    public let signalQuality: SignalQuality
    public let confidence: Confidence
    public let cleanWaveform: [Double]
    public let peakIndices: [Int]
    public let primaryChannel: SignalChannel
    public let rrMetrics: RRMetrics?

    public init(
        metrics: [CardioMetric],
        signalQuality: SignalQuality,
        confidence: Confidence,
        cleanWaveform: [Double],
        peakIndices: [Int],
        primaryChannel: SignalChannel,
        rrMetrics: RRMetrics?
    ) {
        self.metrics = metrics
        self.signalQuality = signalQuality
        self.confidence = confidence
        self.cleanWaveform = cleanWaveform
        self.peakIndices = peakIndices
        self.primaryChannel = primaryChannel
        self.rrMetrics = rrMetrics
    }
}

/// Runs the on-device DSP stage of the capture pipeline:
/// `SQI gate → filter → peak-detect → feature-extract`. Honours the Critical
/// Constraints: the SQI gate runs first and a rejected signal never yields metrics,
/// and metrics are scoped to what the modality legitimately supports.
public struct SignalProcessor: Sendable {

    private let sqiClassifier: SQIClassifier

    public init(sqiClassifier: SQIClassifier = SQIClassifier()) {
        self.sqiClassifier = sqiClassifier
    }

    /// Process per-channel raw samples for a modality.
    public func process(
        channels: [SignalChannel: [Double]],
        sampleRate: Double,
        modality: Modality,
        profile: HealthProfile? = nil
    ) -> Swift.Result<ProcessedSignal, CaptureError> {

        let primaryChannel = Self.primaryChannel(for: modality)
        guard let raw = channels[primaryChannel] ?? channels.values.first, raw.count > 8 else {
            return .failure(.sensorUnavailable)
        }
        // A non-positive rate would produce NaN filter coefficients and a NaN SQI
        // that leaks into the failure payload's UI formatting.
        guard sampleRate > 0, sampleRate.isFinite else {
            return .failure(.sensorUnavailable)
        }

        let band = FilterBand.passband(for: modality)
        let filter = BandpassFilter(lowHz: band.low, highHz: band.high, sampleRate: sampleRate)
        let filtered = filter.filtfilt(raw)
        let duration = Double(raw.count) / sampleRate

        // 1. SQI gate — runs BEFORE any metric computation.
        let quality = sqiClassifier.evaluate(
            raw: raw,
            filtered: filtered,
            sampleRate: sampleRate,
            durationSeconds: duration,
            modality: modality
        )
        guard quality.isAcceptable else {
            return .failure(.poorSignalQuality(quality))
        }

        // 2. Peak detection + RR features.
        let detector = PeakDetector()
        let peaks = detector.peakIndices(in: filtered, sampleRate: sampleRate)
        let rr = detector.rrIntervalsMS(peakIndices: peaks, sampleRate: sampleRate)
        let rrMetrics = RRMetrics(rrIntervalsMS: rr)

        guard let features = rrMetrics else {
            // Cleared SQI but couldn't resolve beats — treat as irregular cadence.
            let q = SignalQuality(sqi: quality.sqi, isAcceptable: false, issues: [.irregularCadence])
            return .failure(.poorSignalQuality(q))
        }

        // 3. Build metrics, scoped to what this modality is allowed to surface.
        var metrics: [CardioMetric] = []
        let allowed = Set(modality.supportedMetrics)

        if allowed.contains(.heartRate) {
            metrics.append(CardioMetric(kind: .heartRate, value: features.heartRateBPM.rounded(), profile: profile))
        }
        // A literal 0 ms HRV is a degenerate signal (or synthetic input), not a
        // physiological finding; showing it would flag a false "worth a check".
        if allowed.contains(.hrvSDNN), features.sdnnMS > 0 {
            metrics.append(CardioMetric(kind: .hrvSDNN, value: features.sdnnMS.rounded(), profile: profile))
        }
        if allowed.contains(.hrvRMSSD), features.rmssdMS > 0 {
            metrics.append(CardioMetric(kind: .hrvRMSSD, value: features.rmssdMS.rounded(), profile: profile))
        }
        if allowed.contains(.rhythmIrregularity) {
            metrics.append(CardioMetric(kind: .rhythmIrregularity, value: features.irregularityPercent.rounded(), profile: profile))
        }

        // Respiratory rate — optional, only when a clear respiratory rhythm exists.
        if allowed.contains(.respiratoryRate),
           let breathsPerMin = respiratoryRate(filtered: filtered, sampleRate: sampleRate) {
            metrics.append(CardioMetric(kind: .respiratoryRate, value: breathsPerMin.rounded(), profile: profile))
        }

        // 4. Confidence from SQI, beat count, and regularity.
        let confidence = confidence(quality: quality, features: features)

        let processed = ProcessedSignal(
            metrics: metrics,
            signalQuality: quality,
            confidence: confidence,
            cleanWaveform: downsample(filtered, to: 200),
            peakIndices: peaks,
            primaryChannel: primaryChannel,
            rrMetrics: features
        )
        return .success(processed)
    }

    // MARK: - Helpers

    /// Primary channel used for peak detection per modality.
    public static func primaryChannel(for modality: Modality) -> SignalChannel {
        switch modality {
        case .fingerPPG, .facialRPPG: return .green
        }
    }

    private func confidence(quality: SignalQuality, features: RRMetrics) -> Confidence {
        let countFactor = min(Double(features.beatCount) / 12.0, 1.0)
        let regularityFactor = 1.0 - min(features.irregularityPercent / 100.0, 0.6)
        let raw = quality.sqi * (0.5 + 0.5 * countFactor) * (0.6 + 0.4 * regularityFactor)
        return Confidence(raw)
    }

    /// Rough respiratory rate (breaths/min) from PPG amplitude modulation (RIIV),
    /// via autocorrelation of the rectified low-pass envelope in 0.1–0.5 Hz.
    private func respiratoryRate(filtered: [Double], sampleRate: Double) -> Double? {
        guard filtered.count > Int(sampleRate * 10) else { return nil }
        // Envelope: rectify then heavily smooth.
        let rectified = filtered.map(abs)
        let smoothLP = BandpassFilter(lowHz: 0.08, highHz: 0.6, sampleRate: sampleRate).filtfilt(rectified)
        let env = Vector.zscore(smoothLP)
        let n = env.count
        let minLag = max(Int(sampleRate * 60.0 / 30.0), 1)  // 30 br/min
        let maxLag = min(Int(sampleRate * 60.0 / 8.0), n - 1) // 8 br/min
        guard maxLag > minLag else { return nil }
        let zeroLag = Vector.dot(env, env)
        guard zeroLag > 1e-9 else { return nil }
        var bestLag = 0
        var bestVal = 0.0
        for lag in minLag...maxLag {
            var acc = 0.0
            for i in 0..<(n - lag) { acc += env[i] * env[i + lag] }
            let norm = acc / zeroLag
            if norm > bestVal { bestVal = norm; bestLag = lag }
        }
        guard bestVal > 0.3, bestLag > 0 else { return nil }
        let periodSeconds = Double(bestLag) / sampleRate
        let rate = 60.0 / periodSeconds
        return (8...30).contains(rate) ? rate : nil
    }

    /// Down-sample a waveform to at most `maxCount` points for preview/storage.
    private func downsample(_ x: [Double], to maxCount: Int) -> [Double] {
        guard x.count > maxCount, maxCount > 0 else { return x }
        let stride = Double(x.count) / Double(maxCount)
        return (0..<maxCount).map { x[Int(Double($0) * stride)] }
    }
}
