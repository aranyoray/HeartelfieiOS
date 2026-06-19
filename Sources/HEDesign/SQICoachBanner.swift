import SwiftUI
import HECore

/// Surfaces the single most useful signal-quality coaching tip during/after a
/// capture. Shows the top `SQIIssue`'s actionable message and glyph; when there
/// are no issues and the signal is acceptable, it shows a calm, positive
/// "Signal looks good" state. Color follows the SQI band.
public struct SQICoachBanner: View {
    private let quality: SignalQuality

    public init(quality: SignalQuality) {
        self.quality = quality
    }

    /// The best-fix-first issue to coach, if any.
    private var topIssue: SQIIssue? { quality.issues.first }

    private var isPositive: Bool { topIssue == nil && quality.isAcceptable }

    private var tint: Color {
        // A clean, acceptable signal always reads as "good" regardless of the
        // exact SQI band number.
        isPositive ? Color.heRisk(.normal) : Color.heSQI(quality.band)
    }

    private var systemImage: String {
        if let topIssue { return topIssue.systemImage }
        return isPositive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
    }

    private var message: String {
        if let topIssue { return topIssue.coachingMessage }
        if isPositive { return "Signal looks good — hold steady." }
        return "Signal is a little weak — adjust and try again."
    }

    private var title: String {
        if isPositive { return "Signal looks good" }
        return "Improve your signal"
    }

    public var body: some View {
        HStack(alignment: .top, spacing: HESpacing.md) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                Text(title)
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text(message)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(HESpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview("SQI coach banner") {
    VStack(spacing: HESpacing.md) {
        SQICoachBanner(quality: .pristine)
        SQICoachBanner(
            quality: SignalQuality(sqi: 0.45, isAcceptable: false, issues: [.motion, .lowLight])
        )
        SQICoachBanner(
            quality: SignalQuality(sqi: 0.3, isAcceptable: false, issues: [.noContact])
        )
        SQICoachBanner(
            quality: SignalQuality(sqi: 0.55, isAcceptable: false, issues: [])
        )
    }
    .padding()
    .background(Color.heBackground)
}
