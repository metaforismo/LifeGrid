import SwiftUI

enum GoalFilter: String, CaseIterable, Identifiable {
    case daily, once, plans, archived
    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: String(localized: "Daily")
        case .once: String(localized: "Once")
        case .plans: String(localized: "Plans")
        case .archived: String(localized: "Archive")
        }
    }
}

struct GoalsView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: GoalFilter = .daily
    var openCreate: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("Goals")
                        .font(.largeTitle.weight(.bold))
                    Spacer()
                    Button {
                        Haptics.tap()
                        openCreate()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .frame(width: 42, height: 42)
                            .background(LifeGridTheme.panelStrong)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text("Create goal"))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, LGSpacing.l)
                .padding(.top, 18)

                Picker("Goal filter", selection: $filter) {
                    ForEach(GoalFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, LGSpacing.l)

                content
            }
            .padding(.bottom, 100)
        }
        .background(AppBackground())
    }

    @ViewBuilder
    private var content: some View {
        switch filter {
        case .daily:
            let goals = store.dailyGoals()
            if goals.isEmpty {
                empty("target", "No daily habits", "Daily goals show up on Today once their start date arrives.")
            } else {
                GoalListPanel(goals: goals)
            }
        case .once:
            let goals = store.onceGoals()
            if goals.isEmpty {
                empty("star", "No milestones", "One-time goals can be simple completions or numeric targets.")
            } else {
                GoalListPanel(goals: goals)
            }
        case .plans:
            let plans = store.plans.filter { !$0.isArchived }
            if plans.isEmpty {
                empty("calendar.badge.clock", "No plans", "Create a 90-day plan and track the full grid.")
            } else {
                ForEach(plans) { plan in
                    PlanSummaryCard(plan: plan)
                }
            }
        case .archived:
            let goals = store.goals.filter(\.isArchived)
            if goals.isEmpty {
                empty("archivebox", "Archive is empty", "Paused or finished goals can be archived from their detail page.")
            } else {
                GoalListPanel(goals: goals)
            }
        }
    }

    private func empty(_ symbol: String, _ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
        EmptyStateView(symbol: symbol, title: title, message: message, actionTitle: "Create", action: openCreate)
            .padding(.horizontal, LGSpacing.l)
    }
}
