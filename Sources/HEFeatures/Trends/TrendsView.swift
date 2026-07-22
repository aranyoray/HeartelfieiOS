import SwiftUI
import Charts
import HECore
import HEDesign
import HEPersistence

/// The Trends screen: a metric trend chart with its reference band, a calendar
/// heatmap of daily checks, a filterable history list, and range export.
///
/// All copy is wellness-grade and explicitly non-diagnostic. Charts carry an
/// accessible value summary (`accessibilityChartDescriptor` is unavailable on a
/// `Chart` directly, so we add an audio-graph-friendly `AXChartDescriptor`-style
/// per-mark label plus a spoken summary element) so the data is never color-only.
struct TrendsView: View {
    @Environment(AppEnvironment.self) private var env

    // MARK: Selection state
    @State private var selectedMetric: MetricKind = .heartRate
    @State private var range: TrendRange = .month
    @State private var modalityFilter: ModalityFilter = .all
    @State private var tierFilter: TierFilter = .all

    // MARK: Loaded data
    @State private var series: [TimeSeriesPoint] = []
    @State private var allReadings: [CardioReading] = []
    @State private var checks: [DailyCheck] = []
    @State private var availableMetrics: [MetricKind] = TrendsView.baseMetrics
    @State private var isLoading = false

    // MARK: Export
    @State private var exportDocs: ExportDocuments?
    @State private var isPreparingExport = false

    init() {}

    /// The default metric set; device-only metrics are appended when present in data.
    private static let baseMetrics: [MetricKind] = [
        .heartRate, .hrvSDNN, .spo2Estimate, .respiratoryRate
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                trendSection
                heatmapSection
                historySection
                NonDiagnosticFooter()
                EmergencyNotice()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { exportToolbarItem }
        .task { await loadAll() }
        .refreshable { await loadAll() }
        .onChange(of: selectedMetric) { _, _ in Task { await loadSeries() } }
        .onChange(of: range) { _, _ in Task { await loadSeries() } }
    }

