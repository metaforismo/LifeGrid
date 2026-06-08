import SwiftUI

/// A month-at-a-glance calendar of a daily goal's check-offs, with month paging.
struct GoalCalendarView: View {
    @Environment(AppStore.self) private var store
    @Environment(CurrentDateTicker.self) private var clock
    var goal: Goal

    @State private var monthAnchor: Date = .now

    private var calendar: Calendar { store.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            weekdayHeader
            grid
        }
        .padding(16)
        .lifePanel()
        .onAppear { monthAnchor = startOfMonth(clock.now) }
    }

    private var header: some View {
        HStack {
            Text(monthAnchor, format: .dateTime.month(.wide).year())
                .font(.headline)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Spacer()
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LifeGridTheme.secondary)
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canGoForward ? LifeGridTheme.secondary : LifeGridTheme.muted.opacity(0.4))
            .disabled(!canGoForward)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LifeGridTheme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 34)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let complete = store.isComplete(goal, on: day)
        let isToday = calendar.isDate(day, inSameDayAs: clock.now)
        let isFuture = day > clock.now
        return Text(day, format: .dateTime.day())
            .font(.footnote.weight(complete ? .bold : .regular))
            .foregroundStyle(complete ? .black : (isFuture ? LifeGridTheme.muted : .white))
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                Circle().fill(complete ? goal.activity.accent : Color.clear)
            )
            .overlay(
                Circle().stroke(isToday && !complete ? store.accent : .clear, lineWidth: 1.5)
            )
    }

    // MARK: - Date helpers

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1 // 0-based
        return Array(symbols[first...] + symbols[..<first])
    }

    private var cells: [Date?] {
        let first = startOfMonth(monthAnchor)
        let weekdayOfFirst = calendar.component(.weekday, from: first) // 1...7
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        var result: [Date?] = Array(repeating: nil, count: leading)
        for d in 0 ..< dayCount {
            result.append(calendar.date(byAdding: .day, value: d, to: first))
        }
        return result
    }

    private var canGoForward: Bool {
        startOfMonth(monthAnchor) < startOfMonth(clock.now)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        Haptics.soft()
        withAnimation(.snappy) { monthAnchor = startOfMonth(next) }
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
