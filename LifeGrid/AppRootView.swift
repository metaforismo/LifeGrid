import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today, goals, stats, journal

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .today: "Today"
        case .goals: "Goals"
        case .stats: "Stats"
        case .journal: "Journal"
        }
    }

    var symbol: String {
        switch self {
        case .today: "target"
        case .goals: "trophy"
        case .stats: "chart.bar"
        case .journal: "book.pages"
        }
    }
}

enum CreateSheet: Identifiable {
    case goal
    var id: String { "goal" }
}

struct AppRootView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: AppTab = .today
    @State private var sheet: CreateSheet?

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                NavigationStack {
                    selectedContent
                        .navigationDestination(for: Goal.self) { goal in
                            GoalDetailView(goalID: goal.id)
                        }
                        .navigationDestination(for: LifePlan.self) { plan in
                            PlanDetailView(planID: plan.id)
                        }
                }
                .safeAreaInset(edge: .bottom) {
                    CustomTabBar(selectedTab: $selectedTab) {
                        Haptics.tap()
                        sheet = .goal
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                }
            } else {
                OnboardingView()
            }
        }
        .tint(store.accent)
        .sheet(item: $sheet) { _ in
            CreateGoalView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .today:
            TodayView(openCreate: { sheet = .goal })
        case .goals:
            GoalsView(openCreate: { sheet = .goal })
        case .stats:
            StatsView()
        case .journal:
            JournalView()
        }
    }
}

// MARK: - Floating Liquid Glass tab bar

struct CustomTabBar: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedTab: AppTab
    var create: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                ZStack {
                    barContent
                        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .capsule)
                    centerButton
                        .glassEffect(.regular.tint(store.accent.opacity(0.18)).interactive(), in: .circle)
                }
                .frame(height: 74)
            }
        } else {
            ZStack {
                barContent
                centerButton
            }
            .frame(height: 74)
        }
    }

    private var barContent: some View {
        HStack(spacing: 2) {
            tabButton(.today)
            tabButton(.goals)
            Color.clear
                .frame(width: 62)
                .accessibilityHidden(true)
            tabButton(.stats)
            tabButton(.journal)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(LifeGridTheme.stroke, lineWidth: 0.8))
    }

    private var centerButton: some View {
        Button(action: create) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 58, height: 58)
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(LifeGridTheme.elevatedBackground)
                        .overlay(Circle().stroke(LifeGridTheme.stroke, lineWidth: 0.8))
                        .shadow(color: store.accent.opacity(0.28), radius: 16, y: 6)
                )
                .clipShape(Circle())
        }
        .accessibilityLabel(Text("Create goal"))
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            Haptics.soft()
            withAnimation(.snappy(duration: 0.22)) {
                selectedTab = tab
            }
        } label: {
            let isSelected = selectedTab == tab
            VStack(spacing: 4) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolVariant(isSelected ? .fill : .none)
                Text(tab.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 2)
            .foregroundStyle(isSelected ? store.accent : LifeGridTheme.secondary)
            .background(
                Capsule()
                    .fill(isSelected ? store.accent.opacity(0.14) : Color.clear)
            )
        }
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}
