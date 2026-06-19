import SwiftUI
import HECore

/// A circular skin-tone swatch for the onboarding Monk Skin Tone selector. Filled
/// from the tone's representative hex, with a clear selection ring and an
/// accessible label. Selection is conveyed by the ring **and** the accessibility
/// "selected" trait, never by color alone.
public struct MonkSkinToneSwatch: View {
    private let tone: MonkSkinTone
    private let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(tone: MonkSkinTone, isSelected: Bool) {
        self.tone = tone
        self.isSelected = isSelected
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: tone.swatchHex))
                .overlay(
                    // Subtle inner edge so very light swatches stay visible on white.
                    Circle().strokeBorder(Color.heSeparator.opacity(0.6), lineWidth: 1)
                )

            if isSelected {
                Circle()
                    .strokeBorder(Color.hePrimary, lineWidth: 3)
                    .padding(-4)

                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2)
            }
        }
        .frame(width: 44, height: 44)
        .scaleEffect(isSelected && !reduceMotion ? 1.06 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tone.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Monk skin tone swatches") {
    let selected = MonkSkinTone(value: 6)
    return VStack(spacing: HESpacing.lg) {
        HStack(spacing: HESpacing.sm) {
            ForEach(Array(MonkSkinTone.all.prefix(5))) { tone in
                MonkSkinToneSwatch(tone: tone, isSelected: tone == selected)
            }
        }
        HStack(spacing: HESpacing.sm) {
            ForEach(Array(MonkSkinTone.all.suffix(5))) { tone in
                MonkSkinToneSwatch(tone: tone, isSelected: tone == selected)
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.heBackground)
}
