import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {
    var goals: [Goal] = []
    var logs: [GoalLog] = []
    var plans: [LifePlan] = []
    var journal: [JournalEntry] = []
    var hasCompletedOnboarding = false
    var settings = AppSettings()

    @ObservationIgnored private let storageURL: URL

    /// Calendar used for all date math and UI grouping. Applies the user's
    /// chosen first-day-of-week when set (0 = follow system).
    var calendar: Calendar {
        var c = Calendar.autoupdatingCurrent
        if (1 ... 7).contains(settings.firstWeekday) {
            c.firstWeekday = settings.firstWeekday
        }
        return c
    }

    /// The current primary accent color (user-selectable in Settings).
    var accent: Color { settings.accent.color }

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lifegrid-store.json")
        load()
        Haptics.enabled = settings.hapticsEnabled
    }

    func dailyGoals(on date: Date = .now, includeArchived: Bool = false) -> [Goal] {
        let key = DateKey(date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: date)
        return goals
            .filter { $0.frequency == .daily }
            .filter { includeArchived || !$0.isArchived }
            .filter { $0.startsOn <= key }
            .filter { $0.isScheduled(onWeekday: weekday) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func onceGoals(includeArchived: Bool = false) -> [Goal] {
        goals
            .filter { $0.frequency == .once }
            .filter { includeArchived || !$0.isArchived }
            .sorted { lhs, rhs in
                switch (lhs.dueOn, rhs.dueOn) {
                case let (.some(left), .some(right)): left < right
                case (.some, .none): true
                case (.none, .some): false
                case (.none, .none): lhs.createdAt < rhs.createdAt
                }
            }
    }

    func addGoal(
        title: String,
        note: String,
        frequency: GoalFrequency,
        activity: ActivityKind,
        startsOn: Date,
        dueOn: Date?,
        targetValue: Double,
        unit: String,
        reminderTime: Date? = nil,
        weekdays: Set<Int>? = nil
    ) {
        let goal = Goal(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            activity: activity,
            createdAt: .now,
            startsOn: DateKey(startsOn, calendar: calendar),
            dueOn: dueOn.map { DateKey($0, calendar: calendar) },
            targetValue: max(1, targetValue),
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            isArchived: false,
            reminderTime: reminderTime,
            weekdays: (weekdays?.isEmpty ?? true) ? nil : weekdays
        )
        goals.append(goal)
        save()
    }

    func addPlan(title: String, subtitle: String, startsOn: Date, dayCount: Int) {
        let plan = LifePlan(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            startsOn: DateKey(startsOn, calendar: calendar),
            dayCount: max(1, dayCount),
            completedDays: [],
            isArchived: false
        )
        plans.append(plan)
        save()
    }

    func updateGoal(_ goal: Goal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index] = goal
        save()
    }

    func archiveGoal(_ goal: Goal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index].isArchived.toggle()
        save()
    }

    func deleteGoal(_ goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        logs.removeAll { $0.goalID == goal.id }
        save()
    }

    func deletePlan(_ plan: LifePlan) {
        plans.removeAll { $0.id == plan.id }
        save()
    }

    func archivePlanToggle(_ plan: LifePlan) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[index].isArchived.toggle()
        save()
    }

    func deleteJournal(on date: Date = .now) {
        let key = DateKey(date, calendar: calendar)
        journal.removeAll { $0.date == key }
        save()
    }

    func log(for goal: Goal, on date: Date = .now) -> GoalLog? {
        let key = DateKey(date, calendar: calendar)
        return logs.first { $0.goalID == goal.id && $0.date == key }
    }

    func progressValue(for goal: Goal, on date: Date = .now) -> Double {
        log(for: goal, on: date)?.value ?? 0
    }

    func isComplete(_ goal: Goal, on date: Date = .now) -> Bool {
        if goal.frequency == .once {
            return logs.contains { $0.goalID == goal.id && $0.completedAt != nil }
        }
        return log(for: goal, on: date)?.isComplete ?? false
    }

    func setComplete(_ complete: Bool, goal: Goal, on date: Date = .now) {
        let key = DateKey(date, calendar: calendar)
        let value = complete ? goal.targetValue : 0
        upsertLog(goalID: goal.id, date: key, value: value, completedAt: complete ? .now : nil)
        save()
    }

    /// Mark a goal complete for today in response to a notification action.
    func markCompleteFromReminder(_ goalID: UUID) {
        guard let goal = goals.first(where: { $0.id == goalID }) else { return }
        setComplete(true, goal: goal, on: .now)
    }

    func setProgress(_ value: Double, goal: Goal, on date: Date = .now) {
        let key = goal.frequency == .daily ? DateKey(date, calendar: calendar) : DateKey(.now, calendar: calendar)
        let clamped = min(max(value, 0), goal.targetValue)
        upsertLog(goalID: goal.id, date: key, value: clamped, completedAt: clamped >= goal.targetValue ? .now : nil)
        save()
    }

    func activePlan() -> LifePlan? {
        plans.first { !$0.isArchived }
    }

    func togglePlanToday(_ plan: LifePlan, on date: Date = .now) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        let key = DateKey(date, calendar: calendar)
        if plans[index].completedDays.contains(key) {
            plans[index].completedDays.remove(key)
        } else {
            plans[index].completedDays.insert(key)
        }
        save()
    }

    func updateJournal(for date: Date = .now, mood: Int, text: String) {
        let key = DateKey(date, calendar: calendar)
        if let index = journal.firstIndex(where: { $0.date == key }) {
            journal[index].mood = mood
            journal[index].text = text
        } else {
            journal.append(JournalEntry(id: UUID(), date: key, mood: mood, text: text))
        }
        save()
    }

    func journalEntry(on date: Date = .now) -> JournalEntry? {
        let key = DateKey(date, calendar: calendar)
        return journal.first { $0.date == key }
    }

    func activityCount(on key: DateKey, activity: ActivityKind? = nil) -> Int {
        logs.filter { log in
            guard log.date == key, log.isComplete else { return false }
            if let activity, let goal = goals.first(where: { $0.id == log.goalID }) {
                return goal.activity == activity
            }
            return true
        }.count + plans.filter { !$0.isArchived && $0.completedDays.contains(key) && activity == nil }.count
    }

    func currentStreak(for goal: Goal, ending date: Date = .now) -> Int {
        guard goal.frequency == .daily else { return isComplete(goal) ? 1 : 0 }
        var streak = 0
        var cursor = date
        var isFirstScheduled = true
        // Walk back day by day, only counting scheduled days. A scheduled-but-
        // incomplete day breaks the streak, except today (still in progress).
        for _ in 0 ..< 400 {
            let weekday = calendar.component(.weekday, from: cursor)
            if goal.isScheduled(onWeekday: weekday) {
                if isComplete(goal, on: cursor) {
                    streak += 1
                } else if isFirstScheduled, calendar.isDateInToday(cursor) {
                    // today not checked off yet — don't count, don't break
                } else {
                    break
                }
                isFirstScheduled = false
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    func completedDailyCount(on date: Date = .now) -> Int {
        dailyGoals(on: date).filter { isComplete($0, on: date) }.count
    }

    private func upsertLog(goalID: UUID, date: DateKey, value: Double, completedAt: Date?) {
        if let index = logs.firstIndex(where: { $0.goalID == goalID && $0.date == date }) {
            logs[index].value = value
            logs[index].completedAt = completedAt
        } else {
            logs.append(GoalLog(id: UUID(), goalID: goalID, date: date, value: value, completedAt: completedAt))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else {
            seed()
            return
        }
        do {
            let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: data)
            apply(snapshot)
        } catch {
            seed()
        }
    }

    private func apply(_ snapshot: AppSnapshot) {
        goals = snapshot.goals
        logs = snapshot.logs
        plans = snapshot.plans
        journal = snapshot.journal
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        settings = snapshot.settings
    }

    private func currentSnapshot() -> AppSnapshot {
        AppSnapshot(
            goals: goals,
            logs: logs,
            plans: plans,
            journal: journal,
            hasCompletedOnboarding: hasCompletedOnboarding,
            settings: settings
        )
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(currentSnapshot())
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            assertionFailure("Could not save LifeGrid data: \(error)")
        }
    }

    // MARK: - Settings

    /// Persist settings changes and propagate side effects (haptics flag).
    func persistSettings() {
        Haptics.enabled = settings.hapticsEnabled
        save()
    }

    // MARK: - Backup

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(currentSnapshot())
    }

    func importData(_ data: Data) throws {
        let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: data)
        apply(snapshot)
        Haptics.enabled = settings.hapticsEnabled
        save()
    }

    private func seed() {
        let today = Date()
        let start = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        let todayKey = DateKey(today, calendar: calendar)
        let sampleGoals = [
            Goal(id: UUID(), title: String(localized: "Workout"), note: String(localized: "At least 45 minutes"), frequency: .daily, activity: .fitness, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 1, unit: "", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Drink water"), note: String(localized: "2 liters"), frequency: .daily, activity: .hydration, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 2, unit: "L", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Read"), note: String(localized: "At least 20 minutes"), frequency: .daily, activity: .reading, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 20, unit: "min", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Meditate"), note: String(localized: "At least 10 minutes"), frequency: .daily, activity: .meditation, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 10, unit: "min", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Eat clean"), note: String(localized: "No junk food"), frequency: .daily, activity: .nutrition, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 1, unit: "", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Journal"), note: String(localized: "Three grateful things"), frequency: .daily, activity: .journal, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 1, unit: "", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Sleep early"), note: String(localized: "Before 23:30"), frequency: .daily, activity: .sleep, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 1, unit: "", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Walk 10k steps"), note: String(localized: "Move every day"), frequency: .daily, activity: .mindfulness, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 1, unit: "", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Run 10 km"), note: String(localized: "Single milestone"), frequency: .once, activity: .fitness, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 1, unit: "", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Solo trip"), note: String(localized: "Plan and take the trip"), frequency: .once, activity: .travel, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 1, unit: "", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Read 12 books"), note: String(localized: "A long target"), frequency: .once, activity: .learning, createdAt: start, startsOn: DateKey(start), dueOn: DateKey(calendar.date(byAdding: .month, value: 6, to: today) ?? today), targetValue: 12, unit: "books", isArchived: false),
            Goal(id: UUID(), title: String(localized: "Build a portfolio"), note: String(localized: "One complete project"), frequency: .once, activity: .creative, createdAt: start, startsOn: DateKey(start), dueOn: nil, targetValue: 1, unit: "", isArchived: false),
        ]
        goals = sampleGoals

        var seededLogs: [GoalLog] = []
        for dayOffset in -28 ... 0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let key = DateKey(date, calendar: calendar)
            for (index, goal) in sampleGoals.filter({ $0.frequency == .daily }).enumerated() {
                let shouldComplete = (abs(dayOffset) + index) % 4 != 0
                if shouldComplete {
                    seededLogs.append(GoalLog(id: UUID(), goalID: goal.id, date: key, value: goal.targetValue, completedAt: date))
                }
            }
        }
        for goal in sampleGoals.filter({ $0.frequency == .once }).prefix(2) {
            seededLogs.append(GoalLog(id: UUID(), goalID: goal.id, date: todayKey, value: goal.targetValue, completedAt: today))
        }
        if let books = sampleGoals.first(where: { $0.title == "Read 12 books" }) {
            seededLogs.append(GoalLog(id: UUID(), goalID: books.id, date: todayKey, value: 6, completedAt: nil))
        }
        logs = seededLogs

        let planStart = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        let completedDays = Set<DateKey>((-28 ... -1).compactMap { offset in
            guard offset % 5 != 0, let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return DateKey(date, calendar: calendar)
        })
        plans = [
            LifePlan(id: UUID(), title: String(localized: "Change my life"), subtitle: String(localized: "90-day plan"), startsOn: DateKey(planStart), dayCount: 90, completedDays: completedDays, isArchived: false),
        ]
        journal = [
            JournalEntry(id: UUID(), date: todayKey, mood: 4, text: String(localized: "Momentum is visible when I keep promises small enough to finish.")),
        ]
        hasCompletedOnboarding = false
        save()
    }

    /// Wipe everything and reseed the sample data (used by Settings → Reset).
    func resetAllData() {
        seed()
    }

    /// Replace current data with the sample dataset but keep onboarding completed.
    func loadSampleData() {
        seed()
        hasCompletedOnboarding = true
        save()
    }

    func completeOnboarding(
        dailyDrafts: [GoalDraft],
        onceDrafts: [GoalDraft],
        planTitle: String,
        planSubtitle: String,
        planDays: Int
    ) {
        goals = []
        logs = []
        plans = []
        journal = []
        let now = Date()
        for draft in dailyDrafts {
            addGoalWithoutSaving(draft: draft, frequency: .daily, startsOn: now, dueOn: nil)
        }
        for draft in onceDrafts {
            addGoalWithoutSaving(draft: draft, frequency: .once, startsOn: now, dueOn: nil)
        }
        plans = [
            LifePlan(
                id: UUID(),
                title: planTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Change my life" : planTitle,
                subtitle: planSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(planDays)-day challenge" : planSubtitle,
                startsOn: DateKey(now, calendar: calendar),
                dayCount: max(1, planDays),
                completedDays: [],
                isArchived: false
            ),
        ]
        hasCompletedOnboarding = true
        save()
    }

    func skipOnboarding() {
        hasCompletedOnboarding = true
        save()
    }

    func recentKeys(days: Int) -> Set<DateKey> {
        Set((0 ..< days).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: .now).map { DateKey($0, calendar: calendar) }
        })
    }

    private func addGoalWithoutSaving(draft: GoalDraft, frequency: GoalFrequency, startsOn: Date, dueOn: Date?) {
        goals.append(Goal(
            id: UUID(),
            title: draft.title,
            note: draft.note,
            frequency: frequency,
            activity: draft.activity,
            createdAt: .now,
            startsOn: DateKey(startsOn, calendar: calendar),
            dueOn: dueOn.map { DateKey($0, calendar: calendar) },
            targetValue: max(1, draft.targetValue),
            unit: draft.unit,
            isArchived: false,
            reminderTime: nil,
            weekdays: (draft.weekdays?.isEmpty ?? true) ? nil : draft.weekdays
        ))
    }

    // MARK: - Insights

    /// Longest run of consecutive days (ending today or earlier) where every
    /// active daily goal that existed was completed.
    func bestDailyStreak(window: Int = 180) -> Int {
        let active = goals.filter { $0.frequency == .daily }
        guard !active.isEmpty else { return 0 }
        var best = 0
        var run = 0
        for offset in stride(from: window, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            let due = active.filter { $0.startsOn <= DateKey(date, calendar: calendar) && $0.isScheduled(onWeekday: weekday) }
            // Days with nothing scheduled don't count for or against the streak.
            guard !due.isEmpty else { continue }
            let allDone = due.allSatisfy { isComplete($0, on: date) }
            if allDone { run += 1; best = max(best, run) } else { run = 0 }
        }
        return best
    }

    /// Completion rate (0...1) of daily check-ins over the trailing `days`.
    func completionRate(days: Int = 30) -> Double {
        var due = 0
        var done = 0
        for offset in 0 ..< days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            let goals = dailyGoals(on: date)
            due += goals.count
            done += goals.filter { isComplete($0, on: date) }.count
        }
        return due == 0 ? 0 : Double(done) / Double(due)
    }

    /// Total completed daily check-ins ever recorded.
    func totalCompletions() -> Int {
        logs.filter { $0.isComplete }.count
    }

    /// Number of distinct days with at least one completion in the trailing `days`.
    func activeDays(in days: Int = 30) -> Int {
        let keys = recentKeys(days: days)
        let active = Set(logs.filter { $0.isComplete && keys.contains($0.date) }.map(\.date))
        return active.count
    }
}