    // MARK: - Trend chart section

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Metric trends",
                subtitle: "How a metric has moved over time. Screenings, not measurements.",
                systemImage: "chart.xyaxis.line"
            )

            metricPicker
            rangePicker

            NavigationLink(value: AppRoute.metricTrend(selectedMetric)) {
                HECard {
                    VStack(alignment: .leading, spacing: HESpacing.sm) {
                        chartHeader
                        chartBody
                            .frame(height: 220)
                        chartFootnote
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(chartAccessibilitySummary)
            .accessibilityHint("Opens the full \(selectedMetric.displayName) trend.")
            .accessibilityAddTraits(.isButton)
        }
    }

    private var metricPicker: some View {
        Picker("Metric", selection: $selectedMetric) {
            ForEach(availableMetrics) { metric in
                Text(metric.shortName).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Metric")
    }

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(TrendRange.allCases) { r in
                Text(r.title).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Time range")
    }

    private var chartHeader: some View {
        HStack(spacing: HESpacing.sm) {
            Image(systemName: selectedMetric.systemImage)
                .font(.heHeadline)
                .foregroundStyle(Color.hePrimary)
                .accessibilityHidden(true)
            Text(selectedMetric.displayName)
                .font(.heHeadline)
                .foregroundStyle(Color.heTextPrimary)
            Spacer(minLength: 0)
            if let last = series.last {
                Text(formatted(last.value))
                    .font(.heHeadline)
                    .monospacedDigit()
                    .foregroundStyle(Color.heTextPrimary)
                Text(selectedMetric.unit)
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
            }
        }
    }

    @ViewBuilder
    private var chartBody: some View {
        if series.isEmpty {
            emptyChart
        } else {
            Chart {
                // Reference band (typical range), drawn behind the data.
                if let refRange = referenceRange {
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
                        y: .value(selectedMetric.shortName, point.value)
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
                        y: .value(selectedMetric.shortName, point.value)
                    )
                    .foregroundStyle(Color.hePrimary)
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)
                    .symbolSize(28)
                    // Per-point accessible value so VoiceOver / Audio Graphs can read it.
                    .accessibilityLabel(point.date.formatted(.dateTime.month().day()))
                    .accessibilityValue("\(formatted(point.value)) \(selectedMetric.unit)")
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
    }

    private var emptyChart: some View {
        VStack(spacing: HESpacing.sm) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(Color.heTextTertiary)
                .accessibilityHidden(true)
            Text("No \(selectedMetric.displayName) data in this range.")
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var chartFootnote: some View {
        if let refRange = referenceRange {
            Label("Shaded band shows the typical range: \(refRange.displayString).", systemImage: "rectangle.dashed")
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
        }
    }

    // MARK: - Heatmap section

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Daily checks",
                subtitle: "Your check-in consistency over the last several weeks.",
                systemImage: "calendar"
            )
            HECard {
                if checks.allSatisfy({ !$0.didCheck }) {
                    Text("No daily checks recorded yet. Take a quick screening to start building your calendar.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    CalendarHeatmap(checks: checks, weeks: 7)
                }
            }
        }
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "History",
                subtitle: "All your readings, newest first.",
                systemImage: "clock.arrow.circlepath"
            )

            filterControls

            if anomalyCount > 0 {
                anomalyCallout
            }

            if filteredReadings.isEmpty {
                HECard {
                    EmptyStateView(
                        systemImage: "line.3.horizontal.decrease.circle",
                        title: "Nothing to show",
                        message: filtersAreActive
                            ? "No readings match these filters. Try widening them."
                            : "Your readings will appear here once you take a check."
                    )
                }
            } else {
                historyList
            }
        }
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            Menu {
                Picker("Modality", selection: $modalityFilter) {
                    Text(ModalityFilter.all.title).tag(ModalityFilter.all)
                    ForEach(presentModalities, id: \.self) { modality in
                        Text(modality.displayName).tag(ModalityFilter.modality(modality))
                    }
                }
            } label: {
                filterLabel(systemImage: "waveform.path.ecg", text: modalityFilter.title)
            }
            .accessibilityLabel("Filter by modality, currently \(modalityFilter.title)")

            Picker("Tier", selection: $tierFilter) {
                ForEach(TierFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Filter by tier")
        }
    }

    private func filterLabel(systemImage: String, text: String) -> some View {
        HStack(spacing: HESpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.hePrimary)
                .accessibilityHidden(true)
            Text(text)
                .font(.heCallout.weight(.medium))
                .foregroundStyle(Color.heTextPrimary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, HESpacing.sm)
        .padding(.horizontal, HESpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HERadius.md, style: .continuous)
                .fill(Color.heSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.md, style: .continuous)
                .strokeBorder(Color.heSeparator, lineWidth: 1)
        )
    }

    private var anomalyCallout: some View {
        HStack(alignment: .top, spacing: HESpacing.sm) {
            Image(systemName: "flag.fill")
                .foregroundStyle(Color.heRisk(.elevated))
                .accessibilityHidden(true)
            Text("\(anomalyCount) \(anomalyCount == 1 ? "reading is" : "readings are") flagged as worth a check. This isn't a diagnosis — keep watching the trend over time.")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
        }
        .padding(HESpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.heRiskSoft(.elevated), in: RoundedRectangle(cornerRadius: HERadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            ForEach(groupedHistory, id: \.day) { group in
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Text(group.day, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.heCallout.weight(.semibold))
                        .foregroundStyle(Color.heTextSecondary)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(group.readings) { reading in
                        TrendsHistoryRow(reading: reading, isAnomaly: reading.overallRisk == .elevated)
                    }
                }
            }
        }
    }

    // MARK: - Export toolbar

    private var exportToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Task { await prepareExport(.csv) }
                } label: {
                    Label("Export CSV", systemImage: "tablecells")
                }
                Button {
                    Task { await prepareExport(.pdf) }
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext")
                }
            } label: {
                if isPreparingExport {
                    ProgressView()
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .disabled(filteredReadings.isEmpty || isPreparingExport)
            .accessibilityLabel("Export readings")
            // Present a ShareLink sheet once a temp file has been written.
            .sheet(item: $exportDocs) { docs in
                ExportShareSheet(documents: docs)
            }
        }
    }

    // MARK: - Derived data

    private var referenceRange: ClinicalRange? {
        ClinicalConfig.referenceRange(for: selectedMetric, profile: env.profile)
    }

    /// A padded Y domain so the line and the reference band both breathe.
    private var yDomain: ClosedRange<Double> {
        let values = series.map(\.value)
        var lo = values.min() ?? 0
        var hi = values.max() ?? 1
        if let ref = referenceRange {
            lo = min(lo, ref.low)
            hi = max(hi, ref.high)
        }
        if lo == hi { lo -= 1; hi += 1 }
        let pad = (hi - lo) * 0.12
        return (lo - pad)...(hi + pad)
    }

    /// Readings after applying the modality + tier filters.
    private var filteredReadings: [CardioReading] {
        allReadings.filter { reading in
            modalityFilter.matches(reading) && tierFilter.matches(reading)
        }
    }

    private var filtersAreActive: Bool {
        modalityFilter != .all || tierFilter != .all
    }

    private var anomalyCount: Int {
        filteredReadings.filter { $0.overallRisk == .elevated }.count
    }

    /// Distinct modalities actually present in the data (for the filter menu).
    private var presentModalities: [Modality] {
        var seen: [Modality] = []
        for reading in allReadings where !seen.contains(reading.modality) {
            seen.append(reading.modality)
        }
        return seen
    }

    private struct HistoryGroup { let day: Date; let readings: [CardioReading] }

    /// History grouped by calendar day, newest day first, newest reading first.
    private var groupedHistory: [HistoryGroup] {
        let calendar = Calendar.current
        let sorted = filteredReadings.sorted { $0.timestamp > $1.timestamp }
        var order: [Date] = []
        var buckets: [Date: [CardioReading]] = [:]
        for reading in sorted {
            let day = calendar.startOfDay(for: reading.timestamp)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(reading)
        }
        return order.map { HistoryGroup(day: $0, readings: buckets[$0] ?? []) }
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(selectedMetric.fractionDigits)))
    }

    private var chartAccessibilitySummary: String {
        guard !series.isEmpty else {
            return "\(selectedMetric.displayName) trend. No data in this range."
        }
        let values = series.map(\.value)
        let first = formatted(values.first ?? 0)
        let last = formatted(values.last ?? 0)
        let lo = formatted(values.min() ?? 0)
        let hi = formatted(values.max() ?? 0)
        var summary = "\(selectedMetric.displayName) trend over \(range.title), \(series.count) points. "
        summary += "From \(first) to \(last) \(selectedMetric.unit). Range \(lo) to \(hi). "
        if let ref = referenceRange {
            summary += "Typical range \(ref.displayString)."
        }
        return summary
    }

    // MARK: - Loading

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        async let readingsT = try? env.repository.allReadings()
        async let checksT = try? env.repository.dailyChecks(days: 49)
        let readings = (await readingsT) ?? []
        let loadedChecks = (await checksT) ?? []

        allReadings = readings
        checks = loadedChecks
        availableMetrics = Self.metrics(in: readings)
        if !availableMetrics.contains(selectedMetric) {
            selectedMetric = availableMetrics.first ?? .heartRate
        }
        await loadSeries()
    }

    private func loadSeries() async {
        let loaded = (try? await env.repository.timeSeries(metric: selectedMetric, days: range.days)) ?? []
        series = loaded
    }

    /// Base metrics plus any device metrics that actually appear in the data.
    private static func metrics(in readings: [CardioReading]) -> [MetricKind] {
        var result = baseMetrics
        let present = Set(readings.flatMap { $0.metrics.map(\.kind) })
        for kind in present where kind.isDeviceOnly && !result.contains(kind) {
            result.append(kind)
        }
        // Only keep metrics we actually have data for, but always keep heart rate.
        return result.filter { $0 == .heartRate || present.contains($0) }
    }

    // MARK: - Export building

    private func prepareExport(_ format: ExportFormat) async {
        isPreparingExport = true
        defer { isPreparingExport = false }
        let readings = filteredReadings
        guard !readings.isEmpty else { return }
        let exporter = env.exporter
        let profile = env.profile
        let stamp = Self.fileStamp()

        let url: URL? = await Task.detached(priority: .userInitiated) {
            let dir = FileManager.default.temporaryDirectory
            switch format {
            case .csv:
                let target = dir.appendingPathComponent("Heartelfie-Trends-\(stamp).csv")
                try? exporter.writeCSV(readings, to: target)
                return FileManager.default.fileExists(atPath: target.path) ? target : nil
            case .pdf:
                let target = dir.appendingPathComponent("Heartelfie-Trends-\(stamp).pdf")
                try? exporter.writePDF(readings, profile: profile, to: target)
                return FileManager.default.fileExists(atPath: target.path) ? target : nil
            }
        }.value

        if let url {
            exportDocs = ExportDocuments(url: url, format: format)
        }
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Supporting types

/// The selectable trend ranges.
private enum TrendRange: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90
    var id: Int { rawValue }
    var days: Int { rawValue }
    var title: String {
        switch self {
        case .week: return "7d"
        case .month: return "30d"
        case .quarter: return "90d"
        }
    }
}

