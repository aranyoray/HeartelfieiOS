import Foundation

/// Coarse confidence band for display and for driving the low-confidence recheck
/// loop.
public enum ConfidenceBand: String, Codable, Sendable, Hashable, CaseIterable {
    case low, moderate, high

    public var displayName: String {
        switch self {
        case .low: return "Low confidence"
        case .moderate: return "Moderate confidence"
        case .high: return "High confidence"
        }
    }
}

/// A confidence value in `0...1` attached to every reading, with a derived band.
/// Low confidence on a device measurement triggers a recheck / partner-clinic
/// pathway.
public struct Confidence: Codable, Sendable, Hashable, Comparable {
    public let value: Double

    public init(_ value: Double) {
        self.value = min(max(value, 0), 1)
    }

    public var band: ConfidenceBand {
        switch value {
        case ..<ClinicalConfig.lowConfidenceThreshold: return .low
        case ..<0.75: return .moderate
        default: return .high
        }
    }

    public var isLow: Bool { band == .low }

    /// Formatted as a whole percentage, e.g. "82%".
    public var percentString: String {
        "\(Int((value * 100).rounded()))%"
    }

    public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        lhs.value < rhs.value
    }
}
