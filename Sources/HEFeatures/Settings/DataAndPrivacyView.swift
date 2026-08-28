import SwiftUI
import HECore
import HEDesign

/// Plain-language transparency about storage, face data, Apple Health syncing,
/// and deletion.
struct DataAndPrivacyView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var didDelete = false
    @State private var deleteFailed = false

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                consentSection
                storageSection
                faceDataSection
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
            Text("This permanently removes every reading, profile value, and exported report file stored on this device, and asks Apple Health to delete the samples DailyDil wrote. This cannot be undone.")
        }
    }

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
                        detail: "Your readings are stored on this device in an encrypted local database."
                    )
                    privacyPoint(
                        icon: "key.fill",
                        title: "Keys in Keychain",
                        detail: "The encryption key lives in the iOS Keychain and never leaves your device."
                    )
                    privacyPoint(
                        icon: "person.crop.circle.badge.minus",
                        title: "Minimal personal data",
                        detail: "DailyDil keeps no account, email address, contact list, photos, or advertising profile."
                    )
                }
            }
        }
    }

    private var faceDataSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Face data",
                subtitle: "Used only for contactless pulse screening.",
                systemImage: "face.smiling"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    privacyPoint(
                        icon: "camera.viewfinder",
                        title: "What is collected",
                        detail: "During a facial rPPG check, the front camera video stream is processed on device to find a face region and read color-change signals used to estimate pulse. DailyDil does not create Face ID templates or identify you."
                    )
                    privacyPoint(
                        icon: "iphone",
                        title: "Processing and storage",
                        detail: "Raw face images and video frames are processed in memory on device and are not saved after the check. The saved reading contains derived wellness metrics, signal-quality values, timestamps, and a small waveform preview."
                    )
                    privacyPoint(
                        icon: "person.2.slash",
                        title: "No sharing",
                        detail: "Face data is not sold, used for advertising, or shared with third parties. It is not uploaded to DailyDil servers."
                    )
                    privacyPoint(
                        icon: "trash",
                        title: "Retention and deletion",
                        detail: "Raw face frames are discarded immediately after processing. Derived readings remain on this device until you delete them, export them, or remove the app."
                    )
                }
            }
        }
    }

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Network use",
                systemImage: "cloud.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    privacyPoint(
                        icon: "iphone.gen3",
                        title: "Sensitive signals stay local",
                        detail: "Camera frames, face regions, and custom waveforms are processed on device and are not uploaded by default."
                    )
                    privacyPoint(
                        icon: "lock.icloud.fill",
                        title: "Encrypted in transit",
                        detail: "If you choose to use a network-backed model in a future release, requests will use encrypted transport and will be disclosed before use."
                    )
                }
            }
        }
    }

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Apple Health / HealthKit",
                subtitle: "Optional integration controlled by the Health app.",
                systemImage: "heart.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    privacyPoint(
                        icon: "arrow.down.heart.fill",
                        title: "What DailyDil reads",
                        detail: "With your permission, DailyDil reads supported Apple Health values such as heart rate, heart-rate variability, resting heart rate, breathing rate, and available Apple Watch rhythm data."
                    )
                    privacyPoint(
                        icon: "arrow.up.heart.fill",
                        title: "What DailyDil writes",
                        detail: "With your permission, DailyDil saves your camera-based wellness estimates — heart rate, heart-rate variability, and breathing rate — to Apple Health, labelled as coming from DailyDil. Face frames and custom waveforms are not written."
                    )
                    Text("You can change Apple Health permissions any time in the Health app.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }
            }
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Delete all data",
                systemImage: "trash.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    if didDelete {
                        Label("All local DailyDil data has been deleted from this device.", systemImage: "checkmark.circle.fill")
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                        if env.healthCleanupIncomplete {
                            Text("Some samples DailyDil wrote to Apple Health may remain — you can remove them in the Health app under Browse → Data Sources.")
                                .font(.heCaption)
                                .foregroundStyle(Color.heTextSecondary)
                        }
                    } else {
                        if deleteFailed {
                            Label("Deletion didn't finish — your data may still be on this device. Please try again.", systemImage: "exclamationmark.triangle.fill")
                                .font(.heCallout)
                                .foregroundStyle(Color.heRisk(.watch))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("Permanently remove every reading and profile value stored on this device, along with exported report files. DailyDil also asks Apple Health to delete the samples it wrote.")
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
        deleteFailed = false
        Task {
            do {
                try await env.deleteAllData()
                didDelete = true
            } catch {
                // The store wipe failed — be honest that data may still exist
                // rather than showing the success banner.
                deleteFailed = true
            }
            isDeleting = false
        }
    }
}

#Preview("Data & privacy") {
    NavigationStack {
        DataAndPrivacyView()
            .environment(AppEnvironment.preview())
    }
}
