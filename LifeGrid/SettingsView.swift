import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var confirmReset = false
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var pendingImport: Data?
    @State private var confirmImport = false
    @State private var importError = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        @Bindable var store = store
        return NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    appearanceCard(store: store)
                    preferencesCard(store: store)
                    dataCard
                    privacyCard
                    aboutCard
                }
                .padding(22)
            }
            .background(AppBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: prepareExport)
            .onChange(of: store.settings) { _, _ in
                store.persistSettings()
                NotificationManager.shared.sync(goals: store.goals, dailyReminder: store.settings.dailyReminder)
                prepareExport()
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImportResult(result)
            }
            .confirmationDialog("Reset all data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    store.resetAllData()
                    NotificationManager.shared.sync(goals: store.goals, dailyReminder: store.settings.dailyReminder)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This restores the sample data and restarts the welcome flow. This can't be undone.")
            }
            .confirmationDialog("Replace all data?", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("Import", role: .destructive) { performImport() }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("Importing replaces everything currently in the app with the backup's contents.")
            }
            .alert("Couldn't read that file", isPresented: $importError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The selected file isn't a valid LifeGrid backup.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Appearance

    private func appearanceCard(store: AppStore) -> some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 14) {
            Text("Appearance")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Accent color")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeGridTheme.secondary)
            HStack(spacing: 14) {
                ForEach(AccentChoice.allCases) { choice in
                    Button {
                        Haptics.soft()
                        store.settings.accent = choice
                    } label: {
                        Circle()
                            .fill(choice.color)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle().stroke(.white, lineWidth: store.settings.accent == choice ? 2.5 : 0)
                            )
                            .overlay(
                                Circle().stroke(LifeGridTheme.stroke, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(choice.title))
                    .accessibilityAddTraits(store.settings.accent == choice ? .isSelected : [])
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifePanel()
    }

    // MARK: - Preferences

    private func preferencesCard(store: AppStore) -> some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.headline)
                .foregroundStyle(.white)

            HStack {
                Text("Start week on")
                    .foregroundStyle(.white)
                Spacer()
                Picker("Start week on", selection: $store.settings.firstWeekday) {
                    Text("System").tag(0)
                    Text("Monday").tag(2)
                    Text("Sunday").tag(1)
                }
                .pickerStyle(.menu)
                .tint(store.accent)
            }

            Toggle(isOn: $store.settings.hapticsEnabled) {
                Text("Haptic feedback").foregroundStyle(.white)
            }
            .tint(store.accent)

            Divider().background(LifeGridTheme.stroke)

            Toggle(isOn: reminderBinding(store: store)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily reminder").foregroundStyle(.white)
                    Text("A gentle nudge to check in")
                        .font(.caption).foregroundStyle(LifeGridTheme.secondary)
                }
            }
            .tint(store.accent)

            if let reminder = store.settings.dailyReminder {
                DatePicker(
                    "Reminder time",
                    selection: Binding(
                        get: { reminder },
                        set: { store.settings.dailyReminder = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .foregroundStyle(.white)
                .tint(store.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifePanel()
    }

    private func reminderBinding(store: AppStore) -> Binding<Bool> {
        Binding(
            get: { store.settings.dailyReminder != nil },
            set: { on in
                if on {
                    var comps = DateComponents(); comps.hour = 9; comps.minute = 0
                    store.settings.dailyReminder = Calendar.autoupdatingCurrent.date(from: comps) ?? .now
                    Task { await NotificationManager.shared.ensureAuthorizedThenSync(goals: store.goals, dailyReminder: store.settings.dailyReminder) }
                } else {
                    store.settings.dailyReminder = nil
                }
            }
        )
    }

    // MARK: - Data

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Data")
                .font(.headline)
                .foregroundStyle(.white)

            if let exportURL {
                ShareLink(item: exportURL) {
                    settingsRow(symbol: "square.and.arrow.up", tint: store.accent, title: "Export backup", subtitle: "Save all your data as a JSON file")
                }
                .buttonStyle(.plain)
                Divider().background(LifeGridTheme.stroke)
            }

            Button {
                Haptics.tap()
                showImporter = true
            } label: {
                settingsRow(symbol: "square.and.arrow.down", tint: store.accent, title: "Import backup", subtitle: "Replace data from a JSON file")
            }
            .buttonStyle(.plain)

            Divider().background(LifeGridTheme.stroke)

            Button {
                Haptics.tap()
                store.loadSampleData()
                dismiss()
            } label: {
                settingsRow(symbol: "sparkles", tint: store.accent, title: "Load sample data", subtitle: "Fill the app with example goals and history")
            }
            .buttonStyle(.plain)

            Divider().background(LifeGridTheme.stroke)

            Button {
                confirmReset = true
            } label: {
                settingsRow(symbol: "trash", tint: .red, title: "Reset & restart onboarding", subtitle: "Erase everything and start fresh")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifePanel()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Private by design")
                    .font(.headline)
                    .foregroundStyle(.white)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(LifeGridTheme.green)
            }
            Text("No account, no cloud. Everything you track stays on this device.")
                .font(.subheadline)
                .foregroundStyle(LifeGridTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifePanel()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About")
                .font(.headline)
                .foregroundStyle(.white)
            infoRow("App", value: "LifeGrid")
            Divider().background(LifeGridTheme.stroke)
            infoRow("Version", value: version)
            Divider().background(LifeGridTheme.stroke)
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .foregroundStyle(LifeGridTheme.secondary)
                Text("The app follows your device language (English, Italian).")
                    .font(.caption)
                    .foregroundStyle(LifeGridTheme.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifePanel()
    }

    // MARK: - Helpers

    private func settingsRow(symbol: String, tint: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LifeGridTheme.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeGridTheme.muted)
        }
    }

    private func infoRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .foregroundStyle(LifeGridTheme.secondary)
        }
        .font(.subheadline)
    }

    private func prepareExport() {
        do {
            let data = try store.exportData()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("LifeGrid-backup.json")
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            exportURL = nil
        }
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { importError = true; return }
        pendingImport = data
        confirmImport = true
    }

    private func performImport() {
        guard let data = pendingImport else { return }
        do {
            try store.importData(data)
            NotificationManager.shared.sync(goals: store.goals, dailyReminder: store.settings.dailyReminder)
            pendingImport = nil
            dismiss()
        } catch {
            importError = true
        }
    }
}
