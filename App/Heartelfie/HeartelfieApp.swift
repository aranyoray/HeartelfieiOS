import SwiftUI
import HEFeatures

/// The Heartelfie app entry point. Deliberately thin: it hands off to
/// `RootView` in `HEFeatures`, which owns the composition root (sensors,
/// inference, encrypted persistence) and routes between onboarding and the
/// main tab experience.
@main
struct HeartelfieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
