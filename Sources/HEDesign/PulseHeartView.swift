import SwiftUI
import HECore

/// A heart glyph that gently pulses in time with the given BPM. When `bpm` is
/// `nil` (no live rate yet) or Reduce Motion is enabled, it renders a calm,
/// static heart instead of animating.
public struct PulseHeartView: View {
    private let bpm: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(bpm: Double?) {
        self.bpm = bpm
    }

    /// Seconds per beat, clamped to a plausible, smooth range (40–200 bpm).
    private var beatPeriod: Double? {
        guard let bpm, bpm > 0 else { return nil }
        let clamped = min(max(bpm, 40), 200)
        return 60.0 / clamped
    }

    private var shouldAnimate: Bool { beatPeriod != nil && !reduceMotion }

    public var body: some View {
        Group {
            if shouldAnimate, let period = beatPeriod {
                TimelineView(.animation) { timeline in
                    heart(scale: pulseScale(at: timeline.date, period: period))
                }
            } else {
                heart(scale: 1.0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func heart(scale: CGFloat) -> some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.heRisk(.elevated).opacity(0.9))
            .scaleEffect(scale)
            .shadow(color: Color.heRisk(.elevated).opacity(0.35 * Double(scale)), radius: 12 * scale)
            .animation(nil, value: scale) // TimelineView already drives the change.
    }

    /// A quick "lub" contraction followed by a relaxed recovery, mapped into a
    /// 1.0...1.18 scale range. Uses the absolute timeline time so it stays smooth
    /// regardless of when the view appears.
    private func pulseScale(at date: Date, period: Double) -> CGFloat {
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period // 0...1

        // Systole: fast rise/fall in the first ~30% of the cycle.
        let beat: Double
        if phase < 0.3 {
            let local = phase / 0.3
            beat = sin(local * .pi) // 0 → 1 → 0
        } else {
            beat = 0
        }
        return 1.0 + CGFloat(beat) * 0.18
    }

    private var accessibilityLabel: String {
        if let bpm, bpm > 0 {
            return "Heart rate \(Int(bpm.rounded())) beats per minute"
        }
        return "Heart"
    }
}

#Preview("Pulse heart") {
    HStack(spacing: HESpacing.xl) {
        PulseHeartView(bpm: 72)
            .frame(width: 80, height: 80)
        PulseHeartView(bpm: 120)
            .frame(width: 80, height: 80)
        PulseHeartView(bpm: nil)
            .frame(width: 80, height: 80)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.heBackground)
}
