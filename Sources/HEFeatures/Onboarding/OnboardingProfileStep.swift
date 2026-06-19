import SwiftUI
import HECore
import HEDesign

/// Step 4 — Basic health profile (all optional).
///
/// Collects a lean, mostly-optional profile: age, biological sex, height, weight,
/// and any known conditions. Height/weight respect the chosen `UnitSystem` for
/// display but are always normalised to centimetres/kilograms when the draft is
/// turned into a `HealthProfile`. Each field has an explicit opt-in toggle so a
/// user can share only what they're comfortable with — or nothing at all.
struct OnboardingProfileStep: View {
    @Bindable var draft: OnboardingDraft
    @State private var newCondition: String = ""
    @FocusState private var conditionFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            HESectionHeader(
                title: "A little about you",
                subtitle: "All optional — it helps put your readings in context. Share only what you like.",
                systemImage: "person.text.rectangle"
            )

            unitsCard
            ageCard
            biologicalSexCard
            heightCard
            weightCard
            conditionsCard
        }
    }

    // MARK: - Units

    private var unitsCard: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                Text("Units")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)

                Picker("Units", selection: unitBinding) {
                    ForEach(UnitSystem.allCases) { system in
                        Text(shortUnitLabel(system)).tag(system)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Measurement units")
                .accessibilityValue(draft.unitSystem.displayName)
            }
        }
    }

    /// Compact label for the segmented control (the full `displayName` is too long
    /// for two segments and is exposed via `accessibilityValue` instead).
    private func shortUnitLabel(_ system: UnitSystem) -> String {
        switch system {
        case .metric: return "kg · cm"
        case .imperial: return "lb · in"
        }
    }

    /// Flipping units re-expresses the entered height/weight so the physical
    /// measurement is preserved.
    private var unitBinding: Binding<UnitSystem> {
        Binding(
            get: { draft.unitSystem },
            set: { draft.convertEnteredValues(to: $0) }
        )
    }

    // MARK: - Age

    private var ageCard: some View {
        OptionalFieldCard(
            title: "Age",
            systemImage: "number",
            isOn: $draft.includeAge
        ) {
            Stepper(value: $draft.age, in: 1...120) {
                HStack {
                    Text("Age")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                    Spacer()
                    Text("\(draft.age)")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                        .monospacedDigit()
                }
            }
            .accessibilityValue("\(draft.age) years")
        }
    }

    // MARK: - Biological sex

    private var biologicalSexCard: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                Text("Biological sex")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text("Used to calibrate some wellness reference ranges.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)

                Picker("Biological sex", selection: $draft.biologicalSex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.hePrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Biological sex")
                .accessibilityValue(draft.biologicalSex.displayName)
            }
        }
    }

    // MARK: - Height

    private var heightCard: some View {
        OptionalFieldCard(
            title: "Height",
            systemImage: "ruler",
            isOn: $draft.includeHeight
        ) {
            MeasurementStepper(
                value: $draft.heightValue,
                range: heightRange,
                step: 1,
                unitLabel: heightUnitLabel,
                accessibilityName: "Height"
            )
        }
    }

    private var heightRange: ClosedRange<Double> {
        draft.unitSystem == .metric ? 90...230 : 36...90
    }

    private var heightUnitLabel: String {
        draft.unitSystem == .metric ? "cm" : "in"
    }

    // MARK: - Weight

    private var weightCard: some View {
        OptionalFieldCard(
            title: "Weight",
            systemImage: "scalemass",
            isOn: $draft.includeWeight
        ) {
            MeasurementStepper(
                value: $draft.weightValue,
                range: weightRange,
                step: 1,
                unitLabel: weightUnitLabel,
                accessibilityName: "Weight"
            )
        }
    }

    private var weightRange: ClosedRange<Double> {
        draft.unitSystem == .metric ? 30...250 : 66...550
    }

    private var weightUnitLabel: String {
        draft.unitSystem == .metric ? "kg" : "lb"
    }

    // MARK: - Known conditions

    private var conditionsCard: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                Text("Known conditions")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text("Anything you'd like to keep in mind. This never leaves your device unless you export it.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if !draft.knownConditions.isEmpty {
                    VStack(spacing: HESpacing.xs) {
                        ForEach(draft.knownConditions, id: \.self) { condition in
                            conditionRow(condition)
                        }
                    }
                }

                HStack(spacing: HESpacing.sm) {
                    TextField("Add a condition", text: $newCondition)
                        .textFieldStyle(.plain)
                        .font(.heBody)
                        .foregroundStyle(Color.heTextPrimary)
                        .focused($conditionFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addCondition)
                        .padding(.vertical, HESpacing.sm)
                        .padding(.horizontal, HESpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HERadius.md, style: .continuous)
                                .fill(Color.heBackground)
                        )
                        .accessibilityLabel("New condition")

                    Button(action: addCondition) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canAddCondition ? Color.hePrimary : Color.heTextTertiary)
                    }
                    .disabled(!canAddCondition)
                    .accessibilityLabel("Add condition")
                }
            }
        }
    }

    private func conditionRow(_ condition: String) -> some View {
        HStack(spacing: HESpacing.sm) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(Color.hePrimary)
                .accessibilityHidden(true)
            Text(condition)
                .font(.heCallout)
                .foregroundStyle(Color.heTextPrimary)
            Spacer(minLength: 0)
            Button {
                removeCondition(condition)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.heTextTertiary)
            }
            .accessibilityLabel("Remove \(condition)")
        }
        .padding(.vertical, HESpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(condition)
    }

    // MARK: - Conditions logic

    private var canAddCondition: Bool {
        !newCondition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addCondition() {
        let trimmed = newCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Case-insensitive de-dupe so the list stays tidy.
        if !draft.knownConditions.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            draft.knownConditions.append(trimmed)
        }
        newCondition = ""
        conditionFieldFocused = false
    }

    private func removeCondition(_ condition: String) {
        draft.knownConditions.removeAll { $0 == condition }
    }
}

// MARK: - Optional field card

/// A card whose content is gated behind a "share this" toggle. Keeps the
/// share/don't-share affordance consistent across age, height, and weight.
private struct OptionalFieldCard<Content: View>: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                Toggle(isOn: $isOn) {
                    Label {
                        Text(title)
                            .font(.heHeadline)
                            .foregroundStyle(Color.heTextPrimary)
                    } icon: {
                        Image(systemName: systemImage)
                            .foregroundStyle(Color.hePrimary)
                    }
                }
                .tint(Color.hePrimary)
                .accessibilityHint("Choose whether to share your \(title.lowercased())")

                if isOn {
                    content
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Measurement stepper

/// A unit-aware stepper that shows a large value with its unit suffix. Used for
/// height and weight so the control stays accessible and the unit is always
/// spoken.
private struct MeasurementStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unitLabel: String
    let accessibilityName: String

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack(alignment: .firstTextBaseline, spacing: HESpacing.xs) {
                Text(value, format: .number.precision(.fractionLength(0)))
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                    .monospacedDigit()
                Text(unitLabel)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                Spacer()
            }
        }
        .accessibilityLabel(accessibilityName)
        .accessibilityValue("\(value.formatted(.number.precision(.fractionLength(0)))) \(unitLabel)")
    }
}

#Preview("Profile step") {
    ScrollView {
        OnboardingProfileStep(draft: OnboardingDraft())
            .padding(HESpacing.lg)
    }
    .background(Color.heBackground)
    .environment(AppEnvironment.preview(onboarded: false))
}
