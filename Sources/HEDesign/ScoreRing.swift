import SwiftUI
import HECore

/// The Home hero: an animated circular gauge for the daily `CardioScore`. Shows
/// the big numeral value (0–100) with the score's headline, a ring tinted by the
/// softened risk color, and progress driven by `score.progress`.
///
/// Respects Reduce Motion (the ring fills instantly rather than animating) and
/// exposes a single, descriptive VoiceOver element.
public struct ScoreRing: View {
    private let score: CardioScore
    private let lineWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the fill animation from 0 → `score.progress`.
    @State private var animatedProgress: Double = 0

    public init(score: CardioScore, lineWidth: CGFloat = 18) {
        self.score = score
        self.lineWidth = lineWidth
    }

    private var tint: Color { Color.heRisk(score.risk) }

    public var body: some View {
        ZStack {
            // Track.
            Circle()
                .stroke(Color.heSeparator, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Progress arc.
            Circle()
                .trim(from: 0, to: max(0.0001, animatedProgress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tint.opacity(0.65), tint]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center readout.
            VStack(spacing: HESpacing.xxs) {
                // A big "0" before any check reads as a zero score; show a
                // neutral placeholder until a reading contributes.
                Text(verbatim: score.contributingReadings == 0 ? "\u{2013}" : "\(score.value)")
                    .font(.heMetricNumeral)
                    .foregroundStyle(Color.heTextPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if score.contributingReadings > 0 {
                    Text("out of 100")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }

                Text(score.headline)
                    .font(.heCallout.weight(.medium))
                    .foregroundStyle(Color.heTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, HESpacing.sm)
                    .padding(.top, HESpacing.xxs)
            }
            .padding(lineWidth + HESpacing.md)
        }
        .padding(lineWidth / 2)
        .onAppear { applyProgress(animated: !reduceMotion) }
        .onChange(of: score.progress) { _, _ in applyProgress(animated: !reduceMotion) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cardio score \(score.value) out of 100, \(score.risk.displayName)")
        .accessibilityValue(score.headline)
    }

    private func applyProgress(animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.9)) {
                animatedProgress = score.progress
            }
        } else {
            animatedProgress = score.progress
        }
    }
}

#Preview("Score ring") {
    VStack(spacing: HESpacing.xl) {
        ScoreRing(
            score: CardioScore(
                value: 82,
                risk: .normal,
                headline: "Looking steady",
                contributingReadings: 3
            )
        )
        .frame(width: 240, height: 240)

        ScoreRing(
            score: CardioScore(
                value: 54,
                risk: .watch,
                headline: "Worth another check later",
                contributingReadings: 1
            )
        )
        .frame(width: 180, height: 180)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.heBackground)
}
