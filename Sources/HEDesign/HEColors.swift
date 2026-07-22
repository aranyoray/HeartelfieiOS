import SwiftUI
import HECore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Hex helper

public extension Color {
    /// Creates a `Color` from a 6-digit hex string (with or without a leading
    /// "#"), e.g. `Color(hex: "F6EDE4")`. Invalid input falls back to a neutral
    /// gray so the UI never crashes on bad data.
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&rgb) else {
            self = Color(white: 0.5)
            return
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

// MARK: - Dynamic color factory

private extension Color {
    /// Builds a programmatic light/dark dynamic color (no asset catalog).
static func heDynamic(light: UInt32, dark: UInt32) -> Color {
#if canImport(UIKit)
Color(uiColor: UIColor { trait in
trait.userInterfaceStyle == .dark
? UIColor(hexValue: dark)
: UIColor(hexValue: light)
})
#else
Color(nsColor: NSColor(hexValue: light))
#endif
}
}

#if canImport(UIKit)
private extension UIColor {
convenience init(hexValue: UInt32) {
let r = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
let g = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
let b = CGFloat(hexValue & 0x0000FF) / 255.0
self.init(red: r, green: g, blue: b, alpha: 1.0)
}
}
#elseif canImport(AppKit)
private extension NSColor {
convenience init(hexValue: UInt32) {
let r = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
let g = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
let b = CGFloat(hexValue & 0x0000FF) / 255.0
self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
}
}
#endif

// MARK: - Semantic palette

public extension Color {

    // Surfaces ---------------------------------------------------------------

    /// App background — a soft, warm-cool off-white in light, near-black in dark.
    static let heBackground = Color.heDynamic(light: 0xF4F6F8, dark: 0x0B0F12)

    /// Primary card surface.
    static let heSurface = Color.heDynamic(light: 0xFFFFFF, dark: 0x161B20)

    /// Slightly raised surface (sheets, popovers, nested cards).
    static let heSurfaceElevated = Color.heDynamic(light: 0xFFFFFF, dark: 0x1F262C)

    // Brand ------------------------------------------------------------------

    /// Primary brand color — a calm deep teal/indigo that conveys medical trust.
    static let hePrimary = Color.heDynamic(light: 0x1E6E78, dark: 0x4FB8C4)

    /// A deeper variant of the primary, for gradients and pressed states.
    static let hePrimaryDeep = Color.heDynamic(light: 0x123E54, dark: 0x2C7A88)

    /// Warm accent used sparingly for highlights and selection.
    static let heAccent = Color.heDynamic(light: 0x5B6CCB, dark: 0x8C9BF0)

    // Text -------------------------------------------------------------------

    static let heTextPrimary = Color.heDynamic(light: 0x14202A, dark: 0xF2F5F7)
    static let heTextSecondary = Color.heDynamic(light: 0x52606B, dark: 0xAEBAC4)
    static let heTextTertiary = Color.heDynamic(light: 0x8593A0, dark: 0x70808C)

    // Lines ------------------------------------------------------------------

    static let heSeparator = Color.heDynamic(light: 0xE2E7EC, dark: 0x2A333B)

    /// Diffuse shadow tint (kept very soft to read as calm depth).
    static let heShadow = Color.heDynamic(light: 0x14202A, dark: 0x000000)
        .opacity(0.10)

    // Gradients --------------------------------------------------------------

    /// The brand gradient used on the score ring and primary buttons.
    static let hePrimaryGradient = LinearGradient(
        colors: [Color.hePrimary, Color.hePrimaryDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Status & tier mapping

public extension Color {

    /// SOFTENED, colorblind-safe risk color. Deliberately never alarmist: the
    /// "elevated" state is a warm coral rather than a pure, saturated red, and
    /// status is always paired with a glyph/label so it is never color-only.
    ///
    /// - normal:   calm teal-green
    /// - watch:    soft amber
    /// - elevated: muted coral / soft red
    /// - unknown:  neutral gray
    static func heRisk(_ risk: RiskLevel) -> Color {
        switch risk {
        case .normal:   return Color.heDynamic(light: 0x2E8B7F, dark: 0x55C2A8)
        case .watch:    return Color.heDynamic(light: 0xC9881F, dark: 0xE6B450)
        case .elevated: return Color.heDynamic(light: 0xD06A5C, dark: 0xE8897A)
        case .unknown:  return Color.heDynamic(light: 0x8593A0, dark: 0x70808C)
        }
    }

    /// A very soft tinted background derived from the risk color, for badges and
    /// banner fills. Tuned to stay calm in both color schemes.
    static func heRiskSoft(_ risk: RiskLevel) -> Color {
        heRisk(risk).opacity(0.14)
    }

    /// Trust-tier color. Screening (phone) leans indigo/accent; measurement
    /// (device) leans teal/primary to signal the clinical-grade path.
    static func heTier(_ tier: MeasurementTier) -> Color {
        switch tier {
        case .screening:   return Color.heDynamic(light: 0x5B6CCB, dark: 0x8C9BF0)
        case .measurement: return Color.heDynamic(light: 0x1E6E78, dark: 0x4FB8C4)
        }
    }

    /// Color for a signal-quality band (used by the SQI coach banner).
    static func heSQI(_ band: SignalQuality.Band) -> Color {
        switch band {
        case .poor: return heRisk(.elevated)
        case .fair: return heRisk(.watch)
        case .good: return heRisk(.normal)
        }
    }

    /// Color for a confidence band; low is distinct but intentionally not alarmist.
    static func heConfidence(_ band: ConfidenceBand) -> Color {
        switch band {
        case .low:      return Color.heDynamic(light: 0xC9881F, dark: 0xE6B450)
        case .moderate: return Color.heAccent
        case .high:     return Color.heRisk(.normal)
        }
    }
}
