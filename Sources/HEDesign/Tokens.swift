import SwiftUI

// MARK: - Spacing

/// The Heartelfie spacing scale. Generous whitespace is a core part of the
/// "clinical-calm meets premium" tone, so steps grow on an 8-pt rhythm with a
/// couple of finer values for tight, glanceable layouts.
public enum HESpacing {
    /// 2 pt — hairline gaps between tightly coupled glyphs/labels.
    public static let xxs: CGFloat = 2
    /// 4 pt — icon-to-label spacing inside chips.
    public static let xs: CGFloat = 4
    /// 8 pt — default intra-component spacing.
    public static let sm: CGFloat = 8
    /// 16 pt — standard card padding / stack spacing.
    public static let md: CGFloat = 16
    /// 24 pt — comfortable section spacing.
    public static let lg: CGFloat = 24
    /// 32 pt — large section breaks.
    public static let xl: CGFloat = 32
    /// 48 pt — hero / screen-level breathing room.
    public static let xxl: CGFloat = 48
}

// MARK: - Corner radius

/// Continuous corner radii used across the design system. Pair these with
/// `RoundedRectangle(cornerRadius:style: .continuous)` for soft, premium edges.
public enum HERadius {
    /// 8 pt — small controls, chips.
    public static let sm: CGFloat = 8
    /// 12 pt — inset elements within cards.
    public static let md: CGFloat = 12
    /// 20 pt — standard cards / surfaces.
    public static let lg: CGFloat = 20
    /// 28 pt — large hero surfaces.
    public static let xl: CGFloat = 28
    /// A very large radius that reads as a fully rounded pill.
    public static let pill: CGFloat = 999
}

// MARK: - Elevation / shadow

/// Soft depth tokens. The design tone favours gentle, diffuse shadows that
/// suggest calm depth rather than hard drop-shadows.
public enum HEShadow {
    /// The default soft card elevation. Returns the components needed for a
    /// SwiftUI `.shadow` call so they can be applied consistently.
    public static func card() -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (color: Color.heShadow, radius: 18, x: 0, y: 10)
    }

    /// A subtler elevation for chips and inline surfaces.
    public static func subtle() -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (color: Color.heShadow, radius: 8, x: 0, y: 4)
    }
}

public extension View {
    /// Applies the standard soft Heartelfie card elevation.
    func heCardShadow() -> some View {
        let s = HEShadow.card()
        return shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    /// Applies the subtler chip/inline elevation.
    func heSubtleShadow() -> some View {
        let s = HEShadow.subtle()
        return shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}
