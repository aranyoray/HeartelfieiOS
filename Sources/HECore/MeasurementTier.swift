import Foundation

/// The two explicit trust tiers that flow through every reading in Heartelfie.
///
/// This distinction is a *Critical Constraint*: the UI and data model must always
/// make clear where a signal came from and how trustworthy it is. Phone-only
/// sensors are wellness-grade `.screening`; the Heartelfie hardware device path is
/// clinical-grade `.measurement`.
public enum MeasurementTier: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    /// Wellness-grade screening from the phone's own sensors. Lower confidence.
    /// Never to be presented as a medical measurement or diagnosis.
    case screening

    /// Higher-accuracy, clinical-grade path that is only available through the
    /// connected Heartelfie hardware device.
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
        case .measurement: return "Measurement (device)"
        }
    }

    /// The mandatory non-diagnostic disclaimer shown alongside readings of this tier.
    public var disclaimer: String {
        switch self {
        case .screening:
            return "Screening — not a medical measurement."
        case .measurement:
            return "Device measurement — for wellness, not diagnosis."
        }
    }

    /// Whether this tier represents the clinical-grade hardware path.
    public var isClinicalGrade: Bool { self == .measurement }

    /// Whether readings of this tier require the Heartelfie device to be connected.
    public var requiresDevice: Bool { self == .measurement }
}
