import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(CurrentDateTicker.self) private var clock
    var openCreate: () -> Void

    @State private var selectedDate: Date = .now
    @State private var showDatePicker = false
    @State private var showSettings = false

    private var calendar: Calendar { store.calendar }

    private var isFuture: Bool {
        calendar.compare(selectedDate, to: clock.now, toGranularity: .day) == .orderedDescending
    }

    private var isToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: clock.now)
    }

    private var greeting: String {
        switch calendar.component(.hour, from: clock.now) {
        case 5 ..< 12: String(localized: "Good morning")
        case 12 ..< 18: String(localized: "Good afternoon")
        default: String(localized: "Good evening")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                TodayHeaderView(
                    selectedDate: $selectedDate,
                    onMenu: { showSettings = true },
                    onCalendar: { showDatePicker = true }
                )

                dailySection
                onceSection

                if let plan = store.activePlan() {
                    PlanSummaryCard(plan: plan)
                }

                ContributionHeatmapView(
                    title: String(localized: "Activity grid"),
                    subtitle: String(localized: "Daily completions across the last 16 weeks"),
                    activity: nil,
                    dayCount: 112,
                    tint: LifeGridTheme.green
                )
                .padding(.horizontal, LGSpacing.l)
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var dailySection: some View {
        let goals = store.dailyGoals(on: selectedDate)
        let completed = goals.filter { store.isComplete($0, on: selectedDate) }.count
        let allDone = !goals.isEmpty && completed == goals.count
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if isToday {
                        Text(greeting)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(store.accent)
                    }
                    Text("Today's goals")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    if !goals.isEmpty {
                        Text("\(completed) / \(goals.count) completed")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LifeGridTheme.green)
                            .contentTransition(.numericText())
                    }
                }
                Spacer()
                if !goals.isEmpty {
                    ZStack {
                        CircularProgressView(
                            progress: Double(completed) / Double(max(goals.count, 1)),
                            tint: LifeGridTheme.green,
                            lineWidth: 5,
                            showsLabel: false
                        )
                        if allDone {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(LifeGridTheme.green)
                        }
                    }
                    .frame(width: 42, height: 42)
                }
            }
            .padding(.horizontal, LGSpacing.l)

            if allDone {
                allDoneBanner
            }

            if goals.isEmpty {
                EmptyStateView(
                    symbol: "target",
                    title: "No daily goals yet",
                    message: "Create a simple promise for today. The week header rolls forward automatically.",
                    actionTitle: "Create goal",
                    action: openCreate
                )
                .padding(.horizontal, LGSpacing.l)
            } else {
                GoalListPanel(goals: goals, date: selectedDate, editable: !isFuture)
            }
        }
    }

    private var allDoneBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(LifeGridTheme.green)
            Text("All daily goals complete — nice work!")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(14)
        .background(LifeGridTheme.successSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: LifeGridTheme.rowRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LifeGridTheme.rowRadius, style: .continuous)
                .stroke(LifeGridTheme.green.opacity(0.4), lineWidth: 0.8)
        )
        .padding(.horizontal, LGSpacing.l)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var onceSection: some View {
        let goals = store.onceGoals().prefix(4).map(\.self)
        let completed = goals.filter { store.isComplete($0) }.count
        return VStack(spacing: 12) {
            SectionHeader(
                title: "One-time goals",
                trailing: goals.isEmpty ? nil : "\(completed) / \(goals.count)",
                tint: store.accent
            )
            if goals.isEmpty {
                EmptyStateView(
                    symbol: "star",
                    title: "No one-time goals",
                    message: "Add milestones like a trip, a race, a course, or a 12-book challenge.",
                    actionTitle: "Create milestone",
                    action: openCreate
                )
                .padding(.horizontal, LGSpacing.l)
            } else {
                GoalListPanel(goals: goals, editable: !isFuture)
            }
        }
    }
}
