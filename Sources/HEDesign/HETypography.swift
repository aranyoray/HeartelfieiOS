import SwiftUI

// MARK: - Typography

/// DailyDil type ramp, built entirely from system (SF Pro) fonts so full
/// Dynamic Type works automatically. Big metric numerals use a rounded design
/// for a friendlier, glanceable feel.
public extension Font {

    /// Oversized, rounded numeral for the hero score / big metric values. A
    /// fixed point size keeps the ring/card layout stable; callers that need it
    /// to grow with Dynamic Type can wrap it in `ScaledMetric`.
    static let heMetricNumeral = Font.system(
        size: 64,
        weight: .bold,
        design: .rounded
    )

    /// A medium glanceable numeral for metric cards.
    static let heMetricNumeralCompact = Font.system(
        size: 34,
        weight: .semibold,
        design: .rounded
    )

    static let heLargeTitle = Font.system(.largeTitle, design: .default).weight(.bold)

    static let heTitle = Font.system(.title2, design: .default).weight(.semibold)

    static let heHeadline = Font.system(.headline, design: .default)

    static let heBody = Font.system(.body, design: .default)

    static let heCallout = Font.system(.callout, design: .default)

    static let heCaption = Font.system(.caption, design: .default)

    /// Rounded caption used for unit suffixes next to big numerals.
    static let heUnit = Font.system(.callout, design: .rounded).weight(.semibold)
}
