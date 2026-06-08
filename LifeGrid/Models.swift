import Foundation
import SwiftUI

struct DateKey: Hashable, Codable, Comparable, Sendable {
    var rawValue: String

    init(_ date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var date: Date {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: rawValue) ?? .now
    }

    static func < (lhs: DateKey, rhs: DateKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum GoalFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case once

    var id: String { rawValue }
    var title: String { self == .daily ? String(localized: "Daily") : String(localized: "One-time") }
}

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case fitness, hydration, reading, meditation, nutrition, journal, sleep, travel, learning, creative, finance, mindfulness

    var id: String { rawValue }

    /// Lenient decoding: any unknown/retired raw value (e.g. a previously-saved
    /// "coding" goal) falls back to `.learning` instead of failing the whole load.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ActivityKind(rawValue: raw) ?? .learning
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var title: String {
        switch self {
        case .fitness: String(localized: "Fitness")
        case .hydration: String(localized: "Hydration")
        case .reading: String(localized: "Reading")
        case .meditation: String(localized: "Meditation")
        case .nutrition: String(localized: "Nutrition")
        case .journal: String(localized: "Journal")
        case .sleep: String(localized: "Sleep")
        case .travel: String(localized: "Travel")
        case .learning: String(localized: "Learning")
        case .creative: String(localized: "Creative")
        case .finance: String(localized: "Finance")
        case .mindfulness: String(localized: "Mindfulness")
        }
    }

    var symbol: String {
        switch self {
        case .fitness: "dumbbell"
        case .hydration: "drop"
        case .reading: "book"
        case .meditation: "figure.mind.and.body"
        case .nutrition: "fork.knife"
        case .journal: "text.book.closed"
        case .sleep: "moon"
        case .travel: "airplane"
        case .learning: "graduationcap"
        case .creative: "camera"
        case .finance: "chart.line.uptrend.xyaxis"
        case .mindfulness: "leaf"
        }
    }

    var accent: Color {
        switch self {
        case .fitness: .green
        case .hydration: .cyan
        case .reading: .orange
        case .meditation: .purple
        case .nutrition: .teal
        case .journal: .indigo
        case .sleep: .blue
        case .travel: .pink
        case .learning: .yellow
        case .creative: .red
        case .finance: .brown
        case .mindfulness: .mint
        }
    }
}

struct Goal: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var note: String
    var frequency: GoalFrequency
    var activity: ActivityKind
    var createdAt: Date
    var startsOn: DateKey
    var dueOn: DateKey?
    var targetValue: Double
    var unit: String
    var isArchived: Bool
    /// Optional daily reminder time (only hour/minute are used). Optional →
    /// older saved goals without the field decode to `nil` automatically.
    var reminderTime: Date?

    var isQuantified: Bool {
        targetValue > 1 || !unit.isEmpty
    }

    /// Stable identifier used for scheduling this goal's local notification.
    var reminderID: String { "goal-reminder-\(id.uuidString)" }
}

struct GoalLog: Identifiable, Hashable, Codable {
    var id: UUID
    var goalID: UUID
    var date: DateKey
    var value: Double
    var completedAt: Date?

    var isComplete: Bool {
        completedAt != nil
    }
}

struct LifePlan: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var subtitle: String
    var startsOn: DateKey
    var dayCount: Int
    var completedDays: Set<DateKey>
    var isArchived: Bool
}

struct JournalEntry: Identifiable, Hashable, Codable {
    var id: UUID
    var date: DateKey
    var mood: Int
    var text: String
}

struct GoalDraft: Hashable {
    var title: String
    var note: String
    var activity: ActivityKind
    var targetValue: Double = 1
    var unit: String = ""
}

// MARK: - Settings & theming

enum AccentChoice: String, Codable, CaseIterable, Identifiable {
    case purple, green, blue, pink, orange, teal

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .purple: LifeGridTheme.purple
        case .green: LifeGridTheme.green
        case .blue: Color(red: 0.36, green: 0.62, blue: 1.0)
        case .pink: Color(red: 1.0, green: 0.45, blue: 0.72)
        case .orange: Color(red: 1.0, green: 0.6, blue: 0.3)
        case .teal: Color(red: 0.3, green: 0.82, blue: 0.78)
        }
    }

    var title: String {
        switch self {
        case .purple: String(localized: "Purple")
        case .green: String(localized: "Green")
        case .blue: String(localized: "Blue")
        case .pink: String(localized: "Pink")
        case .orange: String(localized: "Orange")
        case .teal: String(localized: "Teal")
        }
    }
}

/// User preferences persisted alongside the data. `firstWeekday` uses
/// Calendar's convention (1 = Sunday … 7 = Saturday); 0 means "follow system".
struct AppSettings: Codable, Equatable {
    var accent: AccentChoice = .purple
    var firstWeekday: Int = 0
    var hapticsEnabled: Bool = true
    var dailyReminder: Date? = nil
}

struct AppSnapshot: Codable {
    var goals: [Goal]
    var logs: [GoalLog]
    var plans: [LifePlan]
    var journal: [JournalEntry]
    var hasCompletedOnboarding: Bool
    var settings: AppSettings

    init(
        goals: [Goal],
        logs: [GoalLog],
        plans: [LifePlan],
        journal: [JournalEntry],
        hasCompletedOnboarding: Bool,
        settings: AppSettings = AppSettings()
    ) {
        self.goals = goals
        self.logs = logs
        self.plans = plans
        self.journal = journal
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.settings = settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goals = try container.decode([Goal].self, forKey: .goals)
        logs = try container.decode([GoalLog].self, forKey: .logs)
        plans = try container.decode([LifePlan].self, forKey: .plans)
        journal = try container.decode([JournalEntry].self, forKey: .journal)
        // `developerLogs` from older builds is intentionally ignored if present.
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }
}
