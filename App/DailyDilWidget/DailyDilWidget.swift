import WidgetKit
import SwiftUI

// Self-contained widget: reads a tiny non-sensitive rollup (score, streak)
// that the app writes to the shared app-group container. No health metrics,
// no readings — just the wellness score and streak the Home hero already shows.

private let appGroupID = "group.com.heartelfie.ios"

struct DashboardSnapshot: Codable {
    var score: Int
    var hasData: Bool
    var streakDays: Int
    var checkedToday: Bool
    var updated: Date

    static let placeholder = DashboardSnapshot(
        score: 82, hasData: true, streakDays: 3, checkedToday: true, updated: .now
    )

    static func load() -> DashboardSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: "he.widget.snapshot") else { return nil }
        return try? JSONDecoder().decode(DashboardSnapshot.self, from: data)
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: DashboardSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: DashboardSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: DashboardSnapshot.load())
        // The app refreshes the snapshot on every dashboard load; an hourly
        // timeline keeps "checked today" from going stale across midnight.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// Brand colors, mirrored from HEDesign (widget stays dependency-free).
private let heTeal = Color(red: 0x1E / 255, green: 0x6E / 255, blue: 0x78 / 255)
private let heTealDeep = Color(red: 0x14 / 255, green: 0x4B / 255, blue: 0x52 / 255)
private let heGradient = LinearGradient(
    colors: [heTeal, heTealDeep], startPoint: .topLeading, endPoint: .bottomTrailing
)

struct DailyDilWidgetView: View {
    var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) { heGradient }
            .widgetURL(URL(string: "dailydil://check"))
    }

    @ViewBuilder
    private var content: some View {
        let snap = entry.snapshot
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                Text("DailyDil")
                    .font(.caption2.weight(.semibold))
                Spacer()
                if let snap, snap.streakDays > 0 {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(snap.streakDays)")
                        .font(.caption2.weight(.bold))
                }
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            if let snap, snap.hasData, snap.checkedToday {
                Text("\(snap.score)")
                    .font(.system(size: family == .systemSmall ? 40 : 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("today's wellness score")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text("Take today's check")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                if family != .systemSmall {
                    Text("A calm minute keeps your trend honest.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}

struct DailyDilWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyDilWidget", provider: SnapshotProvider()) { entry in
            DailyDilWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily check")
        .description("Your streak and today's wellness score. Not a medical device.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DailyDilWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyDilWidget()
    }
}
