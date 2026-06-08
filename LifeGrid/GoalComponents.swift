import SwiftUI

/// The completion circle. Kept as a standalone button so it can live OUTSIDE
/// the row's NavigationLink — otherwise the link swallows the tap and the
/// circle would navigate to detail instead of toggling.
struct GoalCheckButton: View {
    @Environment(AppStore.self) private var store
    var goal: Goal
    var date: Date = .now
    var editable: Bool = true

    var body: some View {
        let complete = store.isComplete(goal, on: date)
        Button {
            toggle(complete)
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(complete ? rowTint : .white.opacity(0.85), lineWidth: complete ? 0 : 2.5)
                    .background(Circle().fill(complete ? rowTint : .clear))
                if complete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .transition(.scale.combined(with: .opacity))
                        .symbolEffect(.bounce, value: complete)
                }
            }
            .frame(width: 42, height: 42)
            .scaleEffect(complete ? 1.0 : 0.96)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: complete)
        }
        .buttonStyle(.plain)
        .disabled(!editable || goal.isQuantified)
        .opacity(editable ? 1 : 0.5)
        .accessibilityLabel(Text(complete ? "Mark \(goal.title) incomplete" : "Mark \(goal.title) complete"))
    }

    private var rowTint: Color {
        goal.frequency == .daily ? LifeGridTheme.green : store.accent
    }

    private func toggle(_ complete: Bool) {
        guard editable else { return }
        if !complete { Haptics.success() } else { Haptics.soft() }
        withAnimation(.snappy) {
            store.setComplete(!complete, goal: goal, on: date)
        }
    }
}

/// The tappable (navigating) portion of a goal row: icon, title, subtitle, badge.
struct GoalRowContent: View {
    @Environment(AppStore.self) private var store
    var goal: Goal
    var date: Date = .now

    var body: some View {
        let complete = store.isComplete(goal, on: date)
        HStack(spacing: 14) {
            Image(systemName: goal.activity.symbol)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(complete ? rowTint.opacity(0.95) : LifeGridTheme.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(complete ? LifeGridTheme.secondary : .white)
                    .strikethrough(complete, color: LifeGridTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LifeGridTheme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            if goal.isQuantified {
                ProgressBadge(goal: goal, date: date, tint: rowTint)
            } else {
                StreakBadge(goal: goal, tint: rowTint)
            }
        }
        .padding(.vertical, 14)
        .padding(.trailing, 18)
        .padding(.leading, 12)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if goal.frequency == .once, store.isComplete(goal) {
            return String(localized: "Completed")
        }
        if goal.isQuantified {
            let value = store.progressValue(for: goal, on: date)
            let unit = goal.unit.isEmpty ? "" : " \(goal.unit)"
            return "\(format(value)) / \(format(goal.targetValue))\(unit)"
        }
        return goal.note
    }

    private var rowTint: Color {
        goal.frequency == .daily ? LifeGridTheme.green : store.accent
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct ProgressBadge: View {
    @Environment(AppStore.self) private var store
    var goal: Goal
    var date: Date
    var tint: Color

    var body: some View {
        let value = store.progressValue(for: goal, on: date)
        Menu {
            Button("Reset") { store.setProgress(0, goal: goal, on: date) }
            Button("Half") { store.setProgress(goal.targetValue / 2, goal: goal, on: date) }
            Button("Complete") {
                Haptics.success()
                store.setProgress(goal.targetValue, goal: goal, on: date)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: value >= goal.targetValue ? "flame.fill" : "flame")
                Text("\(format(value))")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(value >= goal.targetValue ? tint : LifeGridTheme.secondary)
            .frame(minWidth: 48, alignment: .trailing)
        }
        .accessibilityLabel(Text("Progress \(format(value)) of \(format(goal.targetValue))"))
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct StreakBadge: View {
    @Environment(AppStore.self) private var store
    var goal: Goal
    var tint: Color

    var body: some View {
        let streak = store.currentStreak(for: goal)
        HStack(spacing: 5) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
            Text("\(streak)")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(streak > 0 ? tint : LifeGridTheme.secondary)
        .accessibilityLabel(Text("Current streak \(streak)"))
    }
}

struct GoalListPanel: View {
    @Environment(AppStore.self) private var store
    var goals: [Goal]
    var date: Date = .now
    var editable: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                HStack(spacing: 0) {
                    GoalCheckButton(goal: goal, date: date, editable: editable)
                        .padding(.leading, 18)
                    NavigationLink(value: goal) {
                        GoalRowContent(goal: goal, date: date)
                    }
                    .buttonStyle(.plain)
                }
                .contextMenu {
                    Button {
                        store.archiveGoal(goal)
                    } label: {
                        Label(goal.isArchived ? "Restore" : "Archive", systemImage: goal.isArchived ? "tray.and.arrow.up" : "archivebox")
                    }
                    Button(role: .destructive) {
                        store.deleteGoal(goal)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                if index < goals.count - 1 {
                    Divider()
                        .background(LifeGridTheme.stroke)
                        .padding(.leading, 102)
                }
            }
        }
        .lifePanel()
        .padding(.horizontal, LGSpacing.l)
    }
}

struct PlanSummaryCard: View {
    @Environment(AppStore.self) private var store
    var plan: LifePlan

    var body: some View {
        NavigationLink(value: plan) {
            HStack(spacing: 18) {
                ZStack {
                    CircularProgressView(progress: progress, tint: store.accent, lineWidth: 7, showsLabel: false)
                    Text("\(Int(progress * 100))%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(store.accent)
                    Text(plan.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text("\(plan.completedDays.count) / \(plan.dayCount) days completed")
                        .font(.subheadline)
                        .foregroundStyle(LifeGridTheme.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LifeGridTheme.secondary)
            }
            .padding(18)
            .background(LifeGridTheme.planGradient(store.accent), in: RoundedRectangle(cornerRadius: LifeGridTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LifeGridTheme.cardRadius, style: .continuous)
                    .stroke(store.accent.opacity(0.3), lineWidth: 0.8)
            )
            .shadow(color: store.accent.opacity(0.18), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, LGSpacing.l)
    }

    private var progress: Double {
        Double(plan.completedDays.count) / Double(max(plan.dayCount, 1))
    }
}

struct StatPill: View {
    var title: LocalizedStringKey
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(LifeGridTheme.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lifePanel(radius: LifeGridTheme.rowRadius)
    }
}
