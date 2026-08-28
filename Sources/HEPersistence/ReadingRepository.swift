import Foundation
import HECore

/// A single dated value in a metric trend series (for charts).
public struct TimeSeriesPoint: Sendable, Hashable, Codable, Identifiable {
    public let date: Date
    public let value: Double
    public var id: Date { date }

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// Storage abstraction for cardio readings and the user's health profile.
///
/// All access is `async` so concrete stores can be actors (encrypted on-disk,
/// in-memory for previews, etc.) without leaking isolation. Aggregation methods
/// (`dailyChecks`, `streak`, `todayScore`, `timeSeries`) are derived from the
/// stored readings via the shared ``ReadingAggregator`` so every implementation
/// behaves identically.
public protocol ReadingRepository: Sendable {
    func save(_ reading: CardioReading) async throws
    func allReadings() async throws -> [CardioReading]
    func readings(for modality: Modality?) async throws -> [CardioReading]
    func reading(id: UUID) async throws -> CardioReading?
    func delete(id: UUID) async throws
    func deleteAll() async throws

    func dailyChecks(days: Int) async throws -> [DailyCheck]
    func streak() async throws -> CheckStreak
    func todayScore() async throws -> CardioScore
    func timeSeries(metric: MetricKind, days: Int) async throws -> [TimeSeriesPoint]

    func loadProfile() async throws -> HealthProfile?
    func saveProfile(_ profile: HealthProfile) async throws
}

// MARK: - Shared aggregation

/// Pure, stateless aggregation over a `[CardioReading]`, shared by every
/// `ReadingRepository` implementation so trends, streaks and scores are computed
/// one way only.
///
/// All functions are deterministic and side-effect free; they read the clock /
/// calendar only via the injectable `now` / `calendar` parameters (defaulting to
/// the current values) which keeps them unit-testable.
public enum ReadingAggregator {

    // MARK: Daily checks (calendar heatmap)

    /// One ``DailyCheck`` per calendar day for the last `days` days (most recent
    /// first, including days with zero readings). `risk` is the *best* (lowest)
    /// risk observed that day, matching the heatmap-cell semantics.
    public static func dailyChecks(
        from readings: [CardioReading],
        days: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyCheck] {
        guard days > 0 else { return [] }
        let today = calendar.startOfDay(for: now)

        // Bucket readings by start-of-day.
        var byDay: [Date: [CardioReading]] = [:]
        for reading in readings {
            let day = calendar.startOfDay(for: reading.timestamp)
            byDay[day, default: []].append(reading)
        }

        var result: [DailyCheck] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayReadings = byDay[day] ?? []
            // Best (lowest) classifiable risk; `.min()` ignores nothing but treats
            // `.unknown` as lowest, so prefer a real risk when any exists.
            let bestRisk = bestRisk(in: dayReadings)
            result.append(
                DailyCheck(date: day, readingCount: dayReadings.count, risk: bestRisk)
            )
        }
        return result
    }

    /// The best (lowest) *classified* risk among a day's readings, falling back to
    /// `.unknown` when there are no readings or none could be classified.
    private static func bestRisk(in readings: [CardioReading]) -> RiskLevel {
        let classified = readings.map(\.overallRisk).filter { $0 != .unknown }
        return classified.min() ?? .unknown
    }

    // MARK: Streak

