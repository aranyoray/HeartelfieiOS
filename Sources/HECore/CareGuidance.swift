import Foundation

/// Non-diagnostic wellness context for a reading.
///
/// Nothing here diagnoses, treats, or directs medical care. The app may give
/// retake and trend-comparison tips, while the general emergency notice remains
/// separate and user-symptom based.
public enum CareGuidance {
    public enum Urgency: Sendable, Hashable {
        case elevatedContext
        case routine
    }

    /// Whether to surface extra wellness context for this reading.
    public static func shouldSurfaceCare(tier: MeasurementTier, risk: RiskLevel) -> Bool {
        // `.measurement` is only reachable from legacy readings recorded before
        // the hardware tier was retired; keep surfacing care context for those.
        risk == .elevated || risk == .watch || tier == .measurement
    }

    public static func urgency(risk: RiskLevel) -> Urgency {
        risk == .elevated ? .elevatedContext : .routine
    }

    public static func tips(tier: MeasurementTier, risk: RiskLevel, lowConfidence: Bool) -> [String] {
        var tips: [String] = []

        if lowConfidence {
            tips.append("This reading was low confidence. Re-check while relaxed and still before comparing it with your trend.")
        }

        switch risk {
        case .elevated:
            tips.append("Sit down, rest, breathe calmly, then take another reading.")
            tips.append("Compare this result with your recent trend instead of relying on one reading.")
            tips.append("If you feel severe, sudden, or worsening symptoms, use local emergency services rather than this app.")
        case .watch:
            tips.append("Re-check later today when relaxed and compare with your recent baseline.")
            tips.append("Use the trend view to see whether this looks like an isolated reading or a pattern.")
        case .normal:
            tips.append("Keep tracking your baseline. Trends are more useful than a single reading.")
        case .unknown:
            tips.append("Try another reading with better lighting, steadier contact, or less movement.")
        }

        if tier == .screening {
            tips.append("Avoid caffeine, nicotine, and exercise right before a check for the cleanest reading.")
        }

        return tips
    }
}
