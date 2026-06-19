import SwiftUI
import HECore

/// The full 10-point Monk Skin Tone scale rendered as ten numbered, selectable
/// boxes. Used in onboarding and the profile editor.
///
/// Selection is non-color-dependent (number + checkmark + ring), respects Reduce
/// Motion, and is fully VoiceOver-labelled.
public struct MonkSkinToneScale: View {
    @Binding private var selection: MonkSkinTone?
    private let allowsDeselect: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(selection: Binding<MonkSkinTone?>, allowsDeselect: Bool = true) {
        self._selection = selection
        self.allowsDeselect = allowsDeselect
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: HESpacing.sm),
        count: 5
    )

    public var body: some View {
        LazyVGrid(columns: columns, spacing: HESpacing.sm) {
            ForEach(MonkSkinTone.all) { tone in
                box(for: tone)
            }
        }
    }

    private func box(for tone: MonkSkinTone) -> some View {
        let isSelected = selection == tone
        return Button {
            if reduceMotion {
                toggle(tone)
            } else {
                withAnimation(.snappy(duration: 0.18)) { toggle(tone) }
            }
        } label: {
            RoundedRectangle(cornerRadius: HERadius.sm, style: .continuous)
                .fill(Color(hex: tone.swatchHex))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text("\(tone.value)")
                        .font(.heCaption.weight(.semibold))
                        .foregroundStyle(tone.value >= 6 ? Color.white : Color.black.opacity(0.65))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: HERadius.sm, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.hePrimary : Color.heSeparator,
                            lineWidth: isSelected ? 3 : 1
                        )
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color.hePrimary)
                            .padding(3)
                            .accessibilityHidden(true)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tone.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    private func toggle(_ tone: MonkSkinTone) {
        if selection == tone && allowsDeselect {
            selection = nil
        } else {
            selection = tone
        }
    }
}

#Preview("Monk Skin Tone scale") {
    struct PreviewHost: View {
        @State private var tone: MonkSkinTone? = MonkSkinTone(value: 6)
        var body: some View {
            VStack(alignment: .leading, spacing: HESpacing.lg) {
                Text("Monk Skin Tone")
                    .font(.heHeadline)
                MonkSkinToneScale(selection: $tone)
                Text(tone.map { "Selected: \($0.value)" } ?? "None selected")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
            }
            .padding()
        }
    }
    return PreviewHost()
}