/// Modality history filter (all, or a specific modality).
private enum ModalityFilter: Hashable {
    case all
    case modality(Modality)

    func matches(_ reading: CardioReading) -> Bool {
        switch self {
        case .all: return true
        case .modality(let m): return reading.modality == m
        }
    }

    var title: String {
        switch self {
        case .all: return "All sources"
        case .modality(let m): return m.displayName
        }
    }
}

/// Tier history filter.
private enum TierFilter: String, CaseIterable, Identifiable {
    case all, screening, measurement
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .screening: return "Screening"
        case .measurement: return "Measurement"
        }
    }
    func matches(_ reading: CardioReading) -> Bool {
        switch self {
        case .all: return true
        case .screening: return reading.tier == .screening
        case .measurement: return reading.tier == .measurement
        }
    }
}

enum ExportFormat: Sendable { case csv, pdf }

/// Identifiable wrapper so a written temp-file URL can drive a `.sheet(item:)`.
struct ExportDocuments: Identifiable {
    let id = UUID()
    let url: URL
    let format: ExportFormat
}

/// A small sheet wrapping a `ShareLink` for an already-written export file.
struct ExportShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let documents: ExportDocuments

    var body: some View {
        VStack(spacing: HESpacing.lg) {
            Image(systemName: documents.format == .csv ? "tablecells" : "doc.richtext")
                .font(.system(size: 44))
                .foregroundStyle(Color.hePrimary)
                .accessibilityHidden(true)

            VStack(spacing: HESpacing.xs) {
                Text("Your export is ready")
                    .font(.heTitle)
                    .foregroundStyle(Color.heTextPrimary)
                Text("This file carries the non-diagnostic disclaimer. Save it for your records or share it outside Heartelfie if you choose.")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .multilineTextAlignment(.center)
            }

            ShareLink(item: documents.url) {
                Label("Share \(documents.format == .csv ? "CSV" : "PDF")", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Done") { dismiss() }
                .font(.heCallout)
                .foregroundStyle(Color.hePrimary)
        }
        .padding(HESpacing.xl)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color.heBackground)
        .presentationDetents([.medium])
    }
}

