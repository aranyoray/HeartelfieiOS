import SwiftUI
import HECore
import HEDesign

/// Step 1 — Welcome / value proposition.
///
/// Warm, premium first impression that explains what Heartelfie is for (gentle
/// daily cardiovascular self-checks) and introduces the two-tier idea — phone
/// screenings vs. higher-confidence device measurements — in plain language. Sets
/// a calm, non-diagnostic tone from the very first screen.
struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            hero

            VStack(alignment: .leading, spacing: HESpacing.sm) {
                Text("A gentle daily check-in for your heart")
                    .font(.heLargeTitle)
                    .foregroundStyle(Color.heTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Heartelfie helps you notice how your cardiovascular wellness changes day to day, using just your phone — and your Heartelfie device when you have one.")
                    .font(.heBody)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: HESpacing.md) {
                Text("Two ways to check in")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                tierCard(
                    tier: .screening,
                    title: "Phone screening",
                    detail: "Quick, everyday wellness snapshots from your phone's camera and sensors. Great for spotting trends."
                )

                tierCard(
                    tier: .measurement,
                    title: "Device measurement",
                    detail: "When your Heartelfie device is connected, you get a higher-confidence reading for a closer look."
                )
            }

            Label(Disclaimers.notDiagnostic, systemImage: "info.circle")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HERadius.xl, style: .continuous)
                .fill(Color.hePrimaryGradient)

            VStack(spacing: HESpacing.sm) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Text("Welcome to Heartelfie")
                    .font(.heTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(HESpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .heCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to Heartelfie")
    }

    // MARK: - Tier card

    private func tierCard(tier: MeasurementTier, title: String, detail: String) -> some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                HStack(spacing: HESpacing.sm) {
                    TierBadge(tier)
                    Text(title)
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Spacer(minLength: 0)
                }
                Text(detail)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tier.displayName). \(title). \(detail)")
    }
}

#Preview("Welcome step") {
    ScrollView {
        OnboardingWelcomeStep()
            .padding(HESpacing.lg)
    }
    .background(Color.heBackground)
    .environment(AppEnvironment.preview(onboarded: false))
}
