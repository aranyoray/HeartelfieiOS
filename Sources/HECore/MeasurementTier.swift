import Foundation

/// The explicit trust tier that flows through every reading in DailyDil.
///
/// Phone camera checks are wellness-grade `.screening`. `.measurement` remains so
/// older saved hardware readings can still decode and display honestly.
public enum MeasurementTier: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    /// Wellness-grade screening from the phone's own sensors. Lower confidence.
    /// Never to be presented as a medical measurement or diagnosis.
    case screening

    /// Legacy higher-confidence hardware path. No longer offered in the product.
    case measurement

    public var id: String { rawValue }

    /// Short label used for compact badges.
    public var shortLabel: String {
        switch self {
        case .screening: return "Screening"
        case .measurement: return "Measurement"
        }
    }

    /// Full, human-readable name for the tier.
    public var displayName: String {
        switch self {
        case .screening: return "Screening (phone)"
        case .measurement: return "Measurement"
        }
    }

    /// The mandatory non-diagnostic disclaimer shown alongside readings of this tier.
    public var disclaimer: String {
        switch self {
        case .screening:
            return "Screening — not a medical measurement."
        case .measurement:
            return "Measurement — for wellness, not diagnosis."
        }
    }
}
