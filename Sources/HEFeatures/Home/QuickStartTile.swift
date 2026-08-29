import SwiftUI
import HECore
import HEDesign

/// A compact quick-start tile for a single phone-screening modality on the Home
/// dashboard. Tapping starts the capture flow.
struct QuickStartTile: View {
    let modality: Modality

    var body: some View {
        NavigationLink(value: AppRoute.capture(modality)) {
            tileContent
        }
        .buttonStyle(HECardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(modality.displayName), \(modality.tier.displayName)")
        .accessibilityHint("Starts a \(modality.tier.shortLabel.lowercased()).")
        .accessibilityAddTraits(.isButton)
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            HStack(alignment: .top, spacing: HESpacing.sm) {
                Image(systemName: modality.systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.hePrimary)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                Spacer(minLength: 0)
            }

            Text(modality.shortName)
                .font(.heHeadline)
                .foregroundStyle(Color.heTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: HESpacing.xs) {
                TierBadge(modality.tier, compact: true)
                Spacer(minLength: 0)
            }
        }
        .padding(HESpacing.md)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .fill(Color.heSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .strokeBorder(Color.heSeparator, lineWidth: 1)
        )
        .heSubtleShadow()
        .contentShape(RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous))
    }
}

#Preview("Quick-start tiles") {
    NavigationStack {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HESpacing.md) {
            QuickStartTile(modality: .fingerPPG)
            QuickStartTile(modality: .facialRPPG)
        }
        .padding()
        .background(Color.heBackground)
    }
}
