import SwiftUI
import HECore
import HEDesign

/// Step 5 — Consent, privacy summary, and emergency disclaimer.
///
/// The final gate before onboarding can complete. Surfaces the consent summary,
/// an unmissable emergency notice, and a plain-language privacy summary
/// (on-device encrypted storage, export/delete anytime), then requires an
/// affirmative consent toggle. The host view keeps its finish button disabled
/// until `draft.hasAcceptedConsent` is true.
struct OnboardingConsentStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            HESectionHeader(
                title: "Before you start",
                subtitle: "A quick summary of what DailyDil is — and isn't.",
                systemImage: "checkmark.shield.fill"
            )

            HECard {
                Text(Disclaimers.consentSummary)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Summary. \(Disclaimers.consentSummary)")

            HECard {
                Label(Disclaimers.notMedicalDevice, systemImage: "info.circle")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Disclaimers.notMedicalDevice)

            EmergencyNotice()

            privacyCard

            consentToggle
        }
    }

    // MARK: - Privacy

    private var privacyCard: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                Label("Your privacy", systemImage: "lock.fill")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                privacyPoint(
                    systemImage: "iphone.gen3",
                    text: "Your readings are stored encrypted on this device."
                )
                privacyPoint(
                    systemImage: "square.and.arrow.up",
                    text: "Nothing is shared unless you choose to export it."
                )
                privacyPoint(
                    systemImage: "trash",
                    text: "You can delete all of your data at any time, from Settings."
                )
            }
        }
    }

    private func privacyPoint(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: HESpacing.sm) {
            Image(systemName: systemImage)
                .font(.heCallout)
                .foregroundStyle(Color.hePrimary)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    // MARK: - Consent toggle

    private var consentToggle: some View {
        HECard {
            Toggle(isOn: $draft.hasAcceptedConsent) {
                Text("I understand DailyDil offers wellness and screening insights, not a medical diagnosis.")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Color.hePrimary)
            .accessibilityHint("Required to start using DailyDil")
        }
    }
}

#Preview("Consent step") {
    ScrollView {
        OnboardingConsentStep(draft: OnboardingDraft())
            .padding(HESpacing.lg)
    }
    .background(Color.heBackground)
    .environment(AppEnvironment.preview(onboarded: false))
}
