import Foundation
import UserNotifications

/// Schedules on-device daily reminders. No server, no account — purely local
/// `UNCalendarNotificationTrigger`s recomputed from the current goals.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let dailyNudgeID = "lifegrid-daily-nudge"

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Recompute every pending request from the current goals + global nudge.
    func sync(goals: [Goal], dailyReminder: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.autoupdatingCurrent
        for goal in goals where !goal.isArchived && goal.frequency == .daily {
            guard let time = goal.reminderTime else { continue }
            let comps = calendar.dateComponents([.hour, .minute], from: time)
            schedule(
                id: goal.reminderID,
                title: goal.title,
                body: goal.note.isEmpty ? String(localized: "Time for your habit") : goal.note,
                at: comps
            )
        }

        if let dailyReminder {
            let comps = calendar.dateComponents([.hour, .minute], from: dailyReminder)
            schedule(
                id: dailyNudgeID,
                title: "LifeGrid",
                body: String(localized: "Check in on your habits"),
                at: comps
            )
        }
    }

    /// Request permission if undetermined, then (re)schedule everything.
    func ensureAuthorizedThenSync(goals: [Goal], dailyReminder: Date?) async {
        if await authorizationStatus() == .notDetermined {
            await requestAuthorization()
        }
        sync(goals: goals, dailyReminder: dailyReminder)
    }

    private func schedule(id: String, title: String, body: String, at comps: DateComponents) {
        guard comps.hour != nil, comps.minute != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
