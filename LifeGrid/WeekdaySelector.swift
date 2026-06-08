import SwiftUI

/// A row of seven toggleable weekday pills (Calendar weekdays 1...7), ordered by
/// the user's chosen first day of the week.
struct WeekdaySelector: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                Button {
                    Haptics.soft()
                    if isOn { selection.remove(weekday) } else { selection.insert(weekday) }
                } label: {
                    Text(symbol(for: weekday))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(isOn ? .black : LifeGridTheme.secondary)
                        .background(
                            Capsule().fill(isOn ? store.accent : LifeGridTheme.field)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(fullSymbol(for: weekday)))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private var orderedWeekdays: [Int] {
        let first = store.calendar.firstWeekday
        return (0 ..< 7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private func symbol(for weekday: Int) -> String {
        store.calendar.veryShortStandaloneWeekdaySymbols[(weekday - 1) % 7]
    }

    private func fullSymbol(for weekday: Int) -> String {
        store.calendar.standaloneWeekdaySymbols[(weekday - 1) % 7]
    }
}

/// A short, localized schedule label for a goal: "Every day" or "Mon, Wed, Fri".
@MainActor
func weekdaysLabel(_ weekdays: Set<Int>?, calendar: Calendar) -> String {
    guard let weekdays, !weekdays.isEmpty else { return String(localized: "Every day") }
    let symbols = calendar.shortStandaloneWeekdaySymbols
    let first = calendar.firstWeekday
    let ordered = (0 ..< 7)
        .map { ((first - 1 + $0) % 7) + 1 }
        .filter { weekdays.contains($0) }
    return ordered.map { symbols[($0 - 1) % 7] }.joined(separator: ", ")
}
