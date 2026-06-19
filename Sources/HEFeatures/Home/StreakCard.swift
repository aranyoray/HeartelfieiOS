import SwiftUI
import HECore
import HEDesign

/// The daily-check streak card for Home: current and longest streak, a gentle
/// non-diagnostic nudge, and a 7-day mini row showing which of the last seven
/// days had a check (derived from recent reading timestamps).
struct StreakCard: View {
    let streak: CheckStreak
    /// Recent readings, used only to light up the 7-day mini row.
    let recentReadings: [CardioReading]

    private let calendar = Calendar.current

    /// The last seven calendar days, oldest → today.
    private var lastSevenDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    /// Start-of-day dates that have at least one reading.
    private var checkedDays: Set<Date> {
        Set(recentReadings.map { calendar.startOfDay(for: $0.timestamp) })
    }

    var body: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: HESpacing.sm) {
                    Image(systemName: "flame.fill")
                        .font(.heTitle)
                        .foregroundStyle(streak.currentStreak > 0 ? Color.heAccent : Color.heTextTertiary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: HESpacing.xxs) {
                        Text(currentStreakText)
                            .font(.heTitle)
                            .foregroundStyle(Color.heTextPrimary)
                        Text("Longest: \(streak.longestStreak) \(streak.longestStreak == 1 ? "day" : "days")")
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextSecondary)
                    }

                    Spacer(minLength: 0)

                    if streak.didCheckToday {
                        Label("Today done", systemImage: "checkmark.circle.fill")
                            .font(.heCaption.weight(.semibold))
                            .foregroundStyle(Color.heRisk(.normal))
                            .labelStyle(.titleAndIcon)
                    }
                }

                miniWeekRow

                Text(streak.nudge)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var currentStreakText: String {
        if streak.currentStreak == 0 {
            return "No active streak"
        }
        return "\(streak.currentStreak)-day streak"
    }

    private var miniWeekRow: some View {
        HStack(spacing: HESpacing.sm) {
            ForEach(lastSevenDays, id: \.self) { day in
                let didCheck = checkedDays.contains(day)
                VStack(spacing: HESpacing.xs) {
                    Circle()
                        .fill(didCheck ? Color.hePrimary : Color.heSeparator)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(didCheck ? 1 : 0)
                        )
                    Text(weekdayInitial(for: day))
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func weekdayInitial(for date: Date) -> String {
        // Narrow weekday glyph (e.g. "M") via the localized format style — avoids
        // any reliance on calendar/formatter symbol arrays.
        date.formatted(.dateTime.weekday(.narrow))
    }

    private var accessibilityLabel: String {
        let checkedCount = lastSevenDays.filter { checkedDays.contains($0) }.count
        return "\(currentStreakText). Longest streak \(streak.longestStreak) days. "
            + "\(checkedCount) of the last 7 days checked. \(streak.nudge)"
    }
}

#Preview("Streak card") {
    ScrollView {
        VStack(spacing: HESpacing.lg) {
            StreakCard(
                streak: CheckStreak(currentStreak: 4, longestStreak: 11, didCheckToday: true),
                recentReadings: SampleData.history(days: 7)
            )
            StreakCard(
                streak: .none,
                recentReadings: []
            )
        }
        .padding()
    }
    .background(Color.heBackground)
}
