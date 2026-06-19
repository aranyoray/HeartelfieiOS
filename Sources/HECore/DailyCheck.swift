import Foundation

/// One calendar day's daily-check status, used by the streak indicator and the
/// Trends calendar heatmap.
public struct DailyCheck: Identifiable, Codable, Sendable, Hashable {
    /// Start-of-day date (the calendar day this record represents).
    public let date: Date
    /// How many readings were taken that day.
    public let readingCount: Int
    /// Best (lowest) risk observed that day, used to tint the heatmap cell.
    public let risk: RiskLevel

    public var id: Date { date }

    public init(date: Date, readingCount: Int, risk: RiskLevel) {
        self.date = date
        self.readingCount = readingCount
        self.risk = risk
    }

    public var didCheck: Bool { readingCount > 0 }
}

/// A computed daily-check streak summary for the Home dashboard.
public struct CheckStreak: Codable, Sendable, Hashable {
    public let currentStreak: Int
    public let longestStreak: Int
    public let didCheckToday: Bool

    public init(currentStreak: Int, longestStreak: Int, didCheckToday: Bool) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.didCheckToday = didCheckToday
    }

    public static let none = CheckStreak(currentStreak: 0, longestStreak: 0, didCheckToday: false)

    /// Gentle nudge copy based on streak state.
    public var nudge: String {
        if didCheckToday {
            return currentStreak > 1
                ? "Nice — that's \(currentStreak) days in a row."
                : "Today's check is done. See you tomorrow!"
        } else if currentStreak > 0 {
            return "Keep your \(currentStreak)-day streak going with a quick check."
        } else {
            return "A 30-second check is a great way to start."
        }
    }
}
