import Foundation

/// Non-diagnostic, actionable care guidance for a reading context. Centralised so
/// the tips and the "should we surface care access" decision live in one place and
/// stay consistent across the result and insights screens.
///
/// Nothing here is a diagnosis. Tips are calm, general self-care and care-access
/// prompts — never instructions to treat a condition.
public enum CareGuidance {

    /// How urgently to frame care access for a reading.
    public enum Urgency: Sendable, Hashable {
        case emergency   // elevated — lead with immediate help
        case routine     // clinical / watch — lead with next steps
    }

    /// Whether to surface the care-access card for this reading context.
    ///
    /// Shown for **clinical (device measurement) readings** — where the user asked
    /// for tips + immediate care links — and for any **elevated** reading on any
    /// tier, where reaching care matters most.
    public static func shouldSurfaceCare(tier: MeasurementTier, risk: RiskLevel) -> Bool {
        tier == .measurement || risk == .elevated
    }

    public static func urgency(risk: RiskLevel) -> Urgency {
        risk == .elevated ? .emergency : .routine
    }

    /// Ordered, non-diagnostic tips for a reading context (most relevant first).
    public static func tips(tier: MeasurementTier, risk: RiskLevel, lowConfidence: Bool) -> [String] {
        var tips: [String] = []

        if lowConfidence {
            tips.append("This reading was low confidence — re-check when you're relaxed and still before drawing any conclusion.")
        }

        switch risk {
        case .elevated:
            tips.append("Sit down, rest, and breathe calmly, then take another reading.")
            tips.append("Note any symptoms — chest pain or pressure, shortness of breath, dizziness, or fainting — and when they began.")
            tips.append("If symptoms are severe, sudden, or getting worse, treat it as an emergency and get help now.")
        case .watch:
            tips.append("Re-check later today when you're rested; a single reading rarely means much on its own.")
            tips.append("Keep tracking the trend and share it with a clinician if it continues.")
        case .normal, .unknown:
            tips.append("Bring this reading and your recent trend to a clinician at your next visit.")
        }

        if tier == .measurement {
            tips.append("Avoid caffeine, nicotine, and exercise right before a measurement for the cleanest reading.")
        }

        return tips
    }
}
