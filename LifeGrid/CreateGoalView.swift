import SwiftUI

enum CreateMode: String, CaseIterable, Identifiable {
    case daily, once, plan
    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: String(localized: "Daily")
        case .once: String(localized: "One-time")
        case .plan: String(localized: "90-day")
        }
    }
}

struct CreateGoalView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mode: CreateMode = .daily
    @State private var title = ""
    @State private var note = ""
    @State private var activity: ActivityKind = .fitness
    @State private var startDate = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var targetValue = 1.0
    @State private var unit = ""
    @State private var planDays = 90
    @State private var hasReminder = false
    @State private var reminderTime = Calendar.autoupdatingCurrent.date(from: DateComponents(hour: 9, minute: 0)) ?? .now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Type", selection: $mode) {
                        ForEach(CreateMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    fieldGroup {
                        labeledTextField("Title", text: $title, prompt: String(localized: "Change my life"))
                        labeledTextField("Note", text: $note, prompt: mode == .plan ? String(localized: "A compact promise for this season") : String(localized: "At least 45 minutes"))
                    }

                    if mode != .plan {
                        activityPicker

                        fieldGroup {
                            DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                                .foregroundStyle(.white)

                            Toggle("Due date", isOn: $hasDueDate)
                                .tint(store.accent)

                            if hasDueDate {
                                DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                                    .foregroundStyle(.white)
                            }

                            Stepper(value: $targetValue, in: 1 ... 999, step: 1) {
                                HStack {
                                    Text("Target")
                                    Spacer()
                                    Text("\(Int(targetValue))")
                                        .foregroundStyle(LifeGridTheme.secondary)
                                }
                            }

                            labeledTextField("Unit", text: $unit, prompt: String(localized: "min, L, books"))

                            Toggle(isOn: $hasReminder) {
                                Text("Reminder").foregroundStyle(.white)
                            }
                            .tint(store.accent)

                            if hasReminder {
                                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                    .foregroundStyle(.white)
                                    .tint(store.accent)
                            }
                        }
                    } else {
                        fieldGroup {
                            DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                                .foregroundStyle(.white)
                            HStack(spacing: 8) {
                                ForEach([30, 60, 90], id: \.self) { days in
                                    Button {
                                        Haptics.soft()
                                        planDays = days
                                    } label: {
                                        Text("\(days)")
                                            .font(.headline.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(ActivityTileStyle(isSelected: planDays == days, tint: store.accent))
                                }
                            }
                            Stepper(value: $planDays, in: 7 ... 365, step: 1) {
                                HStack {
                                    Text("Days")
                                    Spacer()
                                    Text("\(planDays)")
                                        .foregroundStyle(LifeGridTheme.secondary)
                                }
                            }
                        }
                    }

                    Button {
                        save()
                    } label: {
                        Label(mode == .plan ? "Create plan" : "Create goal", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .liquidGlassButton(prominent: true)
                    .tint(mode == .daily ? LifeGridTheme.green : store.accent)
                    .disabled(!canSave)
                }
                .padding(22)
            }
            .background(AppBackground())
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activityPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)
                .foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(ActivityKind.allCases) { item in
                    Button {
                        Haptics.soft()
                        activity = item
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: item.symbol)
                                .font(.title3)
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(ActivityTileStyle(isSelected: activity == item, tint: item.accent))
                }
            }
        }
        .padding(16)
        .lifePanel()
    }

    private func fieldGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 14) {
            content()
        }
        .padding(16)
        .lifePanel()
    }

    private func labeledTextField(_ label: LocalizedStringKey, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeGridTheme.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(12)
                .background(LifeGridTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
        }
    }

    private func save() {
        Haptics.success()
        if mode == .plan {
            store.addPlan(title: title, subtitle: note.isEmpty ? String(localized: "\(planDays)-day plan") : note, startsOn: startDate, dayCount: planDays)
        } else {
            store.addGoal(
                title: title,
                note: note,
                frequency: mode == .daily ? .daily : .once,
                activity: activity,
                startsOn: startDate,
                dueOn: hasDueDate ? dueDate : nil,
                targetValue: targetValue,
                unit: unit,
                reminderTime: hasReminder ? reminderTime : nil
            )
            if hasReminder {
                Task { await NotificationManager.shared.ensureAuthorizedThenSync(goals: store.goals, dailyReminder: store.settings.dailyReminder) }
            }
        }
        dismiss()
    }
}

struct ActivityTileStyle: ButtonStyle {
    var isSelected: Bool
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .black : LifeGridTheme.secondary)
            .background(isSelected ? tint : LifeGridTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous)
                    .stroke(isSelected ? tint : LifeGridTheme.stroke)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
