import SwiftUI
import HECore
import HEDesign

/// A compact quick-start tile for a single modality on the Home dashboard.
///
/// Phone modalities are always usable. Device modalities are shown but visually
/// gated when the Heartelfie device can't currently measure; in that gated state
/// the tile still routes the user toward device pairing rather than the capture
/// flow, so it's never a dead end.
struct QuickStartTile: View {
    let modality: Modality
    /// Whether this modality can be captured right now.
    let isAvailable: Bool

    private var isGatedDevice: Bool { modality.requiresDevice && !isAvailable }

    var body: some View {
        // A gated device tile points at pairing; everything else starts capture.
        NavigationLink(value: isGatedDevice ? AppRoute.devicePairing : AppRoute.capture(modality)) {
            tileContent
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isGatedDevice
            ? "Opens device pairing. Connect your Heartelfie device to use this measurement."
            : "Starts a \(modality.tier.shortLabel.lowercased()).")
        .accessibilityAddTraits(.isButton)
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            HStack(alignment: .top, spacing: HESpacing.sm) {
                Image(systemName: modality.systemImage)
                    .font(.title2)
                    .foregroundStyle(isGatedDevice ? Color.heTextTertiary : Color.hePrimary)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                Spacer(minLength: 0)

                if isGatedDevice {
                    Image(systemName: "lock.fill")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                        .accessibilityHidden(true)
                }
            }

            Text(modality.shortName)
                .font(.heHeadline)
                .foregroundStyle(Color.heTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: HESpacing.xs) {
                TierBadge(modality.tier, compact: true)
                if modality.isExperimental {
                    ExperimentalChip()
                }
                Spacer(minLength: 0)
            }

            if isGatedDevice {
                Text("Connect device")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
                    .lineLimit(1)
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
        .opacity(isGatedDevice ? 0.7 : 1)
        .heSubtleShadow()
        .contentShape(RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous))
    }

    private var accessibilityLabel: String {
        var parts: [String] = [modality.displayName, modality.tier.displayName]
        if modality.isExperimental { parts.append("Experimental") }
        if isGatedDevice { parts.append("Requires the Heartelfie device") }
        return parts.joined(separator: ", ")
    }
}

/// A small, neutral "Experimental" qualifier chip. Matches the calm capsule
/// styling used elsewhere in capture flows.
struct ExperimentalChip: View {
    var body: some View {
        Text("Experimental")
            .font(.heCaption)
            .foregroundStyle(Color.heTextSecondary)
            .padding(.horizontal, HESpacing.sm)
            .padding(.vertical, HESpacing.xxs)
            .background(Color.heTextTertiary.opacity(0.15), in: Capsule(style: .continuous))
            .accessibilityLabel("Experimental")
    }
}

#Preview("Quick-start tiles") {
    NavigationStack {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HESpacing.md) {
            QuickStartTile(modality: .fingerPPG, isAvailable: true)
            QuickStartTile(modality: .facialRPPG, isAvailable: true)
            QuickStartTile(modality: .deviceECG, isAvailable: false)
            QuickStartTile(modality: .deviceMultiWavelengthPPG, isAvailable: true)
        }
        .padding()
        .background(Color.heBackground)
    }
}
