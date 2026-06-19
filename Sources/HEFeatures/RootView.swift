import SwiftUI
import HECore
import HEDesign

/// Top-level view. Owns the `AppEnvironment`, injects it into the SwiftUI
/// environment, and routes between onboarding and the main tab experience.
///
/// Marked `@MainActor` so the `@State` default expression can construct the
/// `@MainActor`-isolated `AppEnvironment` from the explicit (public) initializer.
@MainActor
public struct RootView: View {
    @State private var env = AppEnvironment()

    public init() {}

    public var body: some View {
        Group {
            if env.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(env)
        .tint(.hePrimary)
        .task { await env.bootstrap() }
    }
}

#Preview("Onboarded") {
    RootView()
}
