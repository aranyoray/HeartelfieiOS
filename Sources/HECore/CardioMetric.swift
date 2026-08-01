import Foundation

/// A single computed metric within a reading. Carries its own reference range and
/// softened risk classification so the UI can render it honestly and consistently.
public struct CardioMetric: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let kind: MetricKind
    public let value: Double
    public let unit: String
    public let risk: RiskLevel
    public let referenceRange: ClinicalRange?
    /// Optional note, e.g. "approximate" for screening SpO₂.
    public let note: String?

    public init(
        id: UUID = UUID(),
        kind: MetricKind,
        value: Double,
        unit: String? = nil,
        risk: RiskLevel? = nil,
        referenceRange: ClinicalRange? = nil,
        note: String? = nil,
        profile: HealthProfile? = nil
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.unit = unit ?? kind.unit
        let range = referenceRange ?? ClinicalConfig.referenceRange(for: kind, profile: profile)
        self.referenceRange = range
        self.risk = risk ?? range?.classify(value) ?? .unknown
        self.note = note
    }

    /// Value formatted to the metric's natural precision (no unit).
    public var formattedValue: String {
        value.formatted(.number.precision(.fractionLength(kind.fractionDigits)))
    }

    /// Value plus unit, e.g. "72 bpm".
    public var formattedValueWithUnit: String {
        unit.isEmpty ? formattedValue : "\(formattedValue) \(unit)"
    }
}
