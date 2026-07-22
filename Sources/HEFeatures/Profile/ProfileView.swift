import SwiftUI
import HECore
import HEDesign

/// The Profile tab root: a calm, accessible `Form` that summarises the person's
/// health profile, surfaces the Heartelfie device status, and links out to the
/// data, privacy, export, about, and developer screens.
///
/// All copy is wellness-grade and explicitly non-diagnostic. Nothing here is a
/// measurement; the profile only adds gentle context to screenings.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env

    init() {}

    var body: some View {
        Form {
            headerSection
            detailsSection
            editSection
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
                    Text(env.profile.name)
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
            .accessibilityLabel("Profile for \(env.profile.name). \(profileSummary)")
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.hePrimary.opacity(0.15))
                .frame(width: 56, height: 56)

            if let tone = env.profile.monkSkinTone {
                Circle()
                    .fill(Color(hex: tone.swatchHex))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.heSeparator, lineWidth: 1))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color.hePrimary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var profileSummary: String {
        var parts: [String] = []
        if let age = env.profile.age { parts.append("Age \(age)") }
        if let sex = env.profile.biologicalSex { parts.append(sex.displayName) }
        if let bmi = env.profile.bmi {
            parts.append("BMI \(bmi.formatted(.number.precision(.fractionLength(1))))")
        }
        if parts.isEmpty {
            return "Add optional details to give your checks more context."
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Health profile details

    private var detailsSection: some View {
        Section {
            detailRow("Age", env.profile.age.map(String.init))
            detailRow("Gender", env.profile.biologicalSex?.displayName)
            detailRow("Height", heightText)
            detailRow("Weight", weightText)
            bmiRow
            detailRow("Race", env.profile.race?.displayName)
            skinToneRow
            priorConditionsRow
        } header: {
            Text("Health profile")
        } footer: {
            Text("All details are optional and stay on your device. BMI is a general guide, not a diagnosis.")
        }
    }

    private func detailRow(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? "Not set")
                .foregroundStyle(value == nil ? Color.heTextTertiary : Color.heTextSecondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value ?? "Not set")")
    }

    @ViewBuilder
    private var bmiRow: some View {
        if let bmi = env.profile.bmi {
            let category = ClinicalConfig.bmiCategory(bmi)
            HStack(spacing: HESpacing.sm) {
                Text("BMI")
                Spacer()
                Text(bmi.formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
                    .foregroundStyle(Color.heTextPrimary)
                Text(category.label)
                    .font(.heCaption.weight(.medium))
                    .foregroundStyle(Color.heRisk(category.risk))
                    .padding(.horizontal, HESpacing.sm)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.heRisk(category.risk).opacity(0.15)))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("B M I \(bmi.formatted(.number.precision(.fractionLength(1)))), \(category.label)")
        }
    }

    private var skinToneRow: some View {
        HStack(spacing: HESpacing.sm) {
            Text("Monk Skin Tone")
            Spacer()
            if let tone = env.profile.monkSkinTone {
                Circle()
                    .fill(Color(hex: tone.swatchHex))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(Color.heSeparator, lineWidth: 1))
                    .accessibilityHidden(true)
                Text("\(tone.value)")
                    .monospacedDigit()
                    .foregroundStyle(Color.heTextSecondary)
            } else {
                Text("Not set").foregroundStyle(Color.heTextTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(env.profile.monkSkinTone.map { "Monk skin tone \($0.value)" } ?? "Monk skin tone not set")
    }

    private var priorConditionsRow: some View {
        HStack(alignment: .top) {
            Text("Prior conditions")
            Spacer()
            if env.profile.priorConditions.isEmpty {
                Text("None").foregroundStyle(Color.heTextTertiary)
            } else {
                Text(sortedConditions)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.heTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Prior conditions: \(env.profile.priorConditions.isEmpty ? "none" : sortedConditions)")
    }

    private var sortedConditions: String {
        env.profile.priorConditions
            .sorted { $0.displayName < $1.displayName }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    private var heightText: String? {
        guard let cm = env.profile.heightCM else { return nil }
        if env.profile.unitSystem == .imperial {
            return "\(Int((cm / 2.54).rounded())) in"
        }
        return "\(Int(cm.rounded())) cm"
    }

    private var weightText: String? {
        guard let kg = env.profile.weightKG else { return nil }
        if env.profile.unitSystem == .imperial {
            return "\(Int((kg * 2.2046226218).rounded())) lb"
        }
        return "\(Int(kg.rounded())) kg"
    }

    // MARK: - Edit + units

    private var editSection: some View {
        Section {
            NavigationLink {
                EditProfileView()
            } label: {
                Label("Edit profile", systemImage: "person.text.rectangle")
            }
            Picker(selection: unitBinding) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.displayName).tag(system)
                }
            } label: {
                Label("Units", systemImage: "ruler")
            }
        } footer: {
            Text("Edit your details any time. Units change how height and weight are shown.")
        }
    }

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
            Text("Apple Health / HealthKit")
        } footer: {
            Text("HealthKit integration is optional. Heartelfie can read supported Apple Health values and write supported reading summaries only after you approve access.")
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
                    Text("Apple Health / HealthKit")
                    .font(.heBody)
                    .foregroundStyle(Color.heTextPrimary)
                Spacer(minLength: 0)
            }

            if didRequest {
                Label("HealthKit permission requested. You can change it in the Health app.", systemImage: "checkmark.circle.fill")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
            } else {
                HESecondaryButton(
                    "Continue",
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
