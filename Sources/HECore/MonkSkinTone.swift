import Foundation

/// A self-selected position on the 10-point Monk Skin Tone (MST) scale.
///
/// Skin-tone equity is a first-class feature: this value is captured optionally
/// during onboarding, passed into the processing/ML layer (optical PPG signals
/// vary with melanin), and its use is disclosed to the user. Heartelfie targets
/// equitable performance across MST 4–10.
public struct MonkSkinTone: Codable, Sendable, Hashable, Identifiable, Comparable {
    /// The 1...10 MST position. 1 is lightest, 10 is darkest.
    public let value: Int

    public init?(value: Int) {
        guard (1...10).contains(value) else { return nil }
        self.value = value
    }

    /// Unchecked initializer for compile-time-known constants.
    private init(unchecked value: Int) { self.value = value }

    public var id: Int { value }

    /// All ten tones, ordered light → dark.
    public static let all: [MonkSkinTone] = (1...10).map { MonkSkinTone(unchecked: $0) }

    /// Representative swatch hex for each tone (approximations of the public Monk
    /// Skin Tone scale; used purely for the onboarding selector UI).
    public var swatchHex: String {
        switch value {
        case 1: return "F6EDE4"
        case 2: return "F3E7DB"
        case 3: return "F7EAD0"
        case 4: return "EADABA"
        case 5: return "D7BD96"
        case 6: return "A07E56"
        case 7: return "825C43"
        case 8: return "604134"
        case 9: return "3A312A"
        default: return "292420"
        }
    }

    public var accessibilityLabel: String { "Monk skin tone \(value) of 10" }

    /// User-facing disclosure of why Heartelfie asks for this and how it's used.
    public static let usageDisclosure = """
    Optical heart readings can behave differently across skin tones. Sharing your \
    skin tone (optional) helps DailyDil calibrate signal processing so screenings \
    work more equitably for everyone. It stays on your device and is only used to \
    tune measurement quality — never to identify you.
    """

    public static func < (lhs: MonkSkinTone, rhs: MonkSkinTone) -> Bool {
        lhs.value < rhs.value
    }
}
