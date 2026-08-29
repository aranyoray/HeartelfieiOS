import SwiftUI

// MARK: - Card button style

/// A tactile press style for whole-card tap targets (rows, tiles, trend cards).
///
/// Unlike `PrimaryButtonStyle`, this draws no chrome of its own — the card
/// already provides its surface, border, and shadow. It only adds a subtle
/// press response: a small scale-down plus a faint dim, animated with the
/// shared `HEMotion.snappy`, and a light haptic tap on press-down.
///
/// The scale is gated on Reduce Motion (the dim still applies there, since a
/// gentle opacity change reads as a state cue rather than motion).
public struct HECardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(reduceMotion ? nil : HEMotion.snappy, value: configuration.isPressed)
            // Light haptic on the press transition (SwiftUI drives it; no UIKit).
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

// MARK: - Convenience

public extension View {
    /// Applies `HECardButtonStyle` to a tappable card/row `Button` or
    /// `NavigationLink`, giving it a subtle scale + light haptic on press.
    func heCardButtonStyle() -> some View {
        buttonStyle(HECardButtonStyle())
    }
}
