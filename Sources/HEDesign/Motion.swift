import SwiftUI

// MARK: - Motion tokens

/// Shared animation curves so motion reads consistently across the app. Anything
/// that moves a large distance must still gate on `accessibilityReduceMotion`.
public enum HEMotion {
    /// Lively-but-settled spring for content entrances and layout changes.
    public static let spring = Animation.spring(response: 0.52, dampingFraction: 0.82)
    /// Snappier spring for controls and small state flips.
    public static let snappy = Animation.spring(response: 0.34, dampingFraction: 0.76)
    /// Gentle cross-fade.
    public static let fade = Animation.easeInOut(duration: 0.28)
    /// Per-item stagger step (seconds) for section/list entrances.
    public static let stagger: Double = 0.06
}

// MARK: - Icon & layout scales

/// Square frame sizes for glyphs and avatars, so icon sizing stops being a set of
/// scattered magic numbers.
public enum HEIcon {
    public static let sm: CGFloat = 20
    public static let md: CGFloat = 28
    public static let lg: CGFloat = 34
    /// Minimum comfortable tap target.
    public static let tap: CGFloat = 44
}

// MARK: - Entrance

/// A one-shot entrance: content fades and rises into place on first appear,
/// staggered by `index`. Respects Reduce Motion (plain fade, no movement). Apply
/// to the major sections of a screen for a lively, premium arrival.
public struct HEEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var shown = false

    public func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: (shown || reduceMotion) ? 0 : 16)
            .onAppear {
                let delay = Double(index) * HEMotion.stagger
                withAnimation((reduceMotion ? HEMotion.fade : HEMotion.spring).delay(delay)) {
                    shown = true
                }
            }
    }
}

public extension View {
    /// Staggered fade-and-rise entrance for a screen section. `index` orders the stagger.
    func heEntrance(_ index: Int = 0) -> some View {
        modifier(HEEntrance(index: index))
    }
}

// MARK: - Ambient background

/// The ambient app field: a soft vertical wash with two faint brand-tinted glows
/// behind content. Richer than a flat fill while staying calm and readable. Use as
/// a screen background in place of `Color.heBackground`.
public struct HEAmbientBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.heBackground
            LinearGradient(
                colors: [Color.hePrimary.opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .center
            )
            RadialGradient(
                colors: [Color.heAccent.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 360
            )
            RadialGradient(
                colors: [Color.hePrimary.opacity(0.09), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}

public extension View {
    /// Places the ambient brand field behind this view.
    func heAmbientBackground() -> some View {
        background(HEAmbientBackground())
    }
}
