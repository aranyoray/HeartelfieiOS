import SwiftUI
import HECore

/// A pill that makes a reading's trust tier unmistakable — a *Critical
/// Constraint* of DailyDil. Screening (phone) vs. measurement (device) is
/// surfaced with both an icon and color, and the accessible label spells out the
/// full tier name.
public struct TierBadge: View {
    private let tier: MeasurementTier
    private let compact: Bool

    public init(_ tier: MeasurementTier, compact: Bool = false) {
        self.tier = tier
        self.compact = compact
    }

    private var systemImage: String {
        switch tier {
        case .screening:   return "iphone"
        case .measurement: return "checkmark.seal.fill" // legacy tier: readings from the retired hardware path
        }
    }

    public var body: some View {
        HStack(spacing: HESpacing.xs) {
            Image(systemName: systemImage)
                .font(.heCaption.weight(.semibold))
                .imageScale(.small)

            if !compact {
                Text(tier.shortLabel)
                    .font(.heCaption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Color.heTier(tier))
        .padding(.vertical, HESpacing.xs)
        .padding(.horizontal, compact ? HESpacing.xs : HESpacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(Color.heTier(tier).opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.heTier(tier).opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tier.displayName)
    }
}

#Preview("Tier badges") {
    VStack(alignment: .leading, spacing: HESpacing.md) {
        ForEach(MeasurementTier.allCases) { tier in
            HStack(spacing: HESpacing.md) {
                TierBadge(tier)
                TierBadge(tier, compact: true)
            }
        }
    }
    .padding()
    .background(Color.heBackground)
}
