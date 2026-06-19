import SwiftUI
import HECore

/// A capture countdown ring shown during acquisition. The arc depletes as
/// `progress` advances (0 → 1) and the remaining seconds are shown as a big,
/// glanceable numeral. The arc transition respects Reduce Motion.
public struct CountdownRing: View {
    private let progress: Double
    private let secondsRemaining: Int
    private let lineWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(progress: Double, secondsRemaining: Int, lineWidth: CGFloat = 14) {
        self.progress = progress
        self.secondsRemaining = secondsRemaining
        self.lineWidth = lineWidth
    }

    private var clamped: Double { min(max(progress, 0), 1) }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.heSeparator, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: max(0.0001, clamped))
                .stroke(
                    Color.hePrimary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: clamped)

            VStack(spacing: HESpacing.xxs) {
                Text(verbatim: "\(max(secondsRemaining, 0))")
                    .font(.heMetricNumeral)
                    .monospacedDigit()
                    .foregroundStyle(Color.heTextPrimary)
                    .contentTransition(.numericText(countsDown: true))

                Text("seconds left")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
            }
            .padding(lineWidth + HESpacing.sm)
        }
        .padding(lineWidth / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capturing")
        .accessibilityValue("\(max(secondsRemaining, 0)) seconds remaining")
    }
}

#Preview("Countdown ring") {
    CountdownRing(progress: 0.65, secondsRemaining: 7)
        .frame(width: 200, height: 200)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.heBackground)
}
