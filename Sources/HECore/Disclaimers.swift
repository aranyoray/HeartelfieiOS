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
    Heartelfie offers wellness and screening insights. It does not diagnose, treat, \
    or rule out any medical condition.
    """

    /// Explicit medical-device disclaimer for App Store review and onboarding.
    public static let notMedicalDevice = """
    Heartelfie is not a medical device and is not intended to diagnose, treat, cure, \
    or prevent any disease or condition. All readings are wellness and screening \
    insights only. Always consult a qualified healthcare professional about your health.
    """

    /// Consent summary shown at onboarding.
    public static let consentSummary = """
    Heartelfie helps you keep an eye on your cardiovascular wellness with daily \
    checks. Phone-based checks are screenings, not medical measurements. Your data \
    stays encrypted on your device unless you choose to export it. You can delete \
    everything at any time.
    """

    /// "What this does / doesn't mean" copy for a modality's result screen.
    public static func whatItMeans(for modality: Modality) -> String {
        switch modality {
        case .fingerPPG, .facialRPPG:
            return "This gives you a quick wellness snapshot of your heart rate and its variability, useful for spotting day-to-day trends."
        case .scg:
            return "This experimental check senses the mechanical vibration of your heartbeat to estimate rate and beat timing."
        case .pcg:
            return "This experimental check listens to your heart sounds and flags anything that sounds unusual for you to follow up on."
        case .deviceMultiWavelengthPPG:
            return "Your Heartelfie device uses multiple light wavelengths for a higher-confidence oxygen-carry and oxygen wellness reading."
        case .deviceECG:
            return "Your Heartelfie device records the electrical rhythm of your heart for a higher-confidence rhythm reading."
        case .deviceBioZ:
            return "Your Heartelfie device estimates hydration from how your body conducts a tiny, safe electrical signal."
        }
    }

    public static func whatItDoesNotMean(for modality: Modality) -> String {
        switch modality {
        case .fingerPPG, .facialRPPG, .scg, .pcg:
            return "This is a screening, not a diagnosis. It can't confirm or rule out any heart condition. If something feels wrong, talk to a clinician."
        case .deviceMultiWavelengthPPG, .deviceECG, .deviceBioZ:
            return "Even with the device, this is a wellness reading — not a diagnosis. Unusual results are a reason to talk to a clinician, not a conclusion."
        }
    }

    /// Disclosure of how Monk Skin Tone is used (mirrors `MonkSkinTone.usageDisclosure`).
    public static let skinToneUsage = MonkSkinTone.usageDisclosure
}
