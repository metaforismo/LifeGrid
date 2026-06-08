import SwiftUI

@main
struct LifeGridApp: App {
    @State private var store = AppStore()
    @State private var clock = CurrentDateTicker()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
                .environment(clock)
                .preferredColorScheme(.dark)
                .task {
                    // Wire the "Mark done" notification action and re-register
                    // any scheduled reminders for the current goals.
                    NotificationManager.shared.configure { goalID in
                        store.markCompleteFromReminder(goalID)
                    }
                    NotificationManager.shared.sync(
                        goals: store.goals,
                        dailyReminder: store.settings.dailyReminder
                    )
                }
        }
    }
}
