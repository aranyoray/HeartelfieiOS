import Foundation

/// Centralised, non-diagnostic copy. Keeping every disclaimer in one place makes
/// it easy to review that nothing in the app reads as a medical claim.
public enum Disclaimers {

    /// Persistent emergency notice shown across the app.
    public static let emergency = """
    If you think you're having a cardiac event, call your local emergency services \
    right away. Do not rely on this app.
    """

    /// Short screening label.
    public static let screening = "Screening — not a medical measurement."

    /// General product framing.
    public static let notDiagnostic = """
    DailyDil offers wellness and screening insights. It does not diagnose, treat, \
    or rule out any medical condition.
    """

    /// Explicit medical-device disclaimer for App Store review and onboarding.
    public static let notMedicalDevice = """
    DailyDil is not a medical device and is not intended to diagnose, treat, cure, \
    or prevent any disease or condition. All readings are wellness and screening \
    insights only. Always consult a qualified healthcare professional about your health.
    """

    /// Consent summary shown at onboarding.
    public static let consentSummary = """
    DailyDil helps you keep an eye on your cardiovascular wellness with daily \
    checks. Phone-based checks are screenings, not medical measurements. Your data \
    stays encrypted on your device unless you choose to export it. You can delete \
    everything at any time.
    """

    /// "What this does / doesn't mean" copy for a modality's result screen.
    public static func whatItMeans(for modality: Modality) -> String {
        switch modality {
        case .fingerPPG, .facialRPPG:
            return "This gives you a quick wellness snapshot of your heart rate and its variability, useful for spotting day-to-day trends."
        }
    }

    public static func whatItDoesNotMean(for modality: Modality) -> String {
        switch modality {
        case .fingerPPG, .facialRPPG:
            return "This is a screening, not a diagnosis. It can't confirm or rule out any heart condition. If something feels wrong, do not rely on this app."
        }
    }

    /// Disclosure of how Monk Skin Tone is used (mirrors `MonkSkinTone.usageDisclosure`).
    public static let skinToneUsage = MonkSkinTone.usageDisclosure
}
