import SwiftUI

@main
struct Untitled_ProjectApp: App {
    @StateObject private var updater = AppUpdater.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .onAppear {
                    DispatchQueue.main.async {
                        if let window = NSApp.keyWindow ?? NSApp.windows.first {
                            window.titlebarAppearsTransparent = true
                            window.styleMask.insert(.fullSizeContentView)
                        }
                    }
                }
                #endif
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView()
            }
        }
    }
}

