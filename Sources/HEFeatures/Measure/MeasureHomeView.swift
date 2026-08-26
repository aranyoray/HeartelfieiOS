import SwiftUI
import HECore
import HEDesign

/// The Measure tab's modality picker. Phone-only wellness screenings using the
/// phone's own sensors — not medical measurements, and not a hardware device path.
struct MeasureHomeView: View {
    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                screeningExplainer

                section(
                    title: "Phone screening",
                    subtitle: "Wellness-grade checks using your phone's own sensors. These are screenings — not medical measurements.",
                    systemImage: "iphone",
                    modalities: Array(Modality.allCases)
                )

                EmergencyNotice()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Measure")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Explainer

    private var screeningExplainer: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                Text("A gentle check with your phone")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)

                HStack(alignment: .top, spacing: HESpacing.sm) {
                    TierBadge(.screening, compact: true)
                        .accessibilityHidden(true)
                    Text("Phone screenings give you quick, day-to-day wellness snapshots. They're lower-confidence and never a diagnosis.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Screening. Phone screenings give you quick, day-to-day wellness snapshots. They're lower-confidence and never a diagnosis.")
            }
        }
        .accessibilityElement(children: .contain)
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
                ModalityRow(modality: modality)
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
