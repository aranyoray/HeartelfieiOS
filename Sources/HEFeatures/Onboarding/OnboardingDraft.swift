import SwiftUI
import Observation
import HECore

/// Mutable, in-flight collection of everything the onboarding flow gathers before
/// it is assembled into a `HealthProfile` and handed to
/// `AppEnvironment.completeOnboarding(_:)`.
///
/// Every field except the unit system is optional — the flow is designed so a user
/// can move through it tapping "Skip" the whole way and still finish with a valid,
/// minimal profile. Height/weight are entered in the user's chosen `UnitSystem`
/// but always normalised to centimetres/kilograms when the profile is built.
@MainActor
@Observable
final class OnboardingDraft {

    // MARK: Skin tone (step 3)

    /// The selected Monk Skin Tone, or `nil` if the user preferred not to say.
    var monkSkinTone: MonkSkinTone?

    // MARK: Health profile (step 4)

    var unitSystem: UnitSystem = .metric

    /// Whether the user chose to share an age. When `false`, `age` is omitted.
    var includeAge: Bool = false
    var age: Int = 35

    var biologicalSex: BiologicalSex = .preferNotToSay

    /// Whether the user chose to share a height.
    var includeHeight: Bool = false
    /// Height in the user's current display unit (cm when metric, inches when
    /// imperial). Normalised to centimetres when the profile is assembled.
    var heightValue: Double = 170

    /// Whether the user chose to share a weight.
    var includeWeight: Bool = false
    /// Weight in the user's current display unit (kg when metric, lb when
    /// imperial). Normalised to kilograms when the profile is assembled.
    var weightValue: Double = 70

    var knownConditions: [String] = []

    // MARK: Consent (step 5)

    /// The user must affirmatively accept before onboarding can finish.
    var hasAcceptedConsent: Bool = false

    // MARK: Unit conversion

    private static let cmPerInch = 2.54
    private static let kgPerPound = 0.45359237

    /// Normalises the current `heightValue` (display unit) to centimetres.
    private var heightCM: Double {
        unitSystem == .metric ? heightValue : heightValue * Self.cmPerInch
    }

    /// Normalises the current `weightValue` (display unit) to kilograms.
    private var weightKG: Double {
        unitSystem == .metric ? weightValue : weightValue * Self.kgPerPound
    }

    /// Re-expresses the entered height/weight when the user flips the unit system,
    /// so the on-screen number stays physically the same measurement.
    func convertEnteredValues(to newSystem: UnitSystem) {
        guard newSystem != unitSystem else { return }
        switch newSystem {
        case .imperial:
            heightValue = (heightValue / Self.cmPerInch).rounded()
            weightValue = (weightValue / Self.kgPerPound).rounded()
        case .metric:
            heightValue = (heightValue * Self.cmPerInch).rounded()
            weightValue = (weightValue * Self.kgPerPound).rounded()
        }
        unitSystem = newSystem
    }

    // MARK: Assembly

    /// Builds the finished, persisted profile from the collected input. Only the
    /// fields the user opted into are included; the rest stay `nil`.
    func makeProfile() -> HealthProfile {
        HealthProfile(
            age: includeAge ? age : nil,
            biologicalSex: biologicalSex == .preferNotToSay ? nil : biologicalSex,
            heightCM: includeHeight ? (heightCM * 10).rounded() / 10 : nil,
            weightKG: includeWeight ? (weightKG * 10).rounded() / 10 : nil,
            knownConditions: knownConditions,
            monkSkinTone: monkSkinTone,
            unitSystem: unitSystem
        )
    }
}