// MARK: - History row

/// A history row that mirrors the Home recent-reading row but adds an anomaly flag
/// and pushes the reading detail.
private struct TrendsHistoryRow: View {
    let reading: CardioReading
    let isAnomaly: Bool

    var body: some View {
        NavigationLink(value: AppRoute.readingDetail(reading)) {
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
                            Text(reading.timestamp, format: .dateTime.hour().minute())
                                .font(.heCaption)
                                .foregroundStyle(Color.heTextTertiary)
                            if isAnomaly {
                                Image(systemName: "flag.fill")
                                    .font(.heCaption)
                                    .foregroundStyle(Color.heRisk(.elevated))
                                    .accessibilityHidden(true)
                            }
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
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the full reading detail.")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts: [String] = [reading.modality.displayName]
        if let metric = reading.primaryMetric {
            parts.append("\(metric.kind.displayName) \(metric.formattedValueWithUnit)")
        }
        parts.append(reading.tier.displayName)
        parts.append("Status: \(reading.overallRisk.displayName)")
        if isAnomaly { parts.append("Flagged as worth a check") }
        parts.append(reading.timestamp.formatted(.dateTime.hour().minute()))
        return parts.joined(separator: ", ")
    }
}

#Preview("Trends") {
    NavigationStack {
        TrendsView()
            .environment(AppEnvironment.preview())
    }
}
