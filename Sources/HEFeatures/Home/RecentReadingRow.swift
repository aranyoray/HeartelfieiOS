import SwiftUI
import HECore
import HEDesign

/// A compact card summarising one recent `CardioReading` for the Home list:
/// modality icon + name, relative time, the primary metric value, a tier badge,
/// and a softened risk badge. Tapping pushes the full reading detail.
struct RecentReadingRow: View {
    let reading: CardioReading

    var body: some View {
        NavigationLink(value: AppRoute.readingDetail(reading)) {
            rowContent
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the full reading detail.")
        .accessibilityAddTraits(.isButton)
    }

    private var rowContent: some View {
        HECard {
            HStack(spacing: HESpacing.md) {
                Image(systemName: reading.modality.systemImage)
                    .font(.title3)
                    .foregroundStyle(Color.hePrimary)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: HESpacing.xs) {
                    HStack(spacing: HESpacing.sm) {
                        Text(reading.modality.shortName)
                            .font(.heHeadline)
                            .foregroundStyle(Color.heTextPrimary)
                            .lineLimit(1)

                        Text(reading.timestamp, format: .relative(presentation: .named))
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextTertiary)
                            .lineLimit(1)
                    }

                    HStack(spacing: HESpacing.sm) {
                        TierBadge(reading.tier, compact: true)
                        RiskBadge(reading.overallRisk)
                    }
                }

                Spacer(minLength: HESpacing.sm)

                if let metric = reading.primaryMetric {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(metric.formattedValue)
                            .font(.heMetricNumeralCompact)
                            .foregroundStyle(Color.heTextPrimary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if !metric.unit.isEmpty {
                            Text(metric.unit)
                                .font(.heCaption)
                                .foregroundStyle(Color.heTextTertiary)
                        }
                    }
                }
            }
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = [reading.modality.displayName]
        if let metric = reading.primaryMetric {
            parts.append("\(metric.kind.displayName) \(metric.formattedValueWithUnit)")
        }
        parts.append(reading.tier.displayName)
        parts.append("Status: \(reading.overallRisk.displayName)")
        let time = reading.timestamp.formatted(.relative(presentation: .named))
        parts.append(time)
        return parts.joined(separator: ", ")
    }
}

#Preview("Recent reading rows") {
    NavigationStack {
        ScrollView {
            VStack(spacing: HESpacing.md) {
                RecentReadingRow(reading: SampleData.fingerPPGReading())
                RecentReadingRow(reading: SampleData.deviceReading(at: Date().addingTimeInterval(-3600)))
                RecentReadingRow(reading: SampleData.lowConfidenceReading(at: Date().addingTimeInterval(-7200)))
            }
            .padding()
        }
        .background(Color.heBackground)
    }
}
