import SwiftUI
import HECore

/// A small, softened status badge. Status is **never** conveyed by color alone:
/// the glyph (and, by default, the label) always carry the meaning so it remains
/// legible for colorblind users and in high-contrast modes.
public struct RiskBadge: View {
    private let risk: RiskLevel
    private let showsLabel: Bool

    public init(_ risk: RiskLevel, showsLabel: Bool = true) {
        self.risk = risk
        self.showsLabel = showsLabel
    }

    public var body: some View {
        HStack(spacing: HESpacing.xs) {
            Image(systemName: risk.systemImage)
                .font(.heCaption.weight(.semibold))
                .imageScale(.small)

            if showsLabel {
                Text(risk.displayName)
                    .font(.heCaption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Color.heRisk(risk))
        .padding(.vertical, HESpacing.xs)
        .padding(.horizontal, showsLabel ? HESpacing.sm : HESpacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(Color.heRiskSoft(risk))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(risk.displayName)")
    }
}

#Preview("Risk badges") {
    VStack(alignment: .leading, spacing: HESpacing.md) {
        ForEach(RiskLevel.allCases, id: \.self) { risk in
            HStack(spacing: HESpacing.md) {
                RiskBadge(risk)
                RiskBadge(risk, showsLabel: false)
            }
        }
    }
    .padding()
    .background(Color.heBackground)
}
