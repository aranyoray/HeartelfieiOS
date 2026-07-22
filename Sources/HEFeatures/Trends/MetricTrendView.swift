import SwiftUI
import Charts
import HECore
import HEDesign
import HEPersistence

/// A focused, single-metric trend detail: a larger chart with the reference band,
/// current / average / min / max stats, a gentle plain-language trend callout, and
/// the non-diagnostic footer. Reached via `AppRoute.metricTrend(metric)`.
struct MetricTrendView: View {
    @Environment(AppEnvironment.self) private var env

    private let metric: MetricKind

    @State private var range: TrendDetailRange = .month
    @State private var series: [TimeSeriesPoint] = []
    @State private var hasLoaded = false

    init(metric: MetricKind) {
        self.metric = metric
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                rangePicker
                chartCard
                statsCard
                trendCallout
                referenceCard
                NonDiagnosticFooter()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle(metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: range) { _, _ in Task { await load() } }
    }

    // MARK: - Range

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(TrendDetailRange.allCases) { r in
                Text(r.title).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Time range")
    }

    // MARK: - Chart

    private var chartCard: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                HStack(spacing: HESpacing.sm) {
                    Image(systemName: metric.systemImage)
                        .font(.heTitle)
                        .foregroundStyle(Color.hePrimary)
                        .accessibilityHidden(true)
                    Text("Over the last \(range.title)")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Spacer(minLength: 0)
                }

