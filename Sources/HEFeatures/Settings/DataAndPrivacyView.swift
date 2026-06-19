import SwiftUI
import HECore
import HEDesign

/// Plain-language transparency about how Heartelfie stores and protects data, what
/// it syncs with Apple Health, and how to delete everything. Calm, honest, and
/// explicitly non-diagnostic.
struct DataAndPrivacyView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var didDelete = false

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                consentSection
                storageSection
                cloudSection
                healthKitSection
                deleteSection
                NonDiagnosticFooter()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Data & privacy")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete all data?", isPresented: $showDeleteConfirm) {
            Button("Delete everything", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every reading and your profile from this device. This can't be undone.")
        }
    }

    // MARK: - Consent

    private var consentSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Your data, your control",
                systemImage: "hand.raised.fill"
            )

            HECard {
                Text(Disclaimers.consentSummary)
                    .font(.heBody)
                    .foregroundStyle(Color.heTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - On-device storage

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "On-device storage",
                systemImage: "lock.shield.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    privacyPoint(
                        icon: "lock.fill",
                        title: "Encrypted at rest",
                        detail: "Your readings are stored on this device in an AES-GCM encrypted database."
                    )
                    privacyPoint(
                        icon: "key.fill",
                        title: "Keys in the Keychain",
                        detail: "The encryption key lives in the iOS Keychain and never leaves your device."
                    )
                    privacyPoint(
                        icon: "person.crop.circle.badge.minus",
                        title: "Minimal personal data",
                        detail: "Heartelfie keeps no name or contact details — only the optional health profile you choose to add."
                    )
                }
            }
        }
    }

    // MARK: - Cloud

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "When data reaches the cloud",
                systemImage: "cloud.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    privacyPoint(
                        icon: "lock.icloud.fill",
                        title: "Encrypted in transit",
                        detail: "Cloud model requests use TLS with certificate pinning, so the connection can't be quietly intercepted."
                    )
                    privacyPoint(
                        icon: "iphone.gen3",
                        title: "Sensitive signals stay local",
                        detail: "Custom waveforms and hemoglobin estimates are processed on your device and are not uploaded."
                    )
                }
            }
        }
    }

    // MARK: - HealthKit

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Apple Health",
                systemImage: "heart.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    privacyPoint(
                        icon: "arrow.down.heart.fill",
                        title: "What Heartelfie reads",
                        detail: "With your permission: heart rate, heart rate variability, resting heart rate, blood oxygen, and respiratory rate — plus Apple Watch ECG when available."
                    )
                    privacyPoint(
                        icon: "arrow.up.heart.fill",
                        title: "What Heartelfie writes",
                        detail: "Only the supported subset of your readings is written back to Apple Health. Custom waveforms and hemoglobin estimates stay on your device."
                    )
                    Text("You can change these permissions any time in the Health app.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }
            }
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Delete all data",
                systemImage: "trash.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    if didDelete {
                        Label("All data deleted from this device.", systemImage: "checkmark.circle.fill")
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                    } else {
                        Text("Permanently remove every reading and your profile from this device.")
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete all data", systemImage: "trash")
                                .font(.heHeadline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.heRisk(.elevated))
                        .disabled(isDeleting)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func privacyPoint(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: HESpacing.md) {
            Image(systemName: icon)
                .font(.heHeadline)
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

    private func deleteAll() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            await env.deleteAllData()
            isDeleting = false
            didDelete = true
        }
    }
}

#Preview("Data & privacy") {
    NavigationStack {
        DataAndPrivacyView()
            .environment(AppEnvironment.preview())
    }
}
