import SwiftUI
import HECore
import HEDesign

/// An accessible editor for the `HealthProfile`. Works on a local draft so edits
/// can be reviewed and saved atomically through `env.updateProfile(_:)`.
///
/// Collects: name / participant ID, age, gender, height, weight (BMI is computed
/// live), race, Monk Skin Tone (the full 10-box scale), and prior-condition
/// checkboxes. Height/weight are entered in the chosen unit system and stored
/// canonically in centimetres / kilograms. Nothing here is diagnostic — the
/// profile only adds gentle context to screenings.
struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ProfileDraft()
    @State private var isSaving = false
    @State private var hasLoaded = false

    init() {}

    var body: some View {
        Form {
            identitySection
            bodySection
            raceSection
            skinToneSection
            priorConditionsSection
            unitsSection
            disclosureSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.heBackground)
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(isSaving)
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            draft = ProfileDraft(profile: env.profile)
            hasLoaded = true
        }
    }

    // MARK: - Identity (name, age, gender)

    private var identitySection: some View {
        Section {
            HStack {
                Text("Name")
                Spacer()
                TextField("Participant ID", text: $draft.name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.heTextPrimary)
                    .submitLabel(.done)
                    .accessibilityLabel("Name or participant ID")
            }

            Stepper(value: $draft.age, in: 1...120) {
                HStack {
                    Text("Age")
                    Spacer()
                    Text("\(draft.age)")
                        .foregroundStyle(Color.heTextSecondary)
                        .monospacedDigit()
                }
            }
            .accessibilityLabel("Age")
            .accessibilityValue("\(draft.age) years")

            Picker("Gender", selection: $draft.biologicalSex) {
                Text("Not set").tag(Optional<BiologicalSex>.none)
                ForEach(BiologicalSex.allCases) { sex in
                    Text(sex.displayName).tag(Optional(sex))
                }
            }
        } header: {
            Text("About you")
        } footer: {
            Text("Your name defaults to a non-identifying ID. Everything here stays on your device.")
        }
    }

    // MARK: - Body (height, weight, BMI)

    private var bodySection: some View {
        Section {
            if draft.unitSystem == .metric {
                measurementStepper(title: "Height", value: $draft.heightCM, range: 80...230, unit: "cm")
                measurementStepper(title: "Weight", value: $draft.weightKG, range: 25...250, unit: "kg")
            } else {
                measurementStepper(title: "Height", value: $draft.heightIN, range: 30...90, unit: "in")
                measurementStepper(title: "Weight", value: $draft.weightLB, range: 55...550, unit: "lb")
            }

            bmiRow
        } header: {
            Text("Body measurements")
        } footer: {
            Text("BMI is calculated from your height and weight. It's a general guide, not a diagnosis.")
        }
    }

    @ViewBuilder
    private var bmiRow: some View {
        if let bmi = draft.bmi {
            let category = ClinicalConfig.bmiCategory(bmi)
            HStack(spacing: HESpacing.sm) {
                Text("BMI")
                Spacer()
                Text(bmi.formatted(.number.precision(.fractionLength(1))))
                    .font(.heBody.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.heTextPrimary)
                Text(category.label)
                    .font(.heCaption.weight(.medium))
                    .foregroundStyle(Color.heRisk(category.risk))
                    .padding(.horizontal, HESpacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.heRisk(category.risk).opacity(0.15))
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("B M I \(bmi.formatted(.number.precision(.fractionLength(1)))), \(category.label)")
        }
    }

    private func measurementStepper(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String
    ) -> some View {
        Stepper(value: value, in: range, step: 1) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded())) \(unit)")
                    .foregroundStyle(Color.heTextSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value.wrappedValue.rounded())) \(unit)")
    }

    // MARK: - Race

    private var raceSection: some View {
        Section {
            Picker("Race", selection: $draft.race) {
                Text("Not set").tag(Optional<Race>.none)
                ForEach(Race.allCases) { race in
                    Text(race.displayName).tag(Optional(race))
                }
            }
        } header: {
            Text("Race")
        } footer: {
            Text("Optional and self-identified. Helps support equitable performance across people; never used to make a claim.")
        }
    }

    // MARK: - Skin tone (10-box scale)

    private var skinToneSection: some View {
        Section {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                MonkSkinToneScale(selection: $draft.monkSkinTone)

                if draft.monkSkinTone != nil {
                    Button("Clear selection") { draft.monkSkinTone = nil }
                        .font(.heCallout)
                        .foregroundStyle(Color.hePrimary)
                }
            }
            .padding(.vertical, HESpacing.xs)
        } header: {
            Text("Monk Skin Tone")
        } footer: {
            Text(MonkSkinTone.usageDisclosure)
        }
    }

    // MARK: - Prior conditions (checkboxes)

    private var priorConditionsSection: some View {
        Section {
            ForEach(PriorCondition.allCases) { condition in
                Toggle(isOn: conditionBinding(condition)) {
                    Label(condition.displayName, systemImage: condition.systemImage)
                }
            }
        } header: {
            Text("Prior conditions")
        } footer: {
            Text("Optional. Helps DailyDil phrase insights more carefully. Stored only on your device.")
        }
    }

    private func conditionBinding(_ condition: PriorCondition) -> Binding<Bool> {
        Binding(
            get: { draft.priorConditions.contains(condition) },
            set: { isOn in
                if isOn { draft.priorConditions.insert(condition) }
                else { draft.priorConditions.remove(condition) }
            }
        )
    }

    // MARK: - Units

    private var unitsSection: some View {
        Section {
            Picker("Units", selection: $draft.unitSystem) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.displayName).tag(system)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Units")
        } footer: {
            Text("Switching units re-labels height and weight; your entries are kept.")
        }
    }

    // MARK: - Disclosure

    private var disclosureSection: some View {
        Section {
            Label("These details never leave your device unless you export them.", systemImage: "lock.fill")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
        }
    }

    // MARK: - Save

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let profile = draft.toProfile()
        Task {
            await env.updateProfile(profile)
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Draft model

/// A mutable, unit-aware editing buffer for `HealthProfile`. Keeps both metric and
/// imperial entries in sync so toggling units never loses the user's input.
private struct ProfileDraft {
    var name: String = "PID001"
    var unitSystem: UnitSystem = .metric
    var age: Int = 35
    var biologicalSex: BiologicalSex?
    var heightCM: Double = 170
    var weightKG: Double = 70
    var race: Race?
    var priorConditions: Set<PriorCondition> = []
    var monkSkinTone: MonkSkinTone?
    /// Carried through unchanged (legacy / "other" free-form conditions).
    var knownConditions: [String] = []

    // Imperial mirrors, derived from / written back to the canonical metric values.
    var heightIN: Double {
        get { heightCM / 2.54 }
        set { heightCM = newValue * 2.54 }
    }
    var weightLB: Double {
        get { weightKG * 2.2046226218 }
        set { weightKG = newValue / 2.2046226218 }
    }

    /// Live BMI from the canonical metric height/weight.
    var bmi: Double? {
        guard heightCM > 0 else { return nil }
        let meters = heightCM / 100.0
        return weightKG / (meters * meters)
    }

    init() {}

    init(profile: HealthProfile) {
        name = profile.name
        unitSystem = profile.unitSystem
        age = profile.age ?? 35
        biologicalSex = profile.biologicalSex
        heightCM = profile.heightCM ?? 170
        weightKG = profile.weightKG ?? 70
        race = profile.race
        priorConditions = profile.priorConditions
        monkSkinTone = profile.monkSkinTone
        knownConditions = profile.knownConditions
    }

    func toProfile() -> HealthProfile {
        HealthProfile(
            name: name,
            age: age,
            biologicalSex: biologicalSex,
            heightCM: heightCM,
            weightKG: weightKG,
            race: race,
            knownConditions: knownConditions,
            priorConditions: priorConditions,
            monkSkinTone: monkSkinTone,
            unitSystem: unitSystem
        )
    }
}

#Preview("Edit profile") {
    NavigationStack {
        EditProfileView()
            .environment(AppEnvironment.preview())
    }
}
