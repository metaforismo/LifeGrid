import Foundation
import UserNotifications

/// Schedules on-device daily reminders and handles their actions. No server,
/// no account — purely local `UNCalendarNotificationTrigger`s recomputed from
/// the current goals, with a "Mark done" action handled by the delegate.
@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private override init() { super.init() }

    private let dailyNudgeID = "lifegrid-daily-nudge"
    private nonisolated static let goalReminderPrefix = "goal-reminder-"
    nonisolated static let completeActionID = "COMPLETE_HABIT"
    nonisolated static let goalCategoryID = "HABIT_REMINDER"

    /// Called when the user taps "Mark done" on a habit reminder.
    private var onComplete: ((UUID) -> Void)?

    /// Register the delegate + action category and wire the completion handler.
    /// Call once at launch.
    func configure(onComplete: @escaping (UUID) -> Void) {
        self.onComplete = onComplete
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let done = UNNotificationAction(
            identifier: Self.completeActionID,
            title: String(localized: "Mark done"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.goalCategoryID,
            actions: [done],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

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
            let hm = calendar.dateComponents([.hour, .minute], from: time)
            let body = goal.note.isEmpty ? String(localized: "Time for your habit") : goal.note
            if goal.isEveryDay {
                schedule(id: goal.reminderID, title: goal.title, body: body, at: hm, category: Self.goalCategoryID)
            } else {
                for weekday in goal.weekdays ?? [] {
                    var comps = hm
                    comps.weekday = weekday
                    schedule(id: "\(goal.reminderID)__\(weekday)", title: goal.title, body: body, at: comps, category: Self.goalCategoryID)
                }
            }
        }

        if let dailyReminder {
            let comps = calendar.dateComponents([.hour, .minute], from: dailyReminder)
            schedule(
                id: dailyNudgeID,
                title: "LifeGrid",
                body: String(localized: "Check in on your habits"),
                at: comps,
                category: nil
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

    private func schedule(id: String, title: String, body: String, at comps: DateComponents, category: String?) {
        guard comps.hour != nil, comps.minute != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category { content.categoryIdentifier = category }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated static func goalID(fromReminderID id: String) -> UUID? {
        guard id.hasPrefix(goalReminderPrefix) else { return nil }
        // A reminder id is "goal-reminder-<uuid>" optionally suffixed with
        // "__<weekday>" for weekly schedules. The UUID is the first 36 chars.
        let remainder = id.dropFirst(goalReminderPrefix.count)
        return UUID(uuidString: String(remainder.prefix(36)))
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == Self.completeActionID,
           let id = Self.goalID(fromReminderID: response.notification.request.identifier) {
            Task { @MainActor in self.onComplete?(id) }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
