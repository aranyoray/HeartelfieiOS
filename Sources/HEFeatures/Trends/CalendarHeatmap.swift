import SwiftUI
import HECore
import HEDesign
import HEPersistence

/// A GitHub-style calendar heatmap of daily checks over the last several weeks.
///
/// Each cell represents one calendar day. Days with at least one reading are
/// tinted by the day's best (lowest) softened risk (`Color.heRisk`), with opacity
/// scaled by how many checks were taken (density). Days with no checks render as a
/// faint, empty cell. Status is never color-only: every cell carries a full
/// VoiceOver label spelling out the date, check count, and status, and the legend
/// pairs each color with its label.
struct CalendarHeatmap: View {
    /// Daily checks, most-recent-first (as returned by the repository). Internally
    /// re-ordered oldest → newest so the grid reads left→right, top→bottom.
    let checks: [DailyCheck]

    /// Number of week columns to render.
    private let weekCount: Int

    init(checks: [DailyCheck], weeks: Int = 7) {
        self.checks = checks
        self.weekCount = weeks
    }

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 26
    private let cellSpacing: CGFloat = HESpacing.xs

    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            grid
            legend
        }
    }

    // MARK: - Grid

    private var grid: some View {
        // Columns are weeks; rows are weekdays (7). A LazyVGrid laid out by row
        // would interleave weeks, so we build explicit week columns in an HStack.
        let weeks = weekColumns
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week) { cell in
                            cellView(cell)
                        }
                    }
                }
            }
            .padding(.vertical, HESpacing.xxs)
        }
        .accessibilityLabel("Daily check calendar, last \(weekCount) weeks")
    }

    @ViewBuilder
    private func cellView(_ cell: HeatmapCell) -> some View {
        switch cell {
        case .day(let check):
            RoundedRectangle(cornerRadius: HERadius.sm, style: .continuous)
                .fill(fill(for: check))
                .overlay(
                    RoundedRectangle(cornerRadius: HERadius.sm, style: .continuous)
                        .strokeBorder(Color.heSeparator.opacity(0.6), lineWidth: check.didCheck ? 0 : 1)
                )
                .frame(width: cellSize, height: cellSize)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(for: check))
        case .placeholder:
            // Keeps the weekday rows aligned for partial leading/trailing weeks.
            Color.clear
                .frame(width: cellSize, height: cellSize)
                .accessibilityHidden(true)
        }
    }

    /// A day's fill: empty cells stay faint; checked cells use the risk color with
    /// opacity scaled by check density so busier days read as more saturated.
    private func fill(for check: DailyCheck) -> Color {
        guard check.didCheck else { return Color.heSeparator.opacity(0.25) }
        let density = min(Double(check.readingCount), 4) / 4.0     // 0...1
        let opacity = 0.45 + density * 0.55                         // 0.45...1.0
        return Color.heRisk(check.risk).opacity(opacity)
    }

    private func label(for check: DailyCheck) -> String {
        let dateString = check.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        guard check.didCheck else {
            return "\(dateString): no checks."
        }
        let countString = check.readingCount == 1 ? "1 check" : "\(check.readingCount) checks"
        return "\(dateString): \(countString), status \(check.risk.displayName)."
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: HESpacing.xs) {
            HStack(spacing: HESpacing.md) {
                legendSwatch(color: Color.heSeparator.opacity(0.25), label: "No check")
                ForEach([RiskLevel.normal, .watch, .elevated], id: \.self) { risk in
                    legendSwatch(color: Color.heRisk(risk), label: risk.displayName)
                }
            }
            Text("Darker cells mean more checks that day.")
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legend. Cells are tinted by the day's best status: typical, keep an eye on, or worth a check. Darker cells mean more checks that day.")
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: HESpacing.xs) {
            RoundedRectangle(cornerRadius: HERadius.sm, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
        }
    }

    // MARK: - Layout model

    private enum HeatmapCell: Identifiable {
        case day(DailyCheck)
        case placeholder(Int)

        var id: String {
            switch self {
            case .day(let check): return "d-\(check.id.timeIntervalSinceReferenceDate)"
            case .placeholder(let index): return "p-\(index)"
            }
        }
    }

    /// Builds week columns (each a 7-row weekday array) from the most-recent
    /// `weekCount * 7` days, oldest → newest, padding the first/last partial week
    /// so weekday rows stay aligned.
    private var weekColumns: [[HeatmapCell]] {
        let wanted = weekCount * 7
        // checks are newest-first; take what we need and flip to oldest-first.
        let recent = Array(checks.prefix(wanted)).reversed().map { $0 }
        guard let firstDay = recent.first?.date else { return [] }

        // Pad the front so the first column starts on the week's first weekday.
        let firstWeekday = calendar.component(.weekday, from: firstDay)         // 1...7
        let leadingPad = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [HeatmapCell] = []
        var placeholderIndex = 0
        for _ in 0..<leadingPad {
            cells.append(.placeholder(placeholderIndex))
            placeholderIndex += 1
        }
        cells.append(contentsOf: recent.map { HeatmapCell.day($0) })
        // Pad the tail to complete the final week column.
        while cells.count % 7 != 0 {
            cells.append(.placeholder(placeholderIndex))
            placeholderIndex += 1
        }

        return stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<min(start + 7, cells.count)])
        }
    }
}

#Preview("Calendar heatmap") {
    let checks = ReadingAggregator.dailyChecks(
        from: SampleData.history(days: 40),
        days: 49
    )
    return ScrollView {
        HECard {
            CalendarHeatmap(checks: checks)
        }
        .padding()
    }
    .background(Color.heBackground)
}
