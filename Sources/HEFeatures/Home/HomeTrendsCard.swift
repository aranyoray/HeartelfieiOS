import SwiftUI
import Charts
import HECore
import HEDesign
import HEPersistence

/// A compact "Your trends" section for the Home dashboard: small heart-rate and
/// HRV sparkline charts (with the configured reference band) that drill into the
/// full per-metric trend. Non-diagnostic; mirrors the deeper Trends tab.
struct HomeTrendsCard: View {
    @Environment(AppEnvironment.self) private var env

    @State private var heartRate: [TimeSeriesPoint] = []
    @State private var hrv: [TimeSeriesPoint] = []
    @State private var hasLoaded = false

    private let days = 30

    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Your trends",
                subtitle: "How your recent checks are tracking.",
                systemImage: "chart.xyaxis.line"
            )

            NavigationLink(value: AppRoute.metricTrend(.heartRate)) {
                MiniTrendChart(metric: .heartRate, points: heartRate, profile: env.profile)
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppRoute.metricTrend(.hrvSDNN)) {
                MiniTrendChart(metric: .hrvSDNN, points: hrv, profile: env.profile)
            }
            .buttonStyle(.plain)
        }
        .task {
            guard !hasLoaded else { return }
            await load()
            hasLoaded = true
        }
        .onChange(of: env.recentReadings.count) {
            Task { await load() }
        }
    }

    private func load() async {
        heartRate = (try? await env.repository.timeSeries(metric: .heartRate, days: days)) ?? []
        hrv = (try? await env.repository.timeSeries(metric: .hrvSDNN, days: days)) ?? []
    }
}

// MARK: - Mini trend chart

private struct MiniTrendChart: View {
    let metric: MetricKind
    let points: [TimeSeriesPoint]
    let profile: HealthProfile?

    private var range: ClinicalRange? {
        ClinicalConfig.referenceRange(for: metric, profile: profile)
    }

    var body: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                header
                if points.count < 2 {
                    emptyChart
                } else {
                    chart
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: HESpacing.sm) {
            Image(systemName: metric.systemImage)
                .foregroundStyle(Color.hePrimary)
                .accessibilityHidden(true)
            Text(metric.displayName)
                .font(.heHeadline)
                .foregroundStyle(Color.heTextPrimary)

            Spacer(minLength: 0)

            if let latest = points.last {
                Text(latest.value.formatted(.number.precision(.fractionLength(metric.fractionDigits))))
                    .font(.heTitle)
                    .monospacedDigit()
                    .foregroundStyle(Color.heTextPrimary)
                Text(metric.unit)
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
                trendGlyph
            }

            Image(systemName: "chevron.right")
                .font(.heCaption.weight(.semibold))
                .foregroundStyle(Color.heTextTertiary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
    }

@ViewBuilder
private var trendGlyph: some View {
Group {
switch trendDirection {
case .up:
Image(systemName: "arrow.up.right").foregroundStyle(Color.heTextSecondary)
case .down:
Image(systemName: "arrow.down.right").foregroundStyle(Color.heTextSecondary)
case .steady:
Image(systemName: "arrow.right").foregroundStyle(Color.heTextTertiary)
}
}
.font(.heCaption.weight(.bold))
.accessibilityHidden(true)
}

    private var chart: some View {
        Chart {
            if let range {
                RectangleMark(
                    xStart: .value("Start", points.first?.date ?? Date()),
                    xEnd: .value("End", points.last?.date ?? Date()),
                    yStart: .value("Low", range.low),
                    yEnd: .value("High", range.high)
                )
                .foregroundStyle(Color.heRisk(.normal).opacity(0.10))
                .accessibilityHidden(true)
            }

            ForEach(points, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(metric.shortName, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.hePrimary.opacity(0.22), Color.hePrimary.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value(metric.shortName, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.hePrimary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            if let latest = points.last {
                PointMark(
                    x: .value("Date", latest.date),
                    y: .value(metric.shortName, latest.value)
                )
                .foregroundStyle(Color.hePrimary)
                .symbolSize(60)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(Color.heSeparator.opacity(0.5))
                AxisValueLabel().font(.heCaption)
            }
        }
        .frame(height: 110)
        .accessibilityHidden(true)
    }

    private var emptyChart: some View {
        HStack(spacing: HESpacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(Color.heTextTertiary)
            Text("Take a few checks to see your \(metric.displayName.lowercased()) trend.")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Trend helpers

    private enum Direction { case up, down, steady }

    /// Compares the average of the first third of points to the last third — a
    /// robust, non-diagnostic "which way is it heading" read.
    private var trendDirection: Direction {
        guard points.count >= 4 else { return .steady }
        let third = max(points.count / 3, 1)
        let firstAvg = average(points.prefix(third).map(\.value))
        let lastAvg = average(points.suffix(third).map(\.value))
        let delta = lastAvg - firstAvg
        let threshold = max(abs(firstAvg) * 0.05, 1)
        if delta > threshold { return .up }
        if delta < -threshold { return .down }
        return .steady
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var accessibilitySummary: String {
        guard let latest = points.last else {
            return "\(metric.displayName) trend, no data yet."
        }
        let valueText = latest.value.formatted(.number.precision(.fractionLength(metric.fractionDigits)))
        let dir: String
        switch trendDirection {
        case .up: dir = "trending up"
        case .down: dir = "trending down"
        case .steady: dir = "holding steady"
        }
        return "\(metric.displayName) latest \(valueText) \(metric.unit), \(dir) over the last \(points.count) checks. Opens full trend."
    }
}

#Preview("Home trends") {
    NavigationStack {
        ScrollView {
            HomeTrendsCard()
                .padding()
        }
        .background(Color.heBackground)
        .environment(AppEnvironment.preview())
    }
}
