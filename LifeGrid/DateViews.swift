import SwiftUI

struct TodayHeaderView: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedDate: Date
    var onMenu: () -> Void
    var onCalendar: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    Haptics.tap()
                    onMenu()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Settings"))

                Spacer()
                VStack(spacing: 4) {
                    Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.title.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Text("Week \(weekOfYear)")
                        .font(.headline)
                        .foregroundStyle(LifeGridTheme.secondary)
                }
                .accessibilityElement(children: .combine)
                Spacer()

                Button {
                    Haptics.tap()
                    onCalendar()
                } label: {
                    Image(systemName: "calendar")
                        .font(.title2.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Pick a date"))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, LGSpacing.l)

            DayStripView(selectedDate: $selectedDate)
        }
        .padding(.top, 12)
    }

    private var weekOfYear: Int {
        store.calendar.component(.weekOfYear, from: selectedDate)
    }
}

/// A week strip paged one week at a time. Swiping moves week-by-week (keeping
/// the same weekday selected); tapping a day selects it; an "Oggi" pill snaps
/// back to the current week.
struct DayStripView: View {
    @Environment(AppStore.self) private var store
    @Environment(CurrentDateTicker.self) private var clock
    @Binding var selectedDate: Date

    private let weekRange = -52 ... 8

    private var calendar: Calendar { store.calendar }
    private var today: Date { calendar.startOfDay(for: clock.now) }

    var body: some View {
        ZStack(alignment: .trailing) {
            TabView(selection: weekSelection) {
                ForEach(weekRange, id: \.self) { offset in
                    weekRow(offset).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 92)

            if !calendar.isDate(selectedDate, inSameDayAs: today) {
                todayPill {
                    Haptics.tap()
                    withAnimation(.snappy) { selectedDate = today }
                }
            }
        }
        .frame(height: 92)
    }

    private func weekRow(_ offset: Int) -> some View {
        let start = weekStart(offset)
        return HStack(spacing: 8) {
            ForEach(0 ..< 7, id: \.self) { d in
                if let day = calendar.date(byAdding: .day, value: d, to: start) {
                    cell(day)
                }
            }
        }
        .padding(.horizontal, LGSpacing.l)
        .padding(.vertical, 2)
    }

    private func cell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        return Button {
            Haptics.soft()
            withAnimation(.snappy(duration: 0.2)) { selectedDate = day }
        } label: {
            VStack(spacing: 8) {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.caption.weight(.semibold))
                Text(day, format: .dateTime.day())
                    .font(.title3.weight(.bold))
                Circle()
                    .fill(markerColor(for: day))
                    .frame(width: 7, height: 7)
            }
            .foregroundStyle(isSelected ? .white : LifeGridTheme.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(
                isSelected ? LifeGridTheme.panelStrong : Color.clear,
                in: RoundedRectangle(cornerRadius: LifeGridTheme.rowRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LifeGridTheme.rowRadius, style: .continuous)
                    .stroke(strokeColor(isToday: isToday, isSelected: isSelected), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func todayPill(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                Text("Today")
            }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(store.accent.opacity(0.5), lineWidth: 1))
            .foregroundStyle(store.accent)
        }
        .buttonStyle(.plain)
        .padding(.trailing, LGSpacing.l)
        .shadow(color: .black.opacity(0.5), radius: 8, x: -6)
    }

    /// Maps the paged TabView selection to/from the selected date. Swiping a
    /// week shifts the selection by 7 days, preserving the weekday.
    private var weekSelection: Binding<Int> {
        Binding(
            get: { weekOffset(of: selectedDate) },
            set: { newOffset in
                let delta = newOffset - weekOffset(of: selectedDate)
                guard delta != 0, let moved = calendar.date(byAdding: .day, value: delta * 7, to: selectedDate) else { return }
                Haptics.soft()
                selectedDate = moved
            }
        )
    }

    private func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func weekStart(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset * 7, to: startOfWeek(today)) ?? today
    }

    private func weekOffset(of date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: startOfWeek(today), to: startOfWeek(date)).day ?? 0
        return Int((Double(days) / 7).rounded())
    }

    private func strokeColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected { return LifeGridTheme.stroke }
        if isToday { return store.accent.opacity(0.6) }
        return .clear
    }

    /// Green when all daily goals were completed that day, dim-green for some,
    /// accent for an active plan day, muted otherwise.
    private func markerColor(for day: Date) -> Color {
        let key = DateKey(day, calendar: calendar)
        let daily = store.dailyGoals(on: day)
        let done = daily.filter { store.isComplete($0, on: day) }.count
        if !daily.isEmpty, done == daily.count { return LifeGridTheme.green }
        if done > 0 { return LifeGridTheme.green.opacity(0.5) }
        if let plan = store.activePlan(), plan.completedDays.contains(key) { return store.accent }
        return LifeGridTheme.muted
    }
}

/// Sheet that lets the user jump to any date (graphical month calendar).
struct DatePickerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker(
                    "Pick a date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(store.accent)
                .padding(.horizontal, 8)

                Button {
                    Haptics.tap()
                    selectedDate = .now
                    dismiss()
                } label: {
                    Label("Jump to today", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .liquidGlassButton(prominent: true)
                .tint(store.accent)

                Spacer()
            }
            .padding(22)
            .background(AppBackground())
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
