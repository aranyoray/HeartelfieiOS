import SwiftUI
import HECore
import HEDesign

/// The "What this does / doesn't mean" explainer for a single modality.
///
/// Lays out, in plain language: the modality and its signal source, its trust
/// tier, what it screens for, an honest "what it means" / "what it does not mean"
/// pair, and the persistent non-diagnostic + emergency notices.
struct ModalityInfoView: View {
    let modality: Modality

    init(modality: Modality) {
        self.modality = modality
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.lg) {
                headerCard
                    .heEntrance(0)
                measuresCard
                    .heEntrance(1)
                meaningCard(
                    title: "What this means",
                    systemImage: "checkmark.seal.fill",
                    tint: Color.heRisk(.normal),
                    text: Disclaimers.whatItMeans(for: modality)
                )
                .heEntrance(2)
                meaningCard(
                    title: "What this does not mean",
                    systemImage: "exclamationmark.shield.fill",
                    tint: Color.heRisk(.watch),
                    text: Disclaimers.whatItDoesNotMean(for: modality)
                )
                .heEntrance(3)
                NonDiagnosticFooter()
                    .heEntrance(4)
                EmergencyNotice()
                    .heEntrance(5)
            }
            .padding(HESpacing.md)
        }
        .heAmbientBackground()
        .navigationTitle(modality.shortName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                HStack(alignment: .top, spacing: HESpacing.md) {
                    Image(systemName: modality.systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(Color.hePrimary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: HESpacing.xs) {
                        Text(modality.displayName)
                            .font(.heTitle)
                            .foregroundStyle(Color.heTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: HESpacing.xs) {
                            TierBadge(modality.tier, compact: false)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Label {
                    Text("Source: \(modality.source.displayName)")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                } icon: {
                    Image(systemName: modality.source.systemImage)
                        .foregroundStyle(Color.heTextSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Signal source: \(modality.source.displayName)")

                Text(modality.summary)
                    .font(.heBody)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Measures

    @ViewBuilder
    private var measuresCard: some View {
        if !modality.supportedMetrics.isEmpty {
            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Text("What it screens for")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)

                    MetricChipsFlow(metrics: modality.supportedMetrics)

                    Text("Showing each metric this check can surface.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Meaning card

    private func meaningCard(title: String, systemImage: String, tint: Color, text: String) -> some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                Label(title, systemImage: systemImage)
                    .font(.heHeadline)
                    .foregroundStyle(tint)

                Text(text)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(text)")
    }
}

#Preview("Modality info") {
    NavigationStack {
        ModalityInfoView(modality: .facialRPPG)
            .environment(AppEnvironment.preview())
    }
}
