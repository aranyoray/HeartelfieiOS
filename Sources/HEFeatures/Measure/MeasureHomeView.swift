import SwiftUI
import HECore
import HEDesign

/// The Measure tab's modality picker. Two honestly-labelled sections:
/// "Phone screening" (wellness-grade, phone sensors) and "Device measurement"
/// (clinical-grade, only via the connected Heartelfie device).
///
/// Every modality is a rich row with its summary, tier, supported metrics, and an
/// explainer link. The header sets expectations up front about what the two tiers
/// do and don't mean.
struct MeasureHomeView: View {
    @Environment(AppEnvironment.self) private var env

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                tierExplainer

                section(
                    title: "Phone screening",
                    subtitle: "Wellness-grade checks using your phone's own sensors. These are screenings — not medical measurements.",
                    systemImage: "iphone",
                    modalities: Modality.phoneModalities
                )

                section(
                    title: "Device measurement",
                    subtitle: "Higher-confidence readings from the Heartelfie device. Still for wellness, not diagnosis.",
                    systemImage: "sensor.tag.radiowaves.forward.fill",
                    modalities: Modality.deviceModalities
                )

                EmergencyNotice()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Measure")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Tier explainer

    private var tierExplainer: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                Text("Two ways to check, honestly labelled")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)

                explainerRow(
                    tier: .screening,
                    text: "Phone screenings give you quick, day-to-day wellness snapshots. They're lower-confidence and never a diagnosis."
                )
                explainerRow(
                    tier: .measurement,
                    text: "Device measurements use the Heartelfie hardware for higher-confidence readings. Still wellness, not a medical verdict."
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func explainerRow(tier: MeasurementTier, text: String) -> some View {
        HStack(alignment: .top, spacing: HESpacing.sm) {
            TierBadge(tier, compact: true)
                .accessibilityHidden(true)
            Text(text)
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tier.displayName). \(text)")
    }

    // MARK: - Section

    private func section(
        title: String,
        subtitle: String,
        systemImage: String,
        modalities: [Modality]
    ) -> some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: title, subtitle: subtitle, systemImage: systemImage)

            ForEach(modalities) { modality in
                ModalityRow(modality: modality, isAvailable: env.isAvailable(modality))
            }
        }
    }
}

#Preview("Measure") {
    NavigationStack {
        MeasureHomeView()
            .environment(AppEnvironment.preview())
    }
}
