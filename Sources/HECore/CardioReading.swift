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
        visibleMetrics.first(where: { $0.kind == .heartRate }) ?? visibleMetrics.first
    }

    /// Metrics shown in DailyDil's current product surface.
    public var visibleMetrics: [CardioMetric] {
        metrics.filter { $0.kind.isVisibleInDailyDil }
    }

    /// The worst (highest) risk across all metrics — drives the overall status.
    public var overallRisk: RiskLevel {
        visibleMetrics.map(\.risk).max() ?? .unknown
    }

    public func metric(_ kind: MetricKind) -> CardioMetric? {
        metrics.first(where: { $0.kind == kind })
    }

    // MARK: - Resilient decoding

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, modality, tier, metrics, confidence,
             signalQuality, provenance, interpretation, monkSkinTone,
             waveformPreview
    }

    /// Decodes `T` if possible, otherwise `nil` — used to skip individual
    /// metrics whose kind no longer exists without dropping the whole reading
    /// (and its heart-rate/HRV history) from the store.
    private struct LossyMetric: Decodable {
        let value: CardioMetric?
        init(from decoder: Decoder) throws {
            value = try? CardioMetric(from: decoder)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.modality = try c.decode(Modality.self, forKey: .modality)
        let modality = self.modality
        self.tier = (try? c.decode(MeasurementTier.self, forKey: .tier)) ?? modality.tier
        let lossy = (try? c.decode([LossyMetric].self, forKey: .metrics)) ?? []
        self.metrics = lossy.compactMap(\.value)
        self.confidence = try c.decode(Confidence.self, forKey: .confidence)
        self.signalQuality = try c.decode(SignalQuality.self, forKey: .signalQuality)
        self.provenance = try c.decode(Provenance.self, forKey: .provenance)
        self.interpretation = try c.decode(String.self, forKey: .interpretation)
        self.monkSkinTone = try c.decodeIfPresent(MonkSkinTone.self, forKey: .monkSkinTone)
        self.waveformPreview = try c.decodeIfPresent([Double].self, forKey: .waveformPreview) ?? []
    }
}
