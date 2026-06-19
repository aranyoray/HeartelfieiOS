import SwiftUI
import HECore
import HEDesign

/// The Profile tab root: a calm, accessible `Form` that summarises the person's
/// optional health profile, surfaces the Heartelfie device status, and links out
/// to the data, privacy, export, about, and developer screens.
///
/// All copy is wellness-grade and explicitly non-diagnostic. Nothing here is a
/// measurement; the profile only adds gentle context to screenings.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env

    init() {}

    var body: some View {
        Form {
            headerSection
            profileSection
            unitsSection
            deviceSection
            healthSection
            dataSection
            aboutSection
            versionSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.heBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack(spacing: HESpacing.md) {
                avatar

                VStack(alignment: .leading, spacing: HESpacing.xxs) {
                    Text(HeartelfieConfig.appName)
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Text(profileSummary)
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, HESpacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your profile. \(profileSummary)")
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.hePrimary.opacity(0.15))
                .frame(width: 56, height: 56)

            if let tone = env.profile.monkSkinTone {
                MonkSkinToneSwatch(tone: tone, isSelected: false)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color.hePrimary)
                    .accessibilityHidden(true)
            }
        }
    }

    /// A name-less, privacy-minimal summary line. Heartelfie never stores a name.
    private var profileSummary: String {
        var parts: [String] = []
        if let age = env.profile.age {
            parts.append("Age \(age)")
        }
        if let sex = env.profile.biologicalSex {
            parts.append(sex.displayName)
        }
        if parts.isEmpty {
            return "Add optional details to give your checks more context."
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            NavigationLink {
                EditProfileView()
            } label: {
                Label("Edit profile", systemImage: "person.text.rectangle")
            }
        } header: {
            Text("Profile")
        } footer: {
            Text("All profile details are optional and stay on your device.")
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        Section {
            Picker(selection: unitBinding) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.displayName).tag(system)
                }
            } label: {
                Label("Units", systemImage: "ruler")
            }
        } header: {
            Text("Units")
        } footer: {
            Text("Used to display height and weight.")
        }
    }

    /// Edits a single field on a value-type profile, then persists the whole
    /// profile through the environment.
    private var unitBinding: Binding<UnitSystem> {
        Binding(
            get: { env.profile.unitSystem },
            set: { newValue in
                var updated = env.profile
                updated.unitSystem = newValue
                Task { await env.updateProfile(updated) }
            }
        )
    }

    // MARK: - Device

    private var deviceSection: some View {
        Section {
            NavigationLink(value: AppRoute.devicePairing) {
                DeviceStatusChip(state: env.deviceState)
            }
            .buttonStyle(.plain)
            .accessibilityHint(env.deviceState.isConnected
                ? "Opens device management."
                : "Opens device pairing to connect your Heartelfie device.")
        } header: {
            Text("Connected device")
        }
    }

    // MARK: - Apple Health

    private var healthSection: some View {
        Section {
            AppleHealthRow()
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Optionally sync supported readings with Apple Health. Custom waveforms and hemoglobin estimates stay on your device.")
        }
    }

    // MARK: - Data & privacy

    private var dataSection: some View {
        Section {
            NavigationLink(value: AppRoute.dataAndPrivacy) {
                Label("Data & privacy", systemImage: "lock.shield")
            }
            NavigationLink(value: AppRoute.exportData) {
                Label("Export data", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Your data")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            NavigationLink(value: AppRoute.about) {
                Label("About \(HeartelfieConfig.appName)", systemImage: "info.circle")
            }
            NavigationLink(value: AppRoute.developer) {
                Label("Developer", systemImage: "hammer")
            }
        }
    }

    // MARK: - Version footer

    private var versionSection: some View {
        Section {
            EmptyView()
        } footer: {
            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                Text("\(HeartelfieConfig.appName) 1.0")
                    .font(.heCaption.weight(.medium))
                    .foregroundStyle(Color.heTextSecondary)
                Text("Wellness and screening only — not a medical device. Model name and version are shown with each reading.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, HESpacing.xs)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Apple Health row

/// A self-contained row that requests Apple Health authorization, managing its own
/// in-flight and completed UI so the parent `Form` stays declarative.
private struct AppleHealthRow: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isConnecting = false
    @State private var didRequest = false

    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            HStack(spacing: HESpacing.sm) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.hePrimary)
                    .accessibilityHidden(true)
                Text("Connect Apple Health")
                    .font(.heBody)
                    .foregroundStyle(Color.heTextPrimary)
                Spacer(minLength: 0)
            }

            if didRequest {
                Label("Health permission requested in Settings.", systemImage: "checkmark.circle.fill")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
            } else {
                HESecondaryButton(
                    "Connect Apple Health",
                    systemImage: "heart.fill",
                    isLoading: isConnecting
                ) {
                    connect()
                }
            }
        }
        .padding(.vertical, HESpacing.xxs)
    }

    private func connect() {
        guard !isConnecting else { return }
        isConnecting = true
        Task {
            await env.enableHealthKit()
            isConnecting = false
            didRequest = true
        }
    }
}

#Preview("Profile") {
    NavigationStack {
        ProfileView()
            .environment(AppEnvironment.preview())
    }
}
