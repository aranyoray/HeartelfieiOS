import SwiftUI
import HECore

/// A compact segmented meter for a reading's `Confidence`. Shows three segments
/// that fill according to the band, plus the percentage and band name. The low
/// band is visually distinct (amber, fewer filled segments) but intentionally
/// calm — low confidence is a prompt to recheck, not an alarm.
public struct ConfidenceMeter: View {
    private let confidence: Confidence

    public init(_ confidence: Confidence) {
        self.confidence = confidence
    }

    /// How many of the three segments are filled for this band.
    private var filledSegments: Int {
        switch confidence.band {
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        }
    }

    private var tint: Color { Color.heConfidence(confidence.band) }

    public var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            HStack(spacing: HESpacing.xs) {
                Image(systemName: confidence.isLow ? "gauge.with.dots.needle.bottom.0percent" : "gauge.with.dots.needle.bottom.50percent")
                    .font(.heCallout.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                Text(confidence.band.displayName)
                    .font(.heCallout.weight(.semibold))
                    .foregroundStyle(Color.heTextPrimary)

                Spacer(minLength: HESpacing.sm)

                Text(confidence.percentString)
                    .font(.heCallout.weight(.semibold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }

            // Segmented bar.
            HStack(spacing: HESpacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index < filledSegments ? tint : Color.heSeparator)
                        .frame(height: 6)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence \(confidence.percentString), \(confidence.band.displayName)")
    }
}

#Preview("Confidence meter") {
    VStack(alignment: .leading, spacing: HESpacing.lg) {
        ConfidenceMeter(Confidence(0.91))
        ConfidenceMeter(Confidence(0.62))
        ConfidenceMeter(Confidence(0.38))
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.heBackground)
}
