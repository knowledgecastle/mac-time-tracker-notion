import SwiftUI

@main
struct TimeTrackerApp: App {
    @StateObject private var store = AppStore()

    init() {
        // Ask for notification permission up front so reminders can fire later.
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 700, idealWidth: 900, minHeight: 650, idealHeight: 750)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Menu bar item — shows the running timer and lets you start/stop
        // and switch tasks without opening the main window.
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
