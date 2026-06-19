import SwiftUI
import HECore
import HEDesign

/// Step 2 — Staged permission priming.
///
/// Explains *why* Heartelfie will ask for each capability before iOS ever shows a
/// system prompt. This is rationale-only: tapping through here does **not** trigger
/// the real camera/motion/microphone/Bluetooth/notification permission dialogs —
/// those are requested in context at first use. The one exception is HealthKit,
/// which offers an opt-in "Connect" action wired to
/// `AppEnvironment.enableHealthKit()`.
struct OnboardingPermissionsStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            HESectionHeader(
                title: "What Heartelfie may ask for",
                subtitle: "We only request something when it's needed for a check — and we'll explain why each time.",
                systemImage: "hand.raised.fill"
            )

            VStack(spacing: HESpacing.sm) {
                ForEach(PermissionPrimer.all) { primer in
                    PermissionRow(primer: primer)
                }
            }

            HealthKitPrimingCard()

            Label("You stay in control. You can change any of these later in Settings, and skip the ones you don't need.", systemImage: "lock.shield")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
        }
    }
}

/// A single capability with the plain-language reason Heartelfie needs it.
private struct PermissionPrimer: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let rationale: String

    static let all: [PermissionPrimer] = [
        PermissionPrimer(
            id: "camera",
            title: "Camera",
            systemImage: "camera.fill",
            rationale: "Reads subtle color changes in your fingertip or face to estimate your pulse."
        ),
        PermissionPrimer(
            id: "motion",
            title: "Motion & fitness",
            systemImage: "figure.walk.motion",
            rationale: "Senses the tiny vibrations of your heartbeat and helps flag movement that blurs a reading."
        ),
        PermissionPrimer(
            id: "microphone",
            title: "Microphone",
            systemImage: "mic.fill",
            rationale: "Listens to your heart sounds for the experimental sound-based check."
        ),
        PermissionPrimer(
            id: "bluetooth",
            title: "Bluetooth",
            systemImage: "sensor.tag.radiowaves.forward.fill",
            rationale: "Connects to your Heartelfie device for higher-confidence measurements."
        ),
        PermissionPrimer(
            id: "notifications",
            title: "Notifications",
            systemImage: "bell.fill",
            rationale: "Optional, gentle reminders so a daily check-in becomes an easy habit."
        )
    ]
}

/// One rationale row. Combined into a single accessibility element so VoiceOver
/// reads the capability and its reason together.
private struct PermissionRow: View {
    let primer: PermissionPrimer

    var body: some View {
        HECard {
            HStack(alignment: .top, spacing: HESpacing.md) {
                Image(systemName: primer.systemImage)
                    .font(.heHeadline)
                    .foregroundStyle(Color.hePrimary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: HESpacing.xxs) {
                    Text(primer.title)
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Text(primer.rationale)
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(primer.title). \(primer.rationale)")
    }
}

/// HealthKit gets its own card because it offers an explicit opt-in here. The state
/// reflects whether the user has tapped Connect this session; the real
/// authorization sheet is presented by `AppEnvironment.enableHealthKit()`.
private struct HealthKitPrimingCard: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isConnecting = false
    @State private var didRequest = false

    var body: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                HStack(alignment: .top, spacing: HESpacing.md) {
                    Image(systemName: "heart.circle.fill")
                        .font(.heHeadline)
                        .foregroundStyle(Color.hePrimary)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: HESpacing.xxs) {
                        Text("Apple Health")
                            .font(.heHeadline)
                            .foregroundStyle(Color.heTextPrimary)
                        Text("Optionally save your readings to Apple Health, so they live alongside the rest of your wellness data.")
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                if didRequest {
                    Label("Health permission requested. You can fine-tune what's shared in the Health app.", systemImage: "checkmark.circle.fill")
                        .font(.heCaption)
                        .foregroundStyle(Color.heRisk(.normal))
                        .accessibilityElement(children: .combine)
                } else {
                    HESecondaryButton(
                        "Connect Apple Health",
                        systemImage: "heart.fill",
                        isLoading: isConnecting
                    ) {
                        connect()
                    }
                    .accessibilityHint("Opens the system Health permission sheet")
                }
            }
        }
    }

    private func connect() {
        guard !isConnecting else { return }
        isConnecting = true
        Task {
            await env.enableHealthKit()
            isConnecting = false
            didRequest = true
        }
    }
}

#Preview("Permissions step") {
    ScrollView {
        OnboardingPermissionsStep()
            .padding(HESpacing.lg)
    }
    .background(Color.heBackground)
    .environment(AppEnvironment.preview(onboarded: false))
}
