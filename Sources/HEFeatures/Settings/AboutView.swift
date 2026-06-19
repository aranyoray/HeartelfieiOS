import SwiftUI
import HECore
import HEDesign

/// What Heartelfie is and isn't: a wellness and screening companion with two
/// confidence tiers, honest about phone-vs-device signals, anchored by the
/// persistent emergency notice and a clear non-diagnostic statement.
struct AboutView: View {
    @Environment(AppEnvironment.self) private var env

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                headerCard
                EmergencyNotice()
                whatItIsSection
                tiersSection
                modelAttributionSection
                regulatorySection
                creditsSection
                NonDiagnosticFooter()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.xs) {
                Text(HeartelfieConfig.appName)
                    .font(.heTitle)
                    .foregroundStyle(Color.heTextPrimary)
                Text("Version 1.0")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                Text("A calm companion for keeping an eye on your cardiovascular wellness.")
                    .font(.heBody)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, HESpacing.xxs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - What it is

    private var whatItIsSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "What Heartelfie is", systemImage: "heart.text.square.fill")

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Text("Heartelfie offers wellness and screening insights — gentle, everyday check-ins, not medical measurements.")
                        .font(.heBody)
                        .foregroundStyle(Color.heTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Disclaimers.notDiagnostic)
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Tiers

    private var tiersSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Two confidence tiers",
                subtitle: "We're honest about how much to trust each signal.",
                systemImage: "chart.bar.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    tier(
                        icon: "iphone",
                        title: "Screening — phone only",
                        detail: "Camera and microphone checks give you a quick, low-friction screening. Convenient, but lower confidence."
                    )
                    Divider().overlay(Color.heSeparator)
                    tier(
                        icon: "sensor.tag.radiowaves.forward.fill",
                        title: "Measurement — with the device",
                        detail: "The Heartelfie device adds higher-confidence signals like ECG, clinical SpO₂, hemoglobin, and bioimpedance. Still wellness and screening — never a diagnosis."
                    )
                }
            }
        }
    }

    private func tier(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: HESpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.hePrimary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                Text(title)
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text(detail)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Model attribution

    private var modelAttributionSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "Model transparency", systemImage: "cpu")

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Text("Some insights are produced by machine-learning models. When a cloud model contributes to a reading, its name, version, and attribution are shown with that reading.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Open any reading to see exactly which model produced it.", systemImage: "doc.text.magnifyingglass")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Regulatory posture

    private var regulatorySection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "Regulatory posture", systemImage: "checkmark.seal")

            HECard {
                Text("Heartelfie is built as a wellness and screening product. Clinical features are designed to be gated behind future regulatory clearance, and are not offered as diagnostic tools today.")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Credits

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "Credits & legal", systemImage: "doc.plaintext")

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    creditRow(title: "Privacy Policy", detail: "Coming soon")
                    Divider().overlay(Color.heSeparator)
                    creditRow(title: "Terms of Use", detail: "Coming soon")
                    Divider().overlay(Color.heSeparator)
                    creditRow(title: "Acknowledgements", detail: "Coming soon")
                    Divider().overlay(Color.heSeparator)
                    creditRow(title: "© \(currentYear) \(HeartelfieConfig.appName)", detail: "")
                }
            }
        }
    }

    private func creditRow(title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(.heCallout)
                .foregroundStyle(Color.heTextPrimary)
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var currentYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }
}

#Preview("About") {
    NavigationStack {
        AboutView()
            .environment(AppEnvironment.preview())
    }
}