                if series.isEmpty {
                    emptyChart
                } else {
                    chart
                        .frame(height: 280)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chartAccessibilitySummary)
    }

    private var chart: some View {
        Chart {
            if let refRange {
                RectangleMark(
                    yStart: .value("Typical low", refRange.low),
                    yEnd: .value("Typical high", refRange.high)
                )
                .foregroundStyle(Color.heRisk(.normal).opacity(0.12))
                .accessibilityHidden(true)
                RuleMark(y: .value("Typical low", refRange.low))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.heRisk(.normal).opacity(0.5))
                    .accessibilityHidden(true)
                RuleMark(y: .value("Typical high", refRange.high))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.heRisk(.normal).opacity(0.5))
                    .accessibilityHidden(true)
            }

            ForEach(series) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(metric.shortName, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.hePrimary.opacity(0.25), Color.hePrimary.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                .accessibilityHidden(true)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value(metric.shortName, point.value)
                )
                .foregroundStyle(Color.hePrimary)
                .interpolationMethod(.catmullRom)
                .symbol(.circle)
                .symbolSize(30)
                .accessibilityLabel(point.date.formatted(.dateTime.month().day()))
                .accessibilityValue("\(formatted(point.value)) \(metric.unit)")
            }

            if let avg = stats?.average {
                RuleMark(y: .value("Average", avg))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                    .foregroundStyle(Color.heAccent.opacity(0.8))
                    .annotation(position: .top, alignment: .leading) {
                        Text("avg")
                            .font(.heCaption)
                            .foregroundStyle(Color.heAccent)
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(preset: .aligned) { _ in
                AxisGridLine().foregroundStyle(Color.heSeparator.opacity(0.5))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.heCaption)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.heSeparator.opacity(0.5))
                AxisValueLabel().font(.heCaption)
            }
        }
    }

    private var emptyChart: some View {
        VStack(spacing: HESpacing.sm) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(Color.heTextTertiary)
                .accessibilityHidden(true)
            Text(hasLoaded
                ? "No \(metric.displayName) readings in this range yet."
                : "Loading…")
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
    }

    // MARK: - Stats

    private var statsCard: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                Text("At a glance")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)

                if let stats {
                    HStack(spacing: HESpacing.md) {
                        statTile("Latest", stats.latest)
                        statTile("Average", stats.average)
                        statTile("Lowest", stats.min)
                        statTile("Highest", stats.max)
                    }
                } else {
                    Text("Take a few \(metric.displayName.lowercased()) checks to see your stats.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                }
            }
        }
    }

    private func statTile(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: HESpacing.xxs) {
            Text(title)
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
            Text(formatted(value))
                .font(.heHeadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.heTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(metric.unit)
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(formatted(value)) \(metric.unit)")
    }

    // MARK: - Trend callout

    @ViewBuilder
    private var trendCallout: some View {
        if let message = trendMessage {
            HStack(alignment: .top, spacing: HESpacing.sm) {
                Image(systemName: trendIcon)
                    .font(.heHeadline)
                    .foregroundStyle(Color.hePrimary)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(HESpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                    .fill(Color.hePrimary.opacity(0.08))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
        }
    }

    // MARK: - Reference card

    @ViewBuilder
    private var referenceCard: some View {
        if let refRange {
            HECard {
                VStack(alignment: .leading, spacing: HESpacing.xs) {
                    Label("Typical range", systemImage: "rectangle.dashed")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Text("\(refRange.displayString). This is a configurable wellness reference, not a clinical cutoff.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Derived

    private var refRange: ClinicalRange? {
        ClinicalConfig.referenceRange(for: metric, profile: env.profile)
    }

    private struct Stats {
        let latest: Double
        let average: Double
        let min: Double
        let max: Double
    }

    private var stats: Stats? {
        let values = series.map(\.value)
        guard let latest = values.last, let lo = values.min(), let hi = values.max() else { return nil }
        let avg = values.reduce(0, +) / Double(values.count)
        return Stats(latest: latest, average: avg, min: lo, max: hi)
    }

    private var yDomain: ClosedRange<Double> {
        let values = series.map(\.value)
        var lo = values.min() ?? 0
        var hi = values.max() ?? 1
        if let ref = refRange {
            lo = min(lo, ref.low)
            hi = max(hi, ref.high)
        }
        if lo == hi { lo -= 1; hi += 1 }
        let pad = (hi - lo) * 0.12
        return (lo - pad)...(hi + pad)
    }

    private var trendIcon: String {
        guard let slope = slope else { return "minus" }
        if slope > slopeThreshold { return "arrow.up.right" }
        if slope < -slopeThreshold { return "arrow.down.right" }
        return "arrow.left.and.right"
    }

    /// A simple first-to-last comparison (averaged over the first/last third) so
    /// the callout is robust to a single noisy point. Returns `nil` for <4 points.
    private var slope: Double? {
        guard series.count >= 4 else { return nil }
        let values = series.map(\.value)
        let third = max(values.count / 3, 1)
        let firstAvg = values.prefix(third).reduce(0, +) / Double(third)
        let lastAvg = values.suffix(third).reduce(0, +) / Double(third)
        return lastAvg - firstAvg
    }

    /// Threshold below which we call the metric "steady" (5% of the typical span,
    /// or a small absolute floor when there's no reference range).
    private var slopeThreshold: Double {
        if let ref = refRange { return (ref.high - ref.low) * 0.05 }
        return 1
    }

    /// A gentle, non-diagnostic, plain-language trend description.
    private var trendMessage: String? {
        guard series.count >= 2 else {
            return series.isEmpty ? nil : "Just one \(metric.displayName.lowercased()) reading so far — keep checking to build a trend."
        }
        let name = metric.displayName
        guard let slope else {
            return "Keep taking \(name.lowercased()) checks to reveal a clearer trend."
        }
        if abs(slope) <= slopeThreshold {
            return "Your \(name.lowercased()) has been fairly steady over the last \(range.title). Steady trends are a good sign — keep it up."
        }
        let direction = slope > 0 ? "trending up" : "trending down"
        let magnitude = formatted(abs(slope))
        return "Your \(name.lowercased()) has been \(direction) by about \(magnitude) \(metric.unit) over the last \(range.title). Trends are more meaningful than any single reading; keep tracking and compare patterns with your baseline if you are unsure."
    }

    private var chartAccessibilitySummary: String {
        guard let stats else {
            return "\(metric.displayName) trend. No data in this range."
        }
        var summary = "\(metric.displayName) over \(range.title), \(series.count) points. "
        summary += "Latest \(formatted(stats.latest)), average \(formatted(stats.average)), "
        summary += "from \(formatted(stats.min)) to \(formatted(stats.max)) \(metric.unit). "
        if let ref = refRange { summary += "Typical range \(ref.displayString)." }
        return summary
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(metric.fractionDigits)))
    }

    // MARK: - Loading

    private func load() async {
        let loaded = (try? await env.repository.timeSeries(metric: metric, days: range.days)) ?? []
        series = loaded
        hasLoaded = true
    }
}

/// Range options for the focused detail chart.
private enum TrendDetailRange: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90
    var id: Int { rawValue }
    var days: Int { rawValue }
    var title: String {
        switch self {
        case .week: return "7 days"
        case .month: return "30 days"
        case .quarter: return "90 days"
        }
    }
}

#Preview("Metric trend") {
    NavigationStack {
        MetricTrendView(metric: .heartRate)
            .environment(AppEnvironment.preview())
    }
}
