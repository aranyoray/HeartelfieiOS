import SwiftUI
import HECore

/// A glanceable card for a single `CardioMetric`: kind icon + name, the big
/// formatted value with its unit, a softened `RiskBadge`, and optional note and
/// reference-range strings.
public struct MetricCardView: View {
    private let metric: CardioMetric

    public init(metric: CardioMetric) {
        self.metric = metric
    }

    private var hasUnit: Bool { !metric.unit.isEmpty }

    public var body: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                // Header: icon + name, risk badge trailing.
                HStack(spacing: HESpacing.sm) {
                    Image(systemName: metric.kind.systemImage)
                        .font(.heHeadline)
                        .foregroundStyle(Color.hePrimary)
                        .frame(width: 26)
                        .accessibilityHidden(true)

                    Text(metric.kind.displayName)
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: HESpacing.sm)

                    RiskBadge(metric.risk)
                }

                // Big value.
                HStack(alignment: .firstTextBaseline, spacing: HESpacing.xs) {
                    Text(metric.formattedValue)
                        .font(.heMetricNumeralCompact)
                        .foregroundStyle(Color.heTextPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if hasUnit {
                        Text(metric.unit)
                            .font(.heUnit)
                            .foregroundStyle(Color.heTextSecondary)
                    }
                }

                // Reference range.
                if let range = metric.referenceRange {
                    Text("Typical: \(range.displayString)")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }

                // Note (e.g. "approximate" for screening SpO₂).
                if let note = metric.note {
                    Text(note)
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = ["\(metric.kind.displayName), \(metric.formattedValueWithUnit)"]
        parts.append(metric.risk.displayName)
        if let range = metric.referenceRange {
            parts.append("typical range \(range.displayString)")
        }
        if let note = metric.note {
            parts.append(note)
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Metric card") {
    ScrollView {
        VStack(spacing: HESpacing.md) {
            if let metric = SampleData.fingerPPGReading().metrics.first {
                MetricCardView(metric: metric)
            }
            MetricCardView(
                metric: CardioMetric(
                    kind: .spo2Estimate,
                    value: 97,
                    note: "Approximate — screening only",
                    profile: SampleData.profile
                )
            )
            MetricCardView(
                metric: CardioMetric(
                    kind: .hemoglobin,
                    value: 11.2,
                    profile: SampleData.profile
                )
            )
            MetricCardView(
                metric: CardioMetric(kind: .respiratoryRate, value: 16, profile: SampleData.profile)
            )
        }
        .padding()
    }
    .background(Color.heBackground)
}
