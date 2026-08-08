import SwiftUI
import HEDesign

/// Caps screen content to a readable column (~640pt) on wide layouts (iPad,
/// landscape), centering it and filling the gutters with the app background so
/// full-width phone layouts don't stretch edge-to-edge on iPadOS.
struct ContentWidthCap: ViewModifier {
    /// Maximum readable content width on wide layouts.
    static let maxWidth: CGFloat = 640

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: Self.maxWidth)
            .frame(maxWidth: .infinity)
            .background(Color.heBackground.ignoresSafeArea())
    }
}

extension View {
    /// Constrain this screen's content to a readable width on iPad/wide layouts.
    func heContentWidthCapped() -> some View {
        modifier(ContentWidthCap())
    }
}
