import SwiftUI
import HECore
import HEDesign

/// The "What this does / doesn't mean" explainer for a single modality.
///
/// Lays out, in plain language: the modality and its signal source, its trust
/// tier, what it measures, an honest "what it means" / "what it does not mean"
/// pair, a device-requirement note for hardware modalities, and the persistent
/// non-diagnostic + emergency notices.
struct ModalityInfoView: View {
    let modality: Modality

    init(modality: Modality) {
        self.modality = modality
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.lg) {
                headerCard
                if modality.requiresDevice {
                    deviceRequirementCard
                }
                measuresCard
                meaningCard(
                    title: "What this means",
                    systemImage: "checkmark.seal.fill",
                    tint: Color.heRisk(.normal),
                    text: Disclaimers.whatItMeans(for: modality)
                )
                meaningCard(
                    title: "What this does not mean",
                    systemImage: "exclamationmark.shield.fill",
                    tint: Color.heRisk(.watch),
                    text: Disclaimers.whatItDoesNotMean(for: modality)
                )
                NonDiagnosticFooter()
                EmergencyNotice()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
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
                            if modality.isExperimental {
                                ExperimentalChip()
                            }
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

    // MARK: - Device requirement

    private var deviceRequirementCard: some View {
        HStack(alignment: .top, spacing: HESpacing.sm) {
            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .foregroundStyle(Color.heTier(.measurement))
                .accessibilityHidden(true)
            Text("This is a device measurement. It requires the Heartelfie device, connected with good contact.")
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HESpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.heSurface, in: RoundedRectangle(cornerRadius: HERadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.md, style: .continuous)
                .strokeBorder(Color.heTier(.measurement).opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Requires the Heartelfie device, connected with good contact.")
    }

    // MARK: - Measures

    @ViewBuilder
    private var measuresCard: some View {
        if !modality.supportedMetrics.isEmpty {
            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Text("What it measures")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)

                    MetricChipsFlow(metrics: modality.supportedMetrics)

                    Text("Showing each metric this check can surface. Device-only metrics never appear under a phone check.")
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

#Preview("Modality info — phone") {
    NavigationStack {
        ModalityInfoView(modality: .fingerPPG)
            .environment(AppEnvironment.preview())
    }
}

#Preview("Modality info — device") {
    NavigationStack {
        ModalityInfoView(modality: .deviceECG)
            .environment(AppEnvironment.preview())
    }
}
