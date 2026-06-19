import SwiftUI
import HECore
import HEDesign

/// Step 3 — Monk Skin Tone selector (optional).
///
/// Lets the user self-select a position on the Monk Skin Tone scale so the signal
/// processing can be calibrated more equitably across skin tones. Selection is
/// entirely optional: a clear "Prefer not to say" choice clears it. The usage
/// disclosure (`MonkSkinTone.usageDisclosure`) is shown so the user understands
/// exactly why it's asked and that it stays on-device.
struct OnboardingSkinToneStep: View {
    @Bindable var draft: OnboardingDraft

    /// Five swatches per row reads comfortably across size classes.
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: HESpacing.md),
        count: 5
    )

    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            HESectionHeader(
                title: "Help us read every skin tone fairly",
                subtitle: "Optional — pick the swatch closest to your skin, or skip.",
                systemImage: "circle.lefthalf.filled"
            )

            HECard {
                LazyVGrid(columns: columns, spacing: HESpacing.md) {
                    ForEach(MonkSkinTone.all) { tone in
                        Button {
                            select(tone)
                        } label: {
                            MonkSkinToneSwatch(
                                tone: tone,
                                isSelected: draft.monkSkinTone == tone
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tone.accessibilityLabel)
                        .accessibilityAddTraits(
                            draft.monkSkinTone == tone ? [.isButton, .isSelected] : .isButton
                        )
                    }
                }
            }

            selectionStatus

            preferNotToSayButton

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Label("Why we ask", systemImage: "info.circle")
                        .font(.heCallout.weight(.semibold))
                        .foregroundStyle(Color.heTextPrimary)
                    Text(MonkSkinTone.usageDisclosure)
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Selection status

    /// A spoken/visible confirmation of the current choice — never color-only.
    private var selectionStatus: some View {
        Group {
            if let tone = draft.monkSkinTone {
                Label("Selected: \(tone.accessibilityLabel)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.heRisk(.normal))
            } else {
                Label("No skin tone selected — that's completely fine.", systemImage: "circle.dashed")
                    .foregroundStyle(Color.heTextSecondary)
            }
        }
        .font(.heCaption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var preferNotToSayButton: some View {
        Button {
            draft.monkSkinTone = nil
        } label: {
            Text("Prefer not to say / Skip")
                .font(.heCallout.weight(.semibold))
                .foregroundStyle(Color.hePrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityHint("Clears your skin-tone selection")
    }

    // MARK: - Actions

    private func select(_ tone: MonkSkinTone) {
        // Tapping the current selection again toggles it off.
        draft.monkSkinTone = (draft.monkSkinTone == tone) ? nil : tone
    }
}

#Preview("Skin tone step") {
    ScrollView {
        OnboardingSkinToneStep(draft: OnboardingDraft())
            .padding(HESpacing.lg)
    }
    .background(Color.heBackground)
    .environment(AppEnvironment.preview(onboarded: false))
}
