import SwiftUI

struct GoalDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(CurrentDateTicker.self) private var clock
    @Environment(\.dismiss) private var dismiss
    var goalID: UUID

    @State private var showEdit = false
    @State private var confirmDelete = false

    var body: some View {
        if let goal = store.goals.first(where: { $0.id == goalID }) {
            ScrollView {
                VStack(spacing: 18) {
                    header(goal)
                    actionPanel(goal)
                    ContributionHeatmapView(
                        title: String(localized: "\(goal.activity.title) history"),
                        subtitle: String(localized: "Completions for this activity"),
                        activity: goal.activity,
                        dayCount: 112,
                        tint: goal.activity.accent
                    )
                    stats(goal)
                    edgeState(goal)
                }
                .padding(22)
                .padding(.bottom, 90)
            }
            .background(AppBackground())
            .navigationTitle(goal.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEdit = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button {
                            store.archiveGoal(goal)
                        } label: {
                            Label(goal.isArchived ? "Restore" : "Archive", systemImage: goal.isArchived ? "tray.and.arrow.up" : "archivebox")
                        }
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                GoalEditView(goal: goal)
            }
            .confirmationDialog("Delete this goal?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deleteGoal(goal)
                    NotificationManager.shared.sync(goals: store.goals, dailyReminder: store.settings.dailyReminder)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the goal and its history. This can't be undone.")
            }
        } else {
            EmptyStateView(symbol: "exclamationmark.triangle", title: "Goal not found", message: "This goal may have been removed.", actionTitle: nil, action: nil)
                .padding(22)
                .background(AppBackground())
        }
    }

    private func header(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: goal.activity.symbol)
                    .font(.title)
                    .frame(width: 56, height: 56)
                    .foregroundStyle(goal.activity.accent)
                    .background(goal.activity.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: LifeGridTheme.rowRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(goal.frequency.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(goal.activity.accent)
                    Text(goal.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            if !goal.note.isEmpty {
                Text(goal.note)
                    .font(.body)
                    .foregroundStyle(LifeGridTheme.secondary)
            }
        }
        .padding(16)
        .lifePanel()
    }

    private func actionPanel(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(goal.frequency == .daily ? "Today" : "Progress")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(store.isComplete(goal, on: clock.now) ? "Complete" : "Open")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.isComplete(goal, on: clock.now) ? goal.activity.accent : LifeGridTheme.secondary)
            }

            if goal.isQuantified {
                Stepper(value: Binding(
                    get: { store.progressValue(for: goal, on: clock.now) },
                    set: { store.setProgress($0, goal: goal, on: clock.now) }
                ), in: 0 ... goal.targetValue, step: 1) {
                    Text("\(Int(store.progressValue(for: goal, on: clock.now))) / \(Int(goal.targetValue)) \(goal.unit)")
                        .foregroundStyle(.white)
                }
            } else {
                Button {
                    let now = store.isComplete(goal, on: clock.now)
                    if !now { Haptics.success() }
                    store.setComplete(!now, goal: goal, on: clock.now)
                } label: {
                    Label(store.isComplete(goal, on: clock.now) ? "Mark incomplete" : "Mark complete", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .liquidGlassButton(prominent: true)
                .tint(goal.activity.accent)
            }
        }
        .padding(16)
        .lifePanel()
    }

    private func stats(_ goal: Goal) -> some View {
        HStack(spacing: 10) {
            StatPill(title: "Streak", value: "\(store.currentStreak(for: goal))", tint: goal.activity.accent)
            StatPill(title: "Target", value: goal.isQuantified ? "\(Int(goal.targetValue))" : "1", tint: LifeGridTheme.green)
            StatPill(title: "Status", value: goal.isArchived ? String(localized: "Paused") : String(localized: "Live"), tint: store.accent)
        }
    }

    private func edgeState(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if goal.startsOn > DateKey(clock.now) {
                Label("Starts on \(goal.startsOn.rawValue)", systemImage: "calendar.badge.clock")
                    .foregroundStyle(.yellow)
            }
            if let dueOn = goal.dueOn, dueOn < DateKey(clock.now), !store.isComplete(goal) {
                Label("Overdue since \(dueOn.rawValue)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if goal.isArchived {
                Label("Archived goals stay out of Today and active stats.", systemImage: "archivebox")
                    .foregroundStyle(LifeGridTheme.secondary)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifePanel()
    }
}

// MARK: - Edit sheet

struct GoalEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var goal: Goal

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 14) {
                        labeled("Title", text: $goal.title)
                        labeled("Note", text: $goal.note)
                        labeled("Unit", text: $goal.unit)
                        Stepper(value: $goal.targetValue, in: 1 ... 999, step: 1) {
                            HStack {
                                Text("Target")
                                Spacer()
                                Text("\(Int(goal.targetValue))").foregroundStyle(LifeGridTheme.secondary)
                            }
                            .foregroundStyle(.white)
                        }

                        Toggle(isOn: reminderToggle) {
                            Text("Reminder").foregroundStyle(.white)
                        }
                        .tint(store.accent)

                        if let time = goal.reminderTime {
                            DatePicker(
                                "Reminder time",
                                selection: Binding(get: { time }, set: { goal.reminderTime = $0 }),
                                displayedComponents: .hourAndMinute
                            )
                            .foregroundStyle(.white)
                            .tint(store.accent)
                        }
                    }
                    .padding(16)
                    .lifePanel()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity")
                            .font(.headline)
                            .foregroundStyle(.white)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                            ForEach(ActivityKind.allCases) { item in
                                Button { goal.activity = item } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: item.symbol).font(.title3)
                                        Text(item.title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                }
                                .buttonStyle(ActivityTileStyle(isSelected: goal.activity == item, tint: item.accent))
                            }
                        }
                    }
                    .padding(16)
                    .lifePanel()
                }
                .padding(22)
            }
            .background(AppBackground())
            .navigationTitle("Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateGoal(goal)
                        Task { await NotificationManager.shared.ensureAuthorizedThenSync(goals: store.goals, dailyReminder: store.settings.dailyReminder) }
                        dismiss()
                    }
                    .disabled(goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var reminderToggle: Binding<Bool> {
        Binding(
            get: { goal.reminderTime != nil },
            set: { on in
                goal.reminderTime = on ? (Calendar.autoupdatingCurrent.date(from: DateComponents(hour: 9, minute: 0)) ?? .now) : nil
            }
        )
    }

    private func labeled(_ label: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeGridTheme.secondary)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(12)
                .background(LifeGridTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
        }
    }
}
