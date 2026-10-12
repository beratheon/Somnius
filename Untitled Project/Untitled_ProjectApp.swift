import SwiftUI
#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        AggregatorService.stopAndCleanAllTorrentMissions()
    }
}
#endif

@main
struct Untitled_ProjectApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
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

