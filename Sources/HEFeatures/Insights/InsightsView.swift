import SwiftUI
import HECore
import HEDesign
import HEPersistence

/// The Insights screen: a calm, explicitly non-diagnostic digest of recent checks.
///
/// - A daily cardio summary composed from today's readings (score + what changed).
/// - Plain-language trend callouts derived from recent time series.
/// - "When to seek care" signals surfaced via `ClinicalConfig.seekCareSignal`,
///   labelled clearly and never alarmist.
/// - Gentle wellness guidance plus the persistent `EmergencyNotice`.
struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var allReadings: [CardioReading] = []
    @State private var hrSeries: [TimeSeriesPoint] = []
    @State private var hrvSeries: [TimeSeriesPoint] = []
    @State private var hasLoaded = false

    init() {}

    /// The metrics we compute trend callouts for, with friendly verbs.
    private let calloutMetrics: [MetricKind] = [.heartRate, .hrvSDNN]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                dailySummarySection
                trendCalloutsSection
                seekCareSection
                guidanceSection
                NonDiagnosticFooter()
                EmergencyNotice()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Daily summary

    private var dailySummarySection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Today's summary",
                subtitle: "A soft, non-diagnostic roll-up of today's checks.",
                systemImage: "sun.max.fill"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    HStack(spacing: HESpacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.heRiskSoft(env.todayScore.risk))
                                .frame(width: 64, height: 64)
                            Text(verbatim: "\(env.todayScore.value)")
                                .font(.heTitle)
                                .monospacedDigit()
                                .foregroundStyle(Color.heRisk(env.todayScore.risk))
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: HESpacing.xxs) {
                            Text("Cardio score")
                                .font(.heCaption)
                                .foregroundStyle(Color.heTextTertiary)
                            Text(env.todayScore.headline)
                                .font(.heHeadline)
                                .foregroundStyle(Color.heTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Cardio score \(env.todayScore.value) out of 100, \(env.todayScore.risk.displayName). \(env.todayScore.headline)")

                    Divider().background(Color.heSeparator)

                    Text(whatChanged)
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// One line describing today's checks vs. recent ones. Calm and factual.
    private var whatChanged: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todays = allReadings.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }

        guard !todays.isEmpty else {
            return "No checks logged yet today. A quick 30-second screening keeps your trend up to date."
        }

        let count = todays.count
        let checkWord = count == 1 ? "check" : "checks"
        var line = "You've logged \(count) \(checkWord) today. "

        // Compare today's average heart rate to the recent baseline if we can.
        if let todayHR = average(of: .heartRate, in: todays),
           let baselineHR = recentBaseline(of: .heartRate, excludingToday: today) {
            let delta = todayHR - baselineHR
            if abs(delta) < 3 {
                line += "Your heart rate is in line with your recent average."
            } else if delta > 0 {
                line += "Your heart rate is a little higher than your recent average — common after activity or coffee."
            } else {
                line += "Your heart rate is a little lower than your recent average, often a sign of being relaxed or rested."
            }
        } else {
            line += "Keep checking to build a baseline you can compare against."
        }
        return line
    }

    // MARK: - Trend callouts

    private var trendCalloutsSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Trend callouts",
                subtitle: "Patterns from your recent screenings.",
                systemImage: "chart.line.uptrend.xyaxis"
            )

            if trendCallouts.isEmpty {
                HECard {
                    Text("Take a few more checks over the coming days and your trend callouts will appear here.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: HESpacing.md) {
                    ForEach(trendCallouts) { callout in
                        calloutCard(callout)
                    }
                }
            }
        }
    }

    private func calloutCard(_ callout: TrendCallout) -> some View {
        NavigationLink(value: AppRoute.metricTrend(callout.metric)) {
            HECard {
                HStack(spacing: HESpacing.md) {
                    Image(systemName: callout.icon)
                        .font(.heTitle)
                        .foregroundStyle(Color.hePrimary)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: HESpacing.xxs) {
                        Text(callout.title)
                            .font(.heHeadline)
                            .foregroundStyle(Color.heTextPrimary)
                        Text(callout.detail)
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.heCaption.weight(.semibold))
                        .foregroundStyle(Color.heTextTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(callout.title). \(callout.detail)")
        .accessibilityHint("Opens the \(callout.metric.displayName) trend.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - When to seek care

    private var seekCareSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "When to seek care",
                subtitle: "Gentle, configurable prompts — never a diagnosis.",
                systemImage: "stethoscope"
            )

            if seekCareSignals.isEmpty {
                HECard {
                    HStack(alignment: .top, spacing: HESpacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.heTitle)
                            .foregroundStyle(Color.heRisk(.normal))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: HESpacing.xxs) {
                            Text("Nothing stands out right now")
                                .font(.heHeadline)
                                .foregroundStyle(Color.heTextPrimary)
                            Text("None of your recent screenings crossed the configured wellness thresholds. Keep up your daily checks.")
                                .font(.heCallout)
                                .foregroundStyle(Color.heTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                VStack(spacing: HESpacing.md) {
                    ForEach(seekCareSignals) { signal in
                        seekCareCard(signal)
                    }
                    CareAccessCard(tier: .screening, risk: .watch)
                }
            }
        }
    }

    private func seekCareCard(_ signal: SeekCareItem) -> some View {
        HStack(alignment: .top, spacing: HESpacing.md) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.heTitle)
                .foregroundStyle(Color.heRisk(.watch))
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HESpacing.xs) {
                Text("Consider a professional check")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text(signal.message)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Based on your \(signal.kind.displayName) screenings. This is wellness guidance, not a diagnosis.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(HESpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .fill(Color.heRiskSoft(.watch))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .strokeBorder(Color.heRisk(.watch).opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Consider a professional check. \(signal.message) Based on your \(signal.kind.displayName) screenings. This is wellness guidance, not a diagnosis.")
    }

    // MARK: - Guidance

    private var guidanceSection: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                Label("How to read your insights", systemImage: "lightbulb.fill")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text("Heartelfie surfaces wellness patterns from your phone and device checks. A single reading rarely means much — trends over days and weeks are what's useful. These insights are not a diagnosis and can't confirm or rule out any condition. If something feels wrong, talk to a clinician.")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived models

    private struct TrendCallout: Identifiable {
        let id = UUID()
        let metric: MetricKind
        let title: String
        let detail: String
        let icon: String
    }

    private struct SeekCareItem: Identifiable {
        let id = UUID()
        let kind: MetricKind
        let message: String
    }

    /// Plain-language callouts from the recent HR / HRV series.
    private var trendCallouts: [TrendCallout] {
        var result: [TrendCallout] = []
        if let c = callout(for: .heartRate, series: hrSeries, steadyVerb: "steady", upVerb: "drifting up", downVerb: "easing down") {
            result.append(c)
        }
        if let c = callout(for: .hrvSDNN, series: hrvSeries, steadyVerb: "steady", upVerb: "trending up", downVerb: "trending down") {
            result.append(c)
        }
        return result
    }

    private func callout(
        for metric: MetricKind,
        series: [TimeSeriesPoint],
        steadyVerb: String,
        upVerb: String,
        downVerb: String
    ) -> TrendCallout? {
        guard series.count >= 3 else { return nil }
        let values = series.map(\.value)
        let third = max(values.count / 3, 1)
        let firstAvg = values.prefix(third).reduce(0, +) / Double(third)
        let lastAvg = values.suffix(third).reduce(0, +) / Double(third)
        let delta = lastAvg - firstAvg
        let threshold: Double = {
            if let ref = ClinicalConfig.referenceRange(for: metric, profile: env.profile) {
                return (ref.high - ref.low) * 0.05
            }
            return 1
        }()

        let name = metric.displayName
        if abs(delta) <= threshold {
            return TrendCallout(
                metric: metric,
                title: "Your \(name) has been \(steadyVerb)",
                detail: "Averaging about \(format(lastAvg, metric)) \(metric.unit) recently. Steady is good — keep tracking.",
                icon: "arrow.left.and.right"
            )
        } else if delta > 0 {
            return TrendCallout(
                metric: metric,
                title: "Your \(name) is \(upVerb)",
                detail: "Up about \(format(abs(delta), metric)) \(metric.unit) lately, now near \(format(lastAvg, metric)) \(metric.unit). Worth keeping an eye on the trend.",
                icon: "arrow.up.right"
            )
        } else {
            return TrendCallout(
                metric: metric,
                title: "Your \(name) is \(downVerb)",
                detail: "Down about \(format(abs(delta), metric)) \(metric.unit) lately, now near \(format(lastAvg, metric)) \(metric.unit). Keep tracking the trend.",
                icon: "arrow.down.right"
            )
        }
    }

    /// Distinct seek-care signals from recent readings (deduped by metric kind).
    private var seekCareSignals: [SeekCareItem] {
        var seenKinds: Set<MetricKind> = []
        var result: [SeekCareItem] = []
        // Look across recent readings (most recent first).
        let recent = allReadings.sorted { $0.timestamp > $1.timestamp }.prefix(30)
        for reading in recent {
            for metric in reading.metrics {
                guard !seenKinds.contains(metric.kind) else { continue }
                if let signal = ClinicalConfig.seekCareSignal(for: metric.kind, value: metric.value) {
                    seenKinds.insert(metric.kind)
                    result.append(SeekCareItem(kind: signal.kind, message: signal.message))
                }
            }
        }
        return result
    }

    // MARK: - Math helpers

    private func average(of kind: MetricKind, in readings: [CardioReading]) -> Double? {
        let values = readings.compactMap { $0.metric(kind)?.value }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Average of a metric across readings before today, for a baseline comparison.
    private func recentBaseline(of kind: MetricKind, excludingToday today: Date) -> Double? {
        let calendar = Calendar.current
        let prior = allReadings.filter { !calendar.isDate($0.timestamp, inSameDayAs: today) }
        return average(of: kind, in: prior)
    }

    private func format(_ value: Double, _ metric: MetricKind) -> String {
        value.formatted(.number.precision(.fractionLength(metric.fractionDigits)))
    }

    // MARK: - Loading

    private func load() async {
        async let readingsT = try? env.repository.allReadings()
        async let hrT = try? env.repository.timeSeries(metric: .heartRate, days: 30)
        async let hrvT = try? env.repository.timeSeries(metric: .hrvSDNN, days: 30)

        allReadings = (await readingsT) ?? []
        hrSeries = (await hrT) ?? []
        hrvSeries = (await hrvT) ?? []
        hasLoaded = true
    }
}

#Preview("Insights") {
    NavigationStack {
        InsightsView()
            .environment(AppEnvironment.preview())
    }
}
