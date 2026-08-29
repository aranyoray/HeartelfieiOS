import SwiftUI
import HECore
import HEDesign

/// Step 1 — Welcome / value proposition.
///
/// Warm, premium first impression that explains what DailyDil is for (gentle
/// daily cardiovascular self-checks from the phone) in plain language. Sets a
/// calm, non-diagnostic tone from the very first screen.
struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            hero
                .heEntrance(0)

            VStack(alignment: .leading, spacing: HESpacing.sm) {
                Text("A gentle daily check-in for your heart")
                    .font(.heLargeTitle)
                    .foregroundStyle(Color.heTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("DailyDil helps you notice how your cardiovascular wellness changes day to day, using just your phone.")
                    .font(.heBody)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .heEntrance(1)

            VStack(alignment: .leading, spacing: HESpacing.md) {
                Text("How you check in")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                tierCard(
                    tier: .screening,
                    title: "Phone screening",
                    detail: "Quick, everyday wellness snapshots from your phone's camera. Great for spotting trends."
                )
            }
            .heEntrance(2)

            Label(Disclaimers.notDiagnostic, systemImage: "info.circle")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .heEntrance(3)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        HEHeroCard {
            VStack(spacing: HESpacing.sm) {
                // A softly pulsing heart, framed inside the app glyph, for a warm
                // living first impression. Calm/static under Reduce Motion.
                ZStack {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.white)

                    PulseHeartView(bpm: 68)
                        .frame(width: HEIcon.md, height: HEIcon.md)
                        .offset(y: 2)
                }
                .accessibilityHidden(true)

                Text("Welcome to DailyDil")
                    .font(.heTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HESpacing.lg)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to DailyDil")
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
