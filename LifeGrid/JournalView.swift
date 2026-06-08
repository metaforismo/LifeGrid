import SwiftUI

struct JournalView: View {
    @Environment(AppStore.self) private var store
    @Environment(CurrentDateTicker.self) private var clock
    @State private var mood = 4
    @State private var text = ""
    @State private var saved = false

    private let moods = ["😞", "😕", "😐", "🙂", "😄"]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("Journal")
                        .font(.largeTitle.weight(.bold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, LGSpacing.l)
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 14) {
                    Text(clock.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.headline)
                        .foregroundStyle(.white)

                    moodPicker

                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(LifeGridTheme.field)
                        .clipShape(RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
                        .foregroundStyle(.white)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("What moved today?")
                                    .foregroundStyle(LifeGridTheme.muted)
                                    .padding(.top, 18)
                                    .padding(.leading, 16)
                                    .allowsHitTesting(false)
                            }
                        }

                    Button {
                        Haptics.success()
                        store.updateJournal(for: clock.now, mood: mood, text: text)
                        withAnimation { saved = true }
                    } label: {
                        Label(saved ? "Saved" : "Save entry", systemImage: saved ? "checkmark.circle.fill" : "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .liquidGlassButton(prominent: true)
                    .tint(LifeGridTheme.green)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
                .lifePanel()
                .padding(.horizontal, LGSpacing.l)

                recentEntries
            }
            .padding(.bottom, 100)
        }
        .background(AppBackground())
        .onAppear(perform: loadEntry)
        .onChange(of: text) { _, _ in saved = false }
        .onChange(of: mood) { _, _ in saved = false }
    }

    private var moodPicker: some View {
        HStack(spacing: 10) {
            ForEach(Array(moods.enumerated()), id: \.offset) { index, emoji in
                let value = index + 1
                Button {
                    Haptics.soft()
                    withAnimation(.snappy) { mood = value }
                } label: {
                    Text(emoji)
                        .font(.title2)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous)
                                .fill(mood == value ? store.accent.opacity(0.25) : LifeGridTheme.field)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous)
                                .stroke(mood == value ? store.accent : .clear, lineWidth: 1)
                        )
                        .opacity(mood == value ? 1 : 0.6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Mood \(value)"))
            }
        }
    }

    private var recentEntries: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent entries")
                .font(.headline)
                .foregroundStyle(.white)
            if store.journal.isEmpty {
                Text("No journal entries yet.")
                    .foregroundStyle(LifeGridTheme.secondary)
            } else {
                ForEach(store.journal.sorted { $0.date > $1.date }.prefix(8)) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.date.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(moods[min(max(entry.mood - 1, 0), 4)])
                                .font(.subheadline)
                        }
                        Text(entry.text)
                            .font(.subheadline)
                            .foregroundStyle(LifeGridTheme.secondary)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteJournal(on: entry.date.date)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    Divider().background(LifeGridTheme.stroke)
                }
            }
        }
        .padding(16)
        .lifePanel()
        .padding(.horizontal, LGSpacing.l)
    }

    private func loadEntry() {
        let entry = store.journalEntry(on: clock.now)
        mood = entry?.mood ?? 4
        text = entry?.text ?? ""
    }
}
