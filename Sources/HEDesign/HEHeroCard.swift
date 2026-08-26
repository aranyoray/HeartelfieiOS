import SwiftUI

/// A high-emphasis gradient card for a screen's hero moment (home greeting,
/// finished reading). Content is expected to style itself for the dark teal
/// gradient (white text, translucent chips) — use `HEHeroChip` for badges.
public struct HEHeroCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(HESpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HERadius.xl, style: .continuous)
                    .fill(Color.heHeroGradient)
            )
            .heCardShadow()
    }
}

/// A translucent capsule chip for use on top of `HEHeroCard`.
public struct HEHeroChip: View {
    private let text: String
    private let systemImage: String?

    public init(_ text: String, systemImage: String? = nil) {
        self.text = text
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: HESpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }
            Text(text)
                .font(.heCaption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, HESpacing.sm)
        .padding(.vertical, HESpacing.xs)
        .background(Capsule().fill(.white.opacity(0.18)))
    }
}

#Preview {
    VStack(spacing: 16) {
        HEHeroCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Good evening")
                    .font(.heTitle)
                    .foregroundStyle(.white)
                HStack {
                    HEHeroChip("3-day streak", systemImage: "flame.fill")
                    HEHeroChip("Checked today", systemImage: "checkmark")
                }
            }
        }
    }
    .padding()
}
