import SwiftUI

@main
struct Untitled_ProjectApp: App {
    @StateObject private var updater = AppUpdater.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView()
            }
        }
    }
}

