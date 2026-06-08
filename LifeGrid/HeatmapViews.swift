import SwiftUI

struct ContributionHeatmapView: View {
    @Environment(AppStore.self) private var store
    var title: String
    var subtitle: String
    var activity: ActivityKind?
    var dayCount: Int = 112
    var tint: Color = LifeGridTheme.green

    @State private var selected: (key: DateKey, count: Int)?
    @State private var revealed = false

    private let cell: CGFloat = 13
    private let spacing: CGFloat = 4

    private var calendar: Calendar { store.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(selectionText ?? subtitle)
                        .font(.caption)
                        .foregroundStyle(selected == nil ? LifeGridTheme.secondary : tint)
                        .contentTransition(.numericText())
                }
                Spacer()
                legend
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing) {
                    monthLabels
                    HStack(alignment: .top, spacing: spacing) {
                        weekdayLabels
                        grid
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .lifePanel()
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { revealed = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    // MARK: - Layout pieces

    private var weeks: [[Date]] {
        let today = calendar.startOfDay(for: .now)
        guard let earliest = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today),
              let weekStart = calendar.dateInterval(of: .weekOfYear, for: earliest)?.start
        else { return [] }

        var columns: [[Date]] = []
        var cursor = weekStart
        while cursor <= today {
            let column = (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0, to: cursor) }
            columns.append(column)
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return columns
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, column in
                VStack(spacing: spacing) {
                    ForEach(column, id: \.self) { date in
                        heatCell(for: date)
                    }
                }
            }
        }
    }

    private var monthLabels: some View {
        let headers = monthHeaders
        return HStack(spacing: spacing) {
            // Leading spacer to align with the weekday-label column.
            Color.clear.frame(width: 18)
            ForEach(headers.indices, id: \.self) { index in
                Text(headers[index])
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(LifeGridTheme.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: cell, alignment: .leading)
            }
        }
    }

    /// One label per column, showing an abbreviated month at its first column
    /// but never closer than 3 columns apart (keeps labels from overlapping).
    private var monthHeaders: [String] {
        var result: [String] = []
        var lastLabeled = -3
        var lastMonth = -1
        for (i, column) in weeks.enumerated() {
            guard let first = column.first else { result.append(""); continue }
            let m = calendar.component(.month, from: first)
            if m != lastMonth {
                if i - lastLabeled >= 3 {
                    result.append(first.formatted(.dateTime.month(.abbreviated)))
                    lastLabeled = i
                } else {
                    result.append("")
                }
                lastMonth = m
            } else {
                result.append("")
            }
        }
        return result
    }

    private var weekdayLabels: some View {
        VStack(spacing: spacing) {
            ForEach(0 ..< 7, id: \.self) { row in
                Group {
                    if row % 2 == 1, let date = calendar.date(byAdding: .day, value: row, to: weekAnchor) {
                        Text(date, format: .dateTime.weekday(.narrow))
                    } else {
                        Text(" ")
                    }
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(LifeGridTheme.muted)
                .frame(width: 14, height: cell)
            }
        }
    }

    private var weekAnchor: Date {
        weeks.first?.first ?? calendar.startOfDay(for: .now)
    }

    private func heatCell(for date: Date) -> some View {
        let today = calendar.startOfDay(for: .now)
        let key = DateKey(date, calendar: calendar)
        let inRange = date <= today
        let count = inRange ? store.activityCount(on: key, activity: activity) : 0
        let isSelected = selected?.key == key
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(inRange ? color(for: count) : Color.white.opacity(0.03))
            .frame(width: cell, height: cell)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(isSelected ? .white : Color.white.opacity(0.04), lineWidth: isSelected ? 1.2 : 0.5)
            )
            .opacity(revealed ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                guard inRange else { return }
                Haptics.soft()
                withAnimation(.snappy) { selected = (key, count) }
            }
            .accessibilityLabel("\(count) on \(key.rawValue)")
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less").font(.system(size: 9)).foregroundStyle(LifeGridTheme.muted)
            ForEach(0 ..< 4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: level))
                    .frame(width: 10, height: 10)
            }
            Text("More").font(.system(size: 9)).foregroundStyle(LifeGridTheme.muted)
        }
    }

    private var selectionText: String? {
        guard let selected else { return nil }
        let date = selected.key.date
        let dateStr = date.formatted(.dateTime.day().month(.abbreviated))
        return "\(dateStr) • \(selected.count)"
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: Color.white.opacity(0.08)
        case 1: tint.opacity(0.35)
        case 2: tint.opacity(0.62)
        default: tint
        }
    }
}

struct NinetyDayGridView: View {
    @Environment(AppStore.self) private var store
    var plan: LifePlan
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0 ..< plan.dayCount, id: \.self) { index in
                let day = dayKey(offset: index)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(plan.completedDays.contains(day) ? store.accent : Color.white.opacity(index % 7 == 0 ? 0.14 : 0.08))
                    .frame(height: 12)
                    .accessibilityLabel("Day \(index + 1)")
            }
        }
    }

    private func dayKey(offset: Int) -> DateKey {
        let date = Calendar.autoupdatingCurrent.date(byAdding: .day, value: offset, to: plan.startsOn.date) ?? plan.startsOn.date
        return DateKey(date)
    }
}
