import SwiftUI
import HECore
import HEDesign

/// Step 2 - staged permission priming.
///
/// Explains why Heartelfie asks for each capability before iOS shows a system
/// prompt. Camera is requested in context at first use. HealthKit has an explicit
/// opt-in action here.
struct OnboardingPermissionsStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            HESectionHeader(
                title: "What Heartelfie may ask for",
                subtitle: "We only request access when it is needed for a check, and we explain why first.",
                systemImage: "hand.raised.fill"
            )

            VStack(spacing: HESpacing.sm) {
                ForEach(PermissionPrimer.all) { primer in
                    PermissionRow(primer: primer)
                }
            }

            HealthKitPrimingCard()

            Label("You stay in control. You can change permissions later in Settings and skip ones you do not need.", systemImage: "lock.shield")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
        }
    }
}

/// A single capability and the plain-language reason Heartelfie needs it.
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
            rationale: "Reads subtle color changes in your fingertip or face to estimate pulse for a wellness screening."
        )
    ]
}

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

/// HealthKit gets its own card because it offers an explicit opt-in here.
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
                        Text("Optionally save supported readings to Apple Health so they can live alongside the rest of your wellness data.")
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                if didRequest {
                    Label("Health permission requested. You can fine-tune what is shared in the Health app.", systemImage: "checkmark.circle.fill")
                        .font(.heCaption)
                        .foregroundStyle(Color.heRisk(.normal))
                        .accessibilityElement(children: .combine)
                } else {
                    HESecondaryButton(
                        "Continue",
                        systemImage: "heart.fill",
                        isLoading: isConnecting
                    ) {
                        connect()
                    }
                    .accessibilityHint("Opens the system Health permission sheet.")
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
