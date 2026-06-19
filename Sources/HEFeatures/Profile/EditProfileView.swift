import SwiftUI
import HECore
import HEDesign

/// An accessible editor for the optional `HealthProfile`. Works on a local draft so
/// edits can be reviewed and saved atomically through `env.updateProfile(_:)`.
///
/// Height and weight are entered in the chosen unit system and converted to the
/// canonical centimetre / kilogram storage on save. Nothing here is required, and
/// nothing here is diagnostic — the profile only adds gentle context to screenings.
struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ProfileDraft()
    @State private var newCondition: String = ""
    @State private var isSaving = false
    @State private var hasLoaded = false

    @FocusState private var conditionFieldFocused: Bool

    init() {}

    var body: some View {
        Form {
            unitsSection
            basicsSection
            bodySection
            conditionsSection
            skinToneSection
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

    // MARK: - Basics

    private var basicsSection: some View {
        Section {
            Toggle("Include age", isOn: $draft.includeAge)
            if draft.includeAge {
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
            }

            Picker("Biological sex", selection: $draft.biologicalSex) {
                Text("Not set").tag(Optional<BiologicalSex>.none)
                ForEach(BiologicalSex.allCases) { sex in
                    Text(sex.displayName).tag(Optional(sex))
                }
            }
        } header: {
            Text("Basics")
        } footer: {
            Text("Used only to put screenings in context. Biological sex helps interpret some metrics.")
        }
    }

    // MARK: - Body measurements

    private var bodySection: some View {
        Section {
            Toggle("Include height", isOn: $draft.includeHeight)
            if draft.includeHeight {
                if draft.unitSystem == .metric {
                    measurementStepper(
                        title: "Height",
                        value: $draft.heightCM,
                        range: 80...230,
                        step: 1,
                        unit: "cm"
                    )
                } else {
                    measurementStepper(
                        title: "Height",
                        value: $draft.heightIN,
                        range: 30...90,
                        step: 1,
                        unit: "in"
                    )
                }
            }

            Toggle("Include weight", isOn: $draft.includeWeight)
            if draft.includeWeight {
                if draft.unitSystem == .metric {
                    measurementStepper(
                        title: "Weight",
                        value: $draft.weightKG,
                        range: 25...250,
                        step: 1,
                        unit: "kg"
                    )
                } else {
                    measurementStepper(
                        title: "Weight",
                        value: $draft.weightLB,
                        range: 55...550,
                        step: 1,
                        unit: "lb"
                    )
                }
            }
        } header: {
            Text("Body measurements")
        }
    }

    private func measurementStepper(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
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

    // MARK: - Known conditions

    private var conditionsSection: some View {
        Section {
            ForEach(draft.knownConditions, id: \.self) { condition in
                Text(condition)
            }
            .onDelete { offsets in
                draft.knownConditions.remove(atOffsets: offsets)
            }

            HStack(spacing: HESpacing.sm) {
                TextField("Add a condition", text: $newCondition)
                    .focused($conditionFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(addCondition)
                Button(action: addCondition) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(trimmedNewCondition.isEmpty)
                .accessibilityLabel("Add condition")
            }
        } header: {
            Text("Known conditions")
        } footer: {
            Text("Optional. Helps Heartelfie phrase insights more carefully. Stored only on your device.")
        }
    }

    private var trimmedNewCondition: String {
        newCondition.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addCondition() {
        let trimmed = trimmedNewCondition
        guard !trimmed.isEmpty else { return }
        if !draft.knownConditions.contains(trimmed) {
            draft.knownConditions.append(trimmed)
        }
        newCondition = ""
        conditionFieldFocused = false
    }

    // MARK: - Skin tone

    private var skinToneSection: some View {
        Section {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                skinToneGrid

                if draft.monkSkinTone != nil {
                    Button("Clear selection") {
                        draft.monkSkinTone = nil
                    }
                    .font(.heCallout)
                    .foregroundStyle(Color.hePrimary)
                }
            }
            .padding(.vertical, HESpacing.xs)
        } header: {
            Text("Skin tone")
        } footer: {
            Text(MonkSkinTone.usageDisclosure)
        }
    }

    private var skinToneGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: HESpacing.sm),
            count: 5
        )
        return LazyVGrid(columns: columns, spacing: HESpacing.md) {
            ForEach(MonkSkinTone.all) { tone in
                Button {
                    draft.monkSkinTone = tone
                } label: {
                    MonkSkinToneSwatch(tone: tone, isSelected: draft.monkSkinTone == tone)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tone.accessibilityLabel)
                .accessibilityAddTraits(draft.monkSkinTone == tone ? [.isSelected] : [])
            }
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
    var unitSystem: UnitSystem = .metric

    var includeAge: Bool = false
    var age: Int = 35

    var biologicalSex: BiologicalSex?

    var includeHeight: Bool = false
    var heightCM: Double = 170

    var includeWeight: Bool = false
    var weightKG: Double = 70

    var knownConditions: [String] = []
    var monkSkinTone: MonkSkinTone?

    // Imperial mirrors, derived from / written back to the canonical metric values.
    var heightIN: Double {
        get { heightCM / 2.54 }
        set { heightCM = newValue * 2.54 }
    }

    var weightLB: Double {
        get { weightKG * 2.2046226218 }
        set { weightKG = newValue / 2.2046226218 }
    }

    init() {}

    init(profile: HealthProfile) {
        unitSystem = profile.unitSystem

        if let age = profile.age {
            includeAge = true
            self.age = age
        }
        biologicalSex = profile.biologicalSex

        if let cm = profile.heightCM {
            includeHeight = true
            heightCM = cm
        }
        if let kg = profile.weightKG {
            includeWeight = true
            weightKG = kg
        }
        knownConditions = profile.knownConditions
        monkSkinTone = profile.monkSkinTone
    }

    func toProfile() -> HealthProfile {
        HealthProfile(
            age: includeAge ? age : nil,
            biologicalSex: biologicalSex,
            heightCM: includeHeight ? heightCM : nil,
            weightKG: includeWeight ? weightKG : nil,
            knownConditions: knownConditions,
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
