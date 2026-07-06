import SwiftUI
import HECore
import HEDesign

/// Actionable care access shown on clinical (device measurement) results and
/// elevated-risk cases: non-diagnostic tips plus **immediate links** to call
/// emergency services and find nearby hospitals, and an optional advice line.
///
/// Calm and non-diagnostic: it frames care as "next steps", escalating to
/// "get care now" only when the reading is elevated. Uses the device dialer
/// (`tel:`) and Apple Maps search (`maps.apple.com`) via `openURL`.
public struct CareAccessCard: View {
    private let tier: MeasurementTier
    private let risk: RiskLevel
    private let lowConfidence: Bool

    @Environment(\.openURL) private var openURL

    public init(tier: MeasurementTier, risk: RiskLevel, lowConfidence: Bool = false) {
        self.tier = tier
        self.risk = risk
        self.lowConfidence = lowConfidence
    }

    private var isEmergency: Bool { CareGuidance.urgency(risk: risk) == .emergency }
    private var tips: [String] { CareGuidance.tips(tier: tier, risk: risk, lowConfidence: lowConfidence) }
    /// Softened accent — coral for elevated, calm teal otherwise. Never alarmist.
    private var accent: Color { isEmergency ? Color.heRisk(.elevated) : Color.hePrimary }

    public var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            header
            if !tips.isEmpty { tipsList }
            actions
            Text(Disclaimers.emergency)
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
                .strokeBorder(accent.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: HESpacing.sm) {
            Image(systemName: isEmergency ? "cross.case.fill" : "stethoscope")
                .font(.heTitle)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                Text(isEmergency ? "Get care now" : "Get care & next steps")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text(isEmergency
                     ? "This reading is outside the typical range. It isn't a diagnosis — but don't wait on symptoms."
                     : "Tips and quick ways to reach care. This is wellness guidance, not a diagnosis.")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tips

    private var tipsList: some View {
        VStack(alignment: .leading, spacing: HESpacing.xs) {
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
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
        .accessibilityLabel("Tips. " + tips.joined(separator: ". "))
    }

    // MARK: - Immediate links

    private var actions: some View {
        VStack(spacing: HESpacing.sm) {
            // Elevated → lead with the emergency call. Otherwise lead with the
            // hospital finder and keep the emergency call as a calm text link.
            if isEmergency {
                emergencyCallButton
                findHospitalsButton
            } else {
                findHospitalsButton
                emergencyCallLink
            }

            if let advice = HeartelfieConfig.Care.adviceLineNumber {
                HESecondaryButton("Call a nurse advice line", systemImage: "phone") {
                    call(advice)
                }
            }
        }
    }

    private var emergencyCallButton: some View {
        Button {
            call(HeartelfieConfig.Care.emergencyNumber)
        } label: {
            Label(
                "Call emergency services (\(HeartelfieConfig.Care.emergencyNumber))",
                systemImage: "phone.fill.arrow.up.right"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityHint("Calls your local emergency number. Placeholder — confirm the number for your region.")
    }

    private var findHospitalsButton: some View {
        HESecondaryButton("Find nearby hospitals", systemImage: "cross.fill") {
            openMaps(query: HeartelfieConfig.Care.hospitalSearchQuery)
        }
        .accessibilityHint("Opens Maps to search for hospitals near you.")
    }

    private var emergencyCallLink: some View {
        Button {
            call(HeartelfieConfig.Care.emergencyNumber)
        } label: {
            Label("In an emergency, call \(HeartelfieConfig.Care.emergencyNumber)", systemImage: "phone.fill")
                .font(.heCallout.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, HESpacing.xs)
        }
        .foregroundStyle(Color.heRisk(.elevated))
        .accessibilityHint("Calls your local emergency number. Placeholder — confirm the number for your region.")
    }

    // MARK: - Actions

    private func call(_ number: String) {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }

    private func openMaps(query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Hospital"
        guard let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else { return }
        openURL(url)
    }
}

#Preview("Elevated (emergency framing)") {
    ScrollView {
        CareAccessCard(tier: .measurement, risk: .elevated, lowConfidence: false)
            .padding()
    }
    .background(Color.heBackground)
}

#Preview("Clinical (routine framing)") {
    ScrollView {
        CareAccessCard(tier: .measurement, risk: .normal, lowConfidence: false)
            .padding()
    }
    .background(Color.heBackground)
}
