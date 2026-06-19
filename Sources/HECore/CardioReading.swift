import Foundation

/// The output of one full capture pipeline run:
/// `acquire → SQI gate → filter → feature-extract → infer → CardioReading`.
///
/// Every reading is self-describing: it always carries its tier, confidence,
/// signal quality, model provenance, and a plain-language, non-diagnostic
/// interpretation. (Named `CardioReading` rather than `Result` to avoid clashing
/// with `Swift.Result`.)
public struct CardioReading: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let modality: Modality
    public let tier: MeasurementTier
    public let metrics: [CardioMetric]
    public let confidence: Confidence
    public let signalQuality: SignalQuality
    public let provenance: Provenance
    /// Plain-language, explicitly non-diagnostic interpretation.
    public let interpretation: String
    /// Skin tone passed into processing, recorded for transparency.
    public let monkSkinTone: MonkSkinTone?
    /// Down-sampled waveform for replay/preview in the result detail screen.
    public let waveformPreview: [Double]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        modality: Modality,
        tier: MeasurementTier? = nil,
        metrics: [CardioMetric],
        confidence: Confidence,
        signalQuality: SignalQuality,
        provenance: Provenance,
        interpretation: String,
        monkSkinTone: MonkSkinTone? = nil,
        waveformPreview: [Double] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.modality = modality
        self.tier = tier ?? modality.tier
        self.metrics = metrics
        self.confidence = confidence
        self.signalQuality = signalQuality
        self.provenance = provenance
        self.interpretation = interpretation
        self.monkSkinTone = monkSkinTone
        self.waveformPreview = waveformPreview
    }

    /// The headline metric for compact cards (heart rate when present).
    public var primaryMetric: CardioMetric? {
        metrics.first(where: { $0.kind == .heartRate }) ?? metrics.first
    }

    /// The worst (highest) risk across all metrics — drives the overall status.
    public var overallRisk: RiskLevel {
        metrics.map(\.risk).max() ?? .unknown
    }

    public func metric(_ kind: MetricKind) -> CardioMetric? {
        metrics.first(where: { $0.kind == kind })
    }
}
