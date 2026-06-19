import SwiftUI
import HECore

/// A smooth, autoscaling waveform renderer built on `Canvas`. Used for the live
/// capture trace and for replaying a reading's `waveformPreview`.
///
/// - Autoscales to the sample min/max so any signal fills the view nicely.
/// - Draws a soft leading-edge glow when `isLive`.
/// - Degrades gracefully: empty or single-sample inputs render just the baseline
///   (or nothing) without crashing.
public struct LiveWaveformView: View {
    private let samples: [Double]
    private let tint: Color
    private let isLive: Bool
    private let showsBaseline: Bool

    public init(
        samples: [Double],
        tint: Color = .hePrimary,
        isLive: Bool = true,
        showsBaseline: Bool = true
    ) {
        self.samples = samples
        self.tint = tint
        self.isLive = isLive
        self.showsBaseline = showsBaseline
    }

    public var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            // Baseline.
            if showsBaseline {
                var baseline = Path()
                baseline.move(to: CGPoint(x: 0, y: size.height / 2))
                baseline.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(
                    baseline,
                    with: .color(Color.heSeparator),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                )
            }

            // Need at least two points to draw a line.
            guard samples.count >= 2 else { return }

            let points = mappedPoints(in: size)
            let path = smoothPath(through: points)

            // Leading-edge glow (subtle), drawn under the main stroke.
            if isLive, let last = points.last {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 6))
                    layer.stroke(
                        path,
                        with: .color(tint.opacity(0.5)),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                }
                // Bright dot at the live edge.
                let dot = Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6))
                context.fill(dot, with: .color(tint))
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 5))
                    layer.fill(dot, with: .color(tint.opacity(0.7)))
                }
            }

            // Main stroke.
            context.stroke(
                path,
                with: .color(tint),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLive ? "Live waveform" : "Waveform")
        .accessibilityHidden(samples.count < 2)
    }

    /// Maps samples to view-space points, autoscaling amplitude to the min/max.
    private func mappedPoints(in size: CGSize) -> [CGPoint] {
        let minV = samples.min() ?? 0
        let maxV = samples.max() ?? 1
        let span = maxV - minV
        // A flat signal sits on the baseline rather than dividing by zero.
        let denom = span == 0 ? 1 : span

        let topInset: CGFloat = 4
        let usableHeight = max(size.height - topInset * 2, 1)
        let stepX = size.width / CGFloat(samples.count - 1)

        return samples.enumerated().map { index, value in
            let normalized = (value - minV) / denom            // 0...1
            let x = CGFloat(index) * stepX
            // Invert Y so larger values rise.
            let y = topInset + (1 - CGFloat(normalized)) * usableHeight
            return CGPoint(x: x, y: y)
        }
    }

    /// A Catmull-Rom-style smoothed path through the points.
    private func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            for p in points.dropFirst() { path.addLine(to: p) }
            return path
        }

        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]

            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        return path
    }
}

#Preview("Live waveform") {
    VStack(spacing: HESpacing.lg) {
        LiveWaveformView(samples: SampleData.syntheticWave(count: 120))
            .frame(height: 120)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                    .fill(Color.heSurface)
            )

        LiveWaveformView(
            samples: SampleData.syntheticWave(count: 80),
            tint: .heAccent,
            isLive: false
        )
        .frame(height: 90)

        // Degenerate inputs render gracefully.
        LiveWaveformView(samples: [])
            .frame(height: 40)
        LiveWaveformView(samples: [0.5])
            .frame(height: 40)
    }
    .padding()
    .background(Color.heBackground)
}
