import Foundation
import SwiftUI
import HECore
import HEDesign
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Schedules the optional once-a-day "take your check" local notification.
/// Wellness-framed copy, no health data in the notification, and everything
/// stays on-device (local notifications only — no push, no server).
@MainActor
@Observable
public final class DailyReminderScheduler {
    private static let enabledKey = "he.reminder.enabled"
    private static let hourKey = "he.reminder.hour"
    private static let minuteKey = "he.reminder.minute"
    private static let requestID = "he.reminder.daily"

    public private(set) var isEnabled: Bool
    public private(set) var time: DateComponents
    /// True when the user enabled reminders but iOS notification permission
    /// was denied — the UI points them at Settings.
    public private(set) var permissionDenied = false

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        var components = DateComponents()
        components.hour = defaults.object(forKey: Self.hourKey) as? Int ?? 9
        components.minute = defaults.object(forKey: Self.minuteKey) as? Int ?? 0
        self.time = components
    }

    public var timeAsDate: Date {
        Calendar.current.date(from: time) ?? Date()
    }

    public func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        if enabled {
            await requestAndSchedule()
        } else {
            cancel()
        }
    }

    public func setTime(_ date: Date) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        time = components
        defaults.set(components.hour ?? 9, forKey: Self.hourKey)
        defaults.set(components.minute ?? 0, forKey: Self.minuteKey)
        if isEnabled {
            await requestAndSchedule()
        }
    }

    private func requestAndSchedule() async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        permissionDenied = !granted
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for today's check"
        content.body = "A calm minute with \(HeartelfieConfig.appName) keeps your wellness trend honest."
        content.sound = .default

        var trigger = DateComponents()
        trigger.hour = time.hour
        trigger.minute = time.minute
        let request = UNNotificationRequest(
            identifier: Self.requestID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
        try? await center.add(request)
        #endif
    }

    private func cancel() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.requestID])
        #endif
    }
}

/// The Profile-screen section for the daily reminder.
struct DailyReminderSection: View {
    @State private var scheduler = DailyReminderScheduler()
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { scheduler.isEnabled },
                set: { newValue in Task { await scheduler.setEnabled(newValue) } }
            )) {
                Label("Remind me to check in", systemImage: "bell.badge")
            }
            .tint(Color.hePrimary)

            if scheduler.isEnabled {
                DatePicker(
                    "Reminder time",
                    selection: Binding(
                        get: { scheduler.timeAsDate },
                        set: { newValue in Task { await scheduler.setTime(newValue) } }
                    ),
                    displayedComponents: .hourAndMinute
                )

                if scheduler.permissionDenied {
                    VStack(alignment: .leading, spacing: HESpacing.xs) {
                        Text("Notifications are off for \(HeartelfieConfig.appName) in iOS Settings, so the reminder can't be delivered.")
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextSecondary)
                        Button("Open Settings") {
                            if let url = URL(string: "app-settings:") {
                                openURL(url)
                            }
                        }
                        .font(.heCaption.weight(.semibold))
                        .foregroundStyle(Color.hePrimary)
                    }
                }
            }
        } header: {
            Text("Daily reminder")
        } footer: {
            Text("A gentle local nudge, scheduled on this device. The notification never includes your results.")
        }
    }
}
