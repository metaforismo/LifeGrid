import SwiftUI

struct PlanDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(CurrentDateTicker.self) private var clock
    @Environment(\.dismiss) private var dismiss
    var planID: UUID

    @State private var confirmDelete = false

    var body: some View {
        if let plan = store.plans.first(where: { $0.id == planID }) {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 16) {
                            CircularProgressView(progress: progress(plan), tint: store.accent)
                                .frame(width: 96, height: 96)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(plan.subtitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(store.accent)
                                Text(plan.title)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("\(plan.completedDays.count) / \(plan.dayCount) days")
                                    .font(.subheadline)
                                    .foregroundStyle(LifeGridTheme.secondary)
                            }
                            Spacer()
                        }

                        Button {
                            let done = isTodayComplete(plan)
                            if !done { Haptics.success() }
                            store.togglePlanToday(plan, on: clock.now)
                        } label: {
                            Label(isTodayComplete(plan) ? "Undo today" : "Complete today", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .liquidGlassButton(prominent: true)
                        .tint(store.accent)
                    }
                    .padding(16)
                    .background(LifeGridTheme.planGradient(store.accent), in: RoundedRectangle(cornerRadius: LifeGridTheme.cardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: LifeGridTheme.cardRadius, style: .continuous)
                            .stroke(store.accent.opacity(0.3), lineWidth: 0.8)
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("90-day grid")
                            .font(.headline)
                            .foregroundStyle(.white)
                        NinetyDayGridView(plan: plan)
                    }
                    .padding(16)
                    .lifePanel()

                    HStack(spacing: 10) {
                        StatPill(title: "Complete", value: "\(Int(progress(plan) * 100))%", tint: store.accent)
                        StatPill(title: "Remaining", value: "\(max(plan.dayCount - plan.completedDays.count, 0))", tint: LifeGridTheme.green)
                        StatPill(title: "Started", value: plan.startsOn.date.formatted(.dateTime.day().month(.abbreviated)), tint: .mint)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Milestones")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach([7, 30, 60, 90].filter { $0 <= plan.dayCount }, id: \.self) { day in
                            HStack {
                                Image(systemName: plan.completedDays.count >= day ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(plan.completedDays.count >= day ? LifeGridTheme.green : LifeGridTheme.secondary)
                                Text("Day \(day)")
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .lifePanel()
                }
                .padding(22)
                .padding(.bottom, 90)
            }
            .background(AppBackground())
            .navigationTitle(plan.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            store.archivePlanToggle(plan)
                        } label: {
                            Label(plan.isArchived ? "Restore" : "Archive", systemImage: plan.isArchived ? "tray.and.arrow.up" : "archivebox")
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
            .confirmationDialog("Delete this plan?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deletePlan(plan)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the plan and its progress. This can't be undone.")
            }
        } else {
            EmptyStateView(symbol: "calendar.badge.exclamationmark", title: "Plan not found", message: "This plan may have been removed.", actionTitle: nil, action: nil)
                .padding(22)
                .background(AppBackground())
        }
    }

    private func progress(_ plan: LifePlan) -> Double {
        Double(plan.completedDays.count) / Double(max(plan.dayCount, 1))
    }

    private func isTodayComplete(_ plan: LifePlan) -> Bool {
        plan.completedDays.contains(DateKey(clock.now))
    }
}