    /// Walks back day-by-day from today counting consecutive days with ≥1 reading
    /// for the current streak, plus the longest run anywhere in history.
    public static func streak(
        from readings: [CardioReading],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CheckStreak {
        guard !readings.isEmpty else { return .none }

        // Distinct days that have at least one reading.
        let checkedDays = Set(readings.map { calendar.startOfDay(for: $0.timestamp) })
        let today = calendar.startOfDay(for: now)
        let didCheckToday = checkedDays.contains(today)

        // Current streak: start at today if checked, else yesterday (a streak that
        // ran up to yesterday is still "current" until today lapses).
        var current = 0
        var cursor: Date? = didCheckToday
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)
        while let day = cursor, checkedDays.contains(day) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: day)
        }

        // Longest streak across all checked days.
        let longest = longestRun(of: checkedDays, calendar: calendar)

        return CheckStreak(
            currentStreak: current,
            longestStreak: max(longest, current),
            didCheckToday: didCheckToday
        )
    }

    /// Longest run of consecutive calendar days in `days`.
    private static func longestRun(of days: Set<Date>, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var longest = 1
        var run = 1
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let day = sorted[index]
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }

    // MARK: Today's score

    /// Composes a gentle, non-diagnostic 0–100 ``CardioScore`` from today's
    /// readings. Starts at 100 and applies small, bounded deductions for
    /// elevated/watch metrics and low confidence. Never alarmist.
    public static func todayScore(
        from readings: [CardioReading],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CardioScore {
        let today = calendar.startOfDay(for: now)
        let todays = readings.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        return score(for: todays)
    }

    /// Score logic factored out so it can be reused / tested directly on any set.
    public static func score(for readings: [CardioReading]) -> CardioScore {
        guard !readings.isEmpty else { return .empty }

        var score = 100.0
        var sawElevated = false
        var sawWatch = false
        var lowConfidenceCount = 0

        for reading in readings {
            // Deduct per-metric for softened risk, capped so a single noisy reading
            // can't tank the score.
            for metric in reading.visibleMetrics {
                switch metric.risk {
                case .elevated:
                    score -= 12
                    sawElevated = true
                case .watch:
                    score -= 5
                    sawWatch = true
                case .normal, .unknown:
                    break
                }
            }
            if reading.confidence.isLow {
                score -= 6
                lowConfidenceCount += 1
            }
        }

        let clamped = Int(min(max(score.rounded(), 0), 100))
        let band = riskBand(for: clamped, sawElevated: sawElevated, sawWatch: sawWatch)
        let headline = scoreHeadline(
            score: clamped,
            band: band,
            readingCount: readings.count,
            lowConfidenceCount: lowConfidenceCount
        )

        return CardioScore(
            value: clamped,
            risk: band,
            headline: headline,
            contributingReadings: readings.count
        )
    }

    /// Maps a numeric score + observed metric risks to a softened band. The
    /// presence of a genuinely elevated metric dominates a merely-high number.
    private static func riskBand(for score: Int, sawElevated: Bool, sawWatch: Bool) -> RiskLevel {
        if sawElevated { return .elevated }
        if sawWatch || score < 80 { return .watch }
        return .normal
    }

    private static func scoreHeadline(
        score: Int,
        band: RiskLevel,
        readingCount: Int,
        lowConfidenceCount: Int
    ) -> String {
        switch band {
        case .normal:
            return "Today's checks look typical. Nice work."
        case .watch:
            if lowConfidenceCount > 0 {
                return "A few readings were a little outside your typical range or low-confidence. Re-check when relaxed."
            }
            return "A few readings were a little outside your typical range. Keep tracking the trend."
        case .elevated:
            return "Some readings were outside your typical range today. This isn't a diagnosis — keep watching the trend over time."
        case .unknown:
            return "Take today's first check to see your score."
        }
    }

    // MARK: Time series

    /// All values of `metric` from the last `days` days, oldest → newest, suitable
    /// for a trend chart. Readings without that metric are skipped.
    public static func timeSeries(
        from readings: [CardioReading],
        metric: MetricKind,
        days: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TimeSeriesPoint] {
        guard days > 0 else { return [] }
        guard metric.isVisibleInDailyDil else { return [] }
        let today = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        return readings
            .filter { $0.timestamp >= cutoff }
            .compactMap { reading -> TimeSeriesPoint? in
                guard let value = reading.metric(metric)?.value else { return nil }
                return TimeSeriesPoint(date: reading.timestamp, value: value)
            }
            .sorted { $0.date < $1.date }
    }
}
