import SwiftUI

struct StatsView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedActivity: ActivityKind? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("Statistics")
                        .font(.largeTitle.weight(.bold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, LGSpacing.l)
                .padding(.top, 18)

                HStack(spacing: 10) {
                    StatPill(title: "Today", value: "\(store.completedDailyCount())", tint: LifeGridTheme.green)
                    StatPill(title: "Active goals", value: "\(store.goals.filter { !$0.isArchived }.count)", tint: store.accent)
                    StatPill(title: "Plans", value: "\(store.plans.filter { !$0.isArchived }.count)", tint: .mint)
                }
                .padding(.horizontal, LGSpacing.l)

                insightsCard

                trendCard

                activityFilter

                ContributionHeatmapView(
                    title: selectedActivity?.title ?? String(localized: "All activity"),
                    subtitle: String(localized: "Last 32 weeks of completions"),
                    activity: selectedActivity,
                    dayCount: 224,
                    tint: selectedActivity?.accent ?? LifeGridTheme.green
                )
                .padding(.horizontal, LGSpacing.l)

                weeklyBars

                achievements

                if let plan = store.activePlan() {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(plan.subtitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                        NinetyDayGridView(plan: plan)
                        Text("\(plan.completedDays.count) / \(plan.dayCount) days complete")
                            .font(.caption)
                            .foregroundStyle(LifeGridTheme.secondary)
                    }
                    .padding(16)
                    .lifePanel()
                    .padding(.horizontal, LGSpacing.l)
                }
            }
            .padding(.bottom, 100)
        }
        .background(AppBackground())
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Insights")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                insight("\(Int(store.completionRate(days: 30) * 100))%", "30-day rate", tint: LifeGridTheme.green)
                insight("\(store.bestDailyStreak())", "Best streak", tint: store.accent)
            }
            HStack(spacing: 10) {
                insight("\(store.totalCompletions())", "Total check-ins", tint: .mint)
                insight("\(store.activeDays(in: 30))", "Active days / 30", tint: .orange)
            }
        }
        .padding(16)
        .lifePanel()
        .padding(.horizontal, LGSpacing.l)
    }

    private func insight(_ value: String, _ title: LocalizedStringKey, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(LifeGridTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(LifeGridTheme.field, in: RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
    }

    private var trendCard: some View {
        let rates = weeklyRates()
        return VStack(alignment: .leading, spacing: 14) {
            Text("8-week trend")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(rates.enumerated()), id: \.offset) { index, rate in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(rate > 0 ? store.accent.opacity(0.85) : Color.white.opacity(0.08))
                            .frame(height: 8 + CGFloat(rate) * 84)
                        Text(index == rates.count - 1 ? String(localized: "Now") : "\(index + 1)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(LifeGridTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .lifePanel()
        .padding(.horizontal, LGSpacing.l)
    }

    private func weeklyRates(weeks: Int = 8) -> [Double] {
        let cal = store.calendar
        var result: [Double] = []
        for w in stride(from: weeks - 1, through: 0, by: -1) {
            var due = 0
            var done = 0
            for d in 0 ..< 7 {
                guard let date = cal.date(byAdding: .day, value: -(w * 7 + d), to: .now) else { continue }
                let goals = store.dailyGoals(on: date)
                due += goals.count
                done += goals.filter { store.isComplete($0, on: date) }.count
            }
            result.append(due == 0 ? 0 : Double(done) / Double(due))
        }
        return result
    }

    private var activityFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    Haptics.soft()
                    selectedActivity = nil
                } label: {
                    Chip(title: String(localized: "All"), systemImage: "square.grid.3x3", isSelected: selectedActivity == nil, tint: LifeGridTheme.green)
                }
                .buttonStyle(.plain)

                ForEach(ActivityKind.allCases) { activity in
                    Button {
                        Haptics.soft()
                        selectedActivity = activity
                    } label: {
                        Chip(title: activity.title, systemImage: activity.symbol, isSelected: selectedActivity == activity, tint: activity.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LGSpacing.l)
        }
    }

    private var weeklyBars: some View {
        let values = lastSevenDayCounts()
        let maxValue = max(values.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 14) {
            Text("This week")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(value > 0 ? LifeGridTheme.green : Color.white.opacity(0.08))
                            .frame(height: CGFloat(max(value, 1)) / CGFloat(maxValue) * 120)
                        Text(dayLabel(offset: index - 6))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LifeGridTheme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .lifePanel()
        .padding(.horizontal, LGSpacing.l)
    }

    private var achievements: some View {
        let items = AchievementCatalog.evaluate(store: store)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Achievements")
                .font(.headline)
                .foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol)
                            .font(.title3)
                            .foregroundStyle(item.unlocked ? item.tint : LifeGridTheme.muted)
                            .frame(width: 36, height: 36)
                            .background((item.unlocked ? item.tint : LifeGridTheme.muted).opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(item.unlocked ? .white : LifeGridTheme.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(LifeGridTheme.muted)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(LifeGridTheme.field, in: RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
                    .opacity(item.unlocked ? 1 : 0.6)
                }
            }
        }
        .padding(16)
        .lifePanel()
        .padding(.horizontal, LGSpacing.l)
    }

    private func lastSevenDayCounts() -> [Int] {
        let calendar = Calendar.autoupdatingCurrent
        return (-6 ... 0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: .now) ?? .now
            return store.activityCount(on: DateKey(date), activity: selectedActivity)
        }
    }

    private func dayLabel(offset: Int) -> String {
        let date = Calendar.autoupdatingCurrent.date(byAdding: .day, value: offset, to: .now) ?? .now
        return date.formatted(.dateTime.weekday(.narrow))
    }
}

// MARK: - Achievements

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let unlocked: Bool
}

enum AchievementCatalog {
    @MainActor
    static func evaluate(store: AppStore) -> [Achievement] {
        let total = store.totalCompletions()
        let best = store.bestDailyStreak()
        let rate = store.completionRate(days: 30)
        return [
            Achievement(id: "first", title: String(localized: "First step"), detail: String(localized: "1 check-in"), symbol: "figure.walk", tint: LifeGridTheme.green, unlocked: total >= 1),
            Achievement(id: "streak7", title: String(localized: "On a roll"), detail: String(localized: "7-day streak"), symbol: "flame.fill", tint: .orange, unlocked: best >= 7),
            Achievement(id: "streak30", title: String(localized: "Unstoppable"), detail: String(localized: "30-day streak"), symbol: "bolt.fill", tint: store.accent, unlocked: best >= 30),
            Achievement(id: "hundred", title: String(localized: "Centurion"), detail: String(localized: "100 check-ins"), symbol: "rosette", tint: .yellow, unlocked: total >= 100),
            Achievement(id: "consistent", title: String(localized: "Consistent"), detail: String(localized: "80% in 30 days"), symbol: "checkmark.seal.fill", tint: LifeGridTheme.green, unlocked: rate >= 0.8),
            Achievement(id: "planner", title: String(localized: "Planner"), detail: String(localized: "Create a plan"), symbol: "calendar", tint: .mint, unlocked: !store.plans.filter { !$0.isArchived }.isEmpty),
        ]
    }
}
