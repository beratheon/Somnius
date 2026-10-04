import Foundation
import SwiftUI
import Combine
import Sparkle

/// Observable updater model managing Sparkle auto-update checks for macOS.
@MainActor
public final class AppUpdater: ObservableObject {
    public static let shared = AppUpdater()

    private let updaterController: SPUStandardUpdaterController

    @Published public var canCheckForUpdates: Bool = false
    @AppStorage("receiveBetaUpdates") public var receiveBetaUpdates: Bool = false {
        didSet {
            configureFeedURL()
        }
    }

    public var updater: SPUUpdater {
        updaterController.updater
    }

    private init() {
        // Initialize Sparkle Standard Updater Controller (runs automatically on launch)
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        self.updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)

        configureFeedURL()
    }

    public func configureFeedURL() {
        // Configurable GitHub repo/owner - defaults to placeholder, ready for user's repository
        let githubRepo = Config.updateRepository.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !githubRepo.isEmpty else { return }

        // Dual-channel update feeds:
        // Stable: https://raw.githubusercontent.com/<owner>/<repo>/main/appcast.xml
        // Beta:   https://raw.githubusercontent.com/<owner>/<repo>/main/appcast-beta.xml
        let channelFile = receiveBetaUpdates ? "appcast-beta.xml" : "appcast.xml"
        let feedString = "https://raw.githubusercontent.com/\(githubRepo)/main/\(channelFile)"

        if let feedURL = URL(string: feedString) {
            updater.setFeedURL(feedURL)
        }
    }

    /// Triggers an interactive "Check for Updates..." dialog.
    public func checkForUpdates() {
        updater.checkForUpdates()
    }
}

/// SwiftUI View to trigger Sparkle update checks with disabled state management.
public struct CheckForUpdatesView: View {
    @ObservedObject var updater: AppUpdater = .shared

    public init() {}

    public var body: some View {
        Button("Check for Updates...") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
