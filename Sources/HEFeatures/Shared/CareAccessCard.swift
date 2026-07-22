import SwiftUI
import HECore
import HEDesign

/// Non-diagnostic wellness context shown beside readings that need extra
/// interpretation help. It deliberately avoids reading-driven medical actions.
public struct CareAccessCard: View {
    private let tier: MeasurementTier
    private let risk: RiskLevel
    private let lowConfidence: Bool

    public init(tier: MeasurementTier, risk: RiskLevel, lowConfidence: Bool = false) {
        self.tier = tier
        self.risk = risk
        self.lowConfidence = lowConfidence
    }

    private var tips: [String] {
        CareGuidance.tips(tier: tier, risk: risk, lowConfidence: lowConfidence)
    }

    private var accent: Color {
        risk == .elevated ? Color.heRisk(.elevated) : Color.hePrimary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            header

            if !tips.isEmpty {
                tipsList
            }

            Text("Heartelfie is a wellness screening tool. It does not diagnose, treat, or recommend care based on a reading.")
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HESpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .fill(accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: HESpacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.heTitle)
                .foregroundStyle(accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                Text("Wellness context")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text("Use this as a retake and trend-comparison guide, not as medical advice.")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tipsList: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: HESpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.heCaption)
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)

                    Text(tip)
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wellness context. " + tips.joined(separator: ". "))
    }
}

#Preview("Wellness context - elevated") {
    CareAccessCard(tier: .measurement, risk: .elevated, lowConfidence: false)
        .padding()
        .background(Color.heBackground)
}

#Preview("Wellness context - routine") {
    CareAccessCard(tier: .measurement, risk: .normal, lowConfidence: false)
        .padding()
        .background(Color.heBackground)
}
