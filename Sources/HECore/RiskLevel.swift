import Foundation

/// A *softened* traffic-light status used for at-a-glance interpretation.
///
/// Deliberately never alarmist: copy uses calm, non-diagnostic language and the
/// design system maps these to a colorblind-safe, softened palette (never a pure,
/// alarming red by default). Status is also surfaced with shape/label cues so it
/// is never color-dependent.
public enum RiskLevel: String, Codable, Sendable, CaseIterable, Hashable, Comparable {
    /// Within the configured typical range.
    case normal
    /// Slightly outside the typical range — worth keeping an eye on.
    case watch
    /// Notably outside the typical range — consider a follow-up.
    case elevated
    /// Not enough signal to classify.
    case unknown

    public var displayName: String {
        switch self {
        case .normal: return "Typical"
        case .watch: return "Keep an eye on"
        case .elevated: return "Worth a check"
        case .unknown: return "Unclassified"
        }
    }

    /// Non-color status glyph so meaning survives without color (accessibility).
    public var systemImage: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .watch: return "exclamationmark.circle.fill"
        case .elevated: return "arrow.up.forward.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    /// Gentle, non-diagnostic guidance string.
    public var guidance: String {
        switch self {
        case .normal:
            return "This reading is within a typical range. Keep up your daily checks."
        case .watch:
            return "This reading is a little outside the typical range. Re-check when relaxed and keep tracking the trend."
        case .elevated:
            return "This reading is outside the typical range. It is not a diagnosis — consider discussing your trend with a clinician."
        case .unknown:
            return "There wasn't enough clean signal to interpret this reading."
        }
    }

    private var sortOrder: Int {
        switch self {
        case .unknown: return 0
        case .normal: return 1
        case .watch: return 2
        case .elevated: return 3
        }
    }

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
