import Foundation

/// Read-side helpers shared between the app and the widget extension. The data
/// lives in an App Group container so the widget can read what the app writes.
enum SharedStore {
    static let appGroupID = "group.com.codex.LifeGrid"
    private static let fileName = "lifegrid-store.json"

    /// The shared App Group store URL, falling back to the app's Documents
    /// directory when the group container isn't available.
    static var storageURL: URL {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return container.appendingPathComponent(fileName)
        }
        return legacyDocumentsURL
    }

    static var legacyDocumentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    static func loadSnapshot() -> AppSnapshot? {
        guard let data = try? Data(contentsOf: storageURL) else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }
}

/// A small, read-only summary of "today" computed from a snapshot. Used by the
/// widget so it doesn't need the full `AppStore`.
struct TodaySummary {
    var completed: Int
    var total: Int
    var accent: AccentChoice
    /// Completion counts per day for the last `dayCount` days (oldest first).
    var heatCounts: [Int]

    var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    static func make(from snapshot: AppSnapshot?, now: Date = .now, heatDays: Int = 49) -> TodaySummary {
        guard let snapshot else {
            return TodaySummary(completed: 0, total: 0, accent: .purple, heatCounts: Array(repeating: 0, count: heatDays))
        }
        var calendar = Calendar.autoupdatingCurrent
        if (1 ... 7).contains(snapshot.settings.firstWeekday) {
            calendar.firstWeekday = snapshot.settings.firstWeekday
        }
        let todayKey = DateKey(now, calendar: calendar)
        let weekday = calendar.component(.weekday, from: now)
        let daily = snapshot.goals.filter {
            $0.frequency == .daily && !$0.isArchived && $0.startsOn <= todayKey && $0.isScheduled(onWeekday: weekday)
        }
        let completed = daily.filter { goal in
            snapshot.logs.contains { $0.goalID == goal.id && $0.date == todayKey && $0.completedAt != nil }
        }.count

        let start = calendar.startOfDay(for: now)
        let counts: [Int] = (0 ..< heatDays).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            let key = DateKey(date, calendar: calendar)
            let logCount = snapshot.logs.filter { $0.date == key && $0.completedAt != nil }.count
            let planCount = snapshot.plans.filter { !$0.isArchived && $0.completedDays.contains(key) }.count
            return logCount + planCount
        }

        return TodaySummary(completed: completed, total: daily.count, accent: snapshot.settings.accent, heatCounts: counts)
    }
}
