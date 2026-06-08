@testable import LifeGrid
import XCTest

@MainActor
final class AppStoreTests: XCTestCase {
    private func temporaryURL(_ name: String = UUID().uuidString) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(name).json")
    }

    func testDailyGoalCompletionTogglesForToday() {
        let store = AppStore(storageURL: temporaryURL())
        guard let goal = store.dailyGoals().first(where: { !$0.isQuantified }) else {
            return XCTFail("Expected seeded daily goal")
        }

        store.setComplete(false, goal: goal)
        XCTAssertFalse(store.isComplete(goal))

        store.setComplete(true, goal: goal)
        XCTAssertTrue(store.isComplete(goal))
    }

    func testQuantifiedGoalCompletesAtTarget() {
        let store = AppStore(storageURL: temporaryURL())
        guard let goal = store.dailyGoals().first(where: { $0.targetValue > 1 }) else {
            return XCTFail("Expected quantified seeded goal")
        }

        store.setProgress(goal.targetValue - 1, goal: goal)
        XCTAssertFalse(store.isComplete(goal))

        store.setProgress(goal.targetValue, goal: goal)
        XCTAssertTrue(store.isComplete(goal))
    }

    func testOneTimeGoalCompletionIsGlobal() {
        let store = AppStore(storageURL: temporaryURL())
        guard let goal = store.onceGoals().last else {
            return XCTFail("Expected seeded one-time goal")
        }

        store.setComplete(true, goal: goal)
        XCTAssertTrue(store.isComplete(goal))
    }

    func testPlanTogglePersistsToday() {
        let store = AppStore(storageURL: temporaryURL())
        guard let plan = store.activePlan() else {
            return XCTFail("Expected seeded plan")
        }

        let key = DateKey(.now)
        let initiallyComplete = plan.completedDays.contains(key)
        store.togglePlanToday(plan)

        guard let updated = store.activePlan() else {
            return XCTFail("Expected active plan after toggle")
        }
        XCTAssertEqual(updated.completedDays.contains(key), !initiallyComplete)
    }

    func testAddedGoalPersistsToDisk() {
        let url = temporaryURL()
        let store = AppStore(storageURL: url)
        store.addGoal(
            title: "Practice piano",
            note: "One focused block",
            frequency: .daily,
            activity: .learning,
            startsOn: .now,
            dueOn: nil,
            targetValue: 1,
            unit: ""
        )

        let reloaded = AppStore(storageURL: url)
        XCTAssertTrue(reloaded.goals.contains { $0.title == "Practice piano" })
    }

    func testDeleteGoalRemovesGoalAndLogs() {
        let store = AppStore(storageURL: temporaryURL())
        guard let goal = store.dailyGoals().first else {
            return XCTFail("Expected seeded daily goal")
        }
        store.setComplete(true, goal: goal)
        XCTAssertFalse(store.logs.filter { $0.goalID == goal.id }.isEmpty)

        store.deleteGoal(goal)
        XCTAssertFalse(store.goals.contains { $0.id == goal.id })
        XCTAssertTrue(store.logs.filter { $0.goalID == goal.id }.isEmpty)
    }

    func testDeletePlanRemovesPlan() {
        let store = AppStore(storageURL: temporaryURL())
        guard let plan = store.activePlan() else {
            return XCTFail("Expected seeded plan")
        }
        store.deletePlan(plan)
        XCTAssertFalse(store.plans.contains { $0.id == plan.id })
    }

    func testResetAllDataRestartsOnboarding() {
        let store = AppStore(storageURL: temporaryURL())
        store.completeOnboarding(dailyDrafts: [], onceDrafts: [], planTitle: "X", planSubtitle: "Y", planDays: 30)
        XCTAssertTrue(store.hasCompletedOnboarding)

        store.resetAllData()
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(store.goals.isEmpty, "Reset should reseed sample goals")
    }

    /// A goal saved by an older build with the retired "coding" activity should
    /// still decode (falling back to .learning) instead of failing the load.
    func testLenientActivityDecodingFallsBack() throws {
        let goal = Goal(
            id: UUID(), title: "Legacy", note: "", frequency: .daily, activity: .fitness,
            createdAt: .now, startsOn: DateKey(.now), dueOn: nil, targetValue: 1, unit: "", isArchived: false
        )
        let data = try JSONEncoder().encode(goal)
        guard var json = String(data: data, encoding: .utf8) else {
            return XCTFail("Could not stringify goal JSON")
        }
        json = json.replacingOccurrences(of: "\"fitness\"", with: "\"coding\"")
        let migrated = try JSONDecoder().decode(Goal.self, from: Data(json.utf8))
        XCTAssertEqual(migrated.activity, .learning)
    }

    func testSnapshotRoundTripsWithoutDeveloperLogs() throws {
        let store = AppStore(storageURL: temporaryURL())
        let snapshot = AppSnapshot(
            goals: store.goals, logs: store.logs, plans: store.plans,
            journal: store.journal, hasCompletedOnboarding: true
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(AppSnapshot.self, from: data)
        XCTAssertEqual(decoded.goals.count, store.goals.count)
        XCTAssertTrue(decoded.hasCompletedOnboarding)
    }

    func testSettingsPersistAcrossReload() {
        let url = temporaryURL()
        let store = AppStore(storageURL: url)
        store.settings.accent = .blue
        store.settings.firstWeekday = 2
        store.settings.hapticsEnabled = false
        store.settings.dailyReminder = Date(timeIntervalSince1970: 1_000_000)
        store.persistSettings()

        let reloaded = AppStore(storageURL: url)
        XCTAssertEqual(reloaded.settings.accent, .blue)
        XCTAssertEqual(reloaded.settings.firstWeekday, 2)
        XCTAssertFalse(reloaded.settings.hapticsEnabled)
        XCTAssertNotNil(reloaded.settings.dailyReminder)
    }

    func testExportImportRoundTrip() throws {
        let store = AppStore(storageURL: temporaryURL())
        let data = try store.exportData()

        let other = AppStore(storageURL: temporaryURL())
        try other.importData(data)
        XCTAssertEqual(other.goals.count, store.goals.count)
        XCTAssertEqual(other.plans.count, store.plans.count)
    }

    func testReminderTimePersists() {
        let url = temporaryURL()
        let store = AppStore(storageURL: url)
        store.addGoal(
            title: "Stretch", note: "", frequency: .daily, activity: .fitness,
            startsOn: .now, dueOn: nil, targetValue: 1, unit: "", reminderTime: Date()
        )
        let reloaded = AppStore(storageURL: url)
        XCTAssertNotNil(reloaded.goals.first { $0.title == "Stretch" }?.reminderTime)
    }

    func testStreakCountsBeforeTodayIsChecked() {
        let store = AppStore(storageURL: temporaryURL())
        store.completeOnboarding(
            dailyDrafts: [GoalDraft(title: "X", note: "", activity: .fitness)],
            onceDrafts: [], planTitle: "P", planSubtitle: "S", planDays: 30
        )
        guard let goal = store.dailyGoals().first else { return XCTFail("Expected a daily goal") }
        let yesterday = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -1, to: .now)!

        store.setComplete(true, goal: goal, on: yesterday)
        XCTAssertEqual(store.currentStreak(for: goal), 1, "Yesterday's run should show before today is checked")

        store.setComplete(true, goal: goal, on: .now)
        XCTAssertEqual(store.currentStreak(for: goal), 2, "Checking today extends the streak")
    }

    func testMarkCompleteFromReminderChecksOffToday() {
        let store = AppStore(storageURL: temporaryURL())
        guard let goal = store.dailyGoals().first(where: { !$0.isQuantified }) else {
            return XCTFail("Expected a non-quantified daily goal")
        }
        store.setComplete(false, goal: goal)
        XCTAssertFalse(store.isComplete(goal))

        store.markCompleteFromReminder(goal.id)
        XCTAssertTrue(store.isComplete(goal), "The notification action should check the goal off for today")
    }

    func testReminderIDParsesBackToGoalID() {
        let goal = Goal(
            id: UUID(), title: "X", note: "", frequency: .daily, activity: .fitness,
            createdAt: .now, startsOn: DateKey(.now), dueOn: nil, targetValue: 1, unit: "", isArchived: false
        )
        XCTAssertEqual(NotificationManager.goalID(fromReminderID: goal.reminderID), goal.id)
        XCTAssertNil(NotificationManager.goalID(fromReminderID: "lifegrid-daily-nudge"))
    }
}
