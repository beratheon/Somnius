import Foundation
import SwiftUI
import AppKit
import Combine

// MARK: - Remote Gatekeeper & Beta Kill-Switch Service
@MainActor
public final class RemoteGatekeeper: ObservableObject {
    public static let shared = RemoteGatekeeper()

    @Published public var isLocked: Bool = false
    @Published public var lockTitle: String = "Beta Access Concluded"
    @Published public var lockMessage: String = "This preview build is no longer supported or active. Please download the latest release to continue using Somnius."
    @Published public var downloadURL: URL = URL(string: "https://github.com/beratheon/Somnius/releases/latest")!
    @Published public var isChecking: Bool = false

    private let localLockKey = "Somnius_RemoteGatekeeper_IsLocked"
    private let localTitleKey = "Somnius_RemoteGatekeeper_LockTitle"
    private let localMessageKey = "Somnius_RemoteGatekeeper_LockMessage"
    private let localURLKey = "Somnius_RemoteGatekeeper_LockURL"

    // Hard local failsafe: 90 days from Oct 10, 2026 (Jan 8, 2027)
    // Ensures that even if users completely sever network connections, expired beta builds terminate cleanly
    private let hardLocalExpiryDate: Date = {
        var comps = DateComponents()
        comps.year = 2027
        comps.month = 1
        comps.day = 8
        return Calendar.current.date(from: comps) ?? Date.distantFuture
    }()

    private var pollTimer: Timer?

    private init() {
        // Restore locally cached lock state if previously marked locked
        if UserDefaults.standard.bool(forKey: localLockKey) {
            self.isLocked = true
            if let savedTitle = UserDefaults.standard.string(forKey: localTitleKey), !savedTitle.isEmpty {
                self.lockTitle = savedTitle
            }
            if let savedMsg = UserDefaults.standard.string(forKey: localMessageKey), !savedMsg.isEmpty {
                self.lockMessage = savedMsg
            }
            if let savedURL = UserDefaults.standard.string(forKey: localURLKey), let u = URL(string: savedURL) {
                self.downloadURL = u
            }
        }

        // Check local failsafe
        if Date() > hardLocalExpiryDate {
            self.lockApp(
                title: "Beta Period Expired",
                message: "This test build has reached its expiration date. Please download the latest update.",
                url: URL(string: "https://github.com/beratheon/Somnius/releases/latest")!
            )
        }

        // Run remote check on startup
        Task {
            await checkStatus()
        }

        // Poll every 15 minutes while app is running
        self.pollTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkStatus()
            }
        }
    }

    public func checkStatus() async {
        isChecking = true
        defer { isChecking = false }

        // Local hard expiry check
        if Date() > hardLocalExpiryDate {
            lockApp(
                title: "Beta Period Expired",
                message: "This preview build has reached its expiration date. Please download the latest release to continue.",
                url: URL(string: "https://github.com/beratheon/Somnius/releases/latest")!
            )
            return
        }

        let repo = Config.updateRepository.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repo.isEmpty else { return }

        let remoteConfigURLString = "https://raw.githubusercontent.com/\(repo)/main/app_status.json"
        guard let url = URL(string: remoteConfigURLString) else { return }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 6.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }

            struct AppStatusPayload: Decodable {
                let kill_switch: Bool?
                let beta_active: Bool?
                let min_version: String?
                let title: String?
                let message: String?
                let download_url: String?
                let hard_expiry_timestamp: Double?
            }

            guard let payload = try? JSONDecoder().decode(AppStatusPayload.self, from: data) else {
                return
            }

            let title = payload.title ?? "Beta Access Concluded"
            let message = payload.message ?? "This preview build is no longer supported or active. Please download the latest release to continue."
            let actionURL = payload.download_url.flatMap { URL(string: $0) } ?? URL(string: "https://github.com/beratheon/Somnius/releases/latest")!

            // 1. Direct kill switch
            if payload.kill_switch == true {
                lockApp(title: title, message: message, url: actionURL)
                return
            }

            // 2. Beta inactive
            if payload.beta_active == false {
                lockApp(title: title, message: message, url: actionURL)
                return
            }

            // 3. Minimum supported version check
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            if let minVersion = payload.min_version, !minVersion.isEmpty {
                if isVersion(currentVersion, olderThan: minVersion) {
                    lockApp(
                        title: "Update Required",
                        message: "Version \(minVersion) or newer is required to use Somnius. You are currently running \(currentVersion).",
                        url: actionURL
                    )
                    return
                }
            }

            // 4. Remote hard expiry timestamp
            if let expiryTS = payload.hard_expiry_timestamp, expiryTS > 0 {
                if Date().timeIntervalSince1970 > expiryTS {
                    lockApp(title: title, message: message, url: actionURL)
                    return
                }
            }

            // If everything passes, unlock (if previously locked and admin restored it)
            unlockApp()
        } catch {
            // Network failure: keep existing cached state
        }
    }

    private func lockApp(title: String, message: String, url: URL) {
        self.isLocked = true
        self.lockTitle = title
        self.lockMessage = message
        self.downloadURL = url

        UserDefaults.standard.set(true, forKey: localLockKey)
        UserDefaults.standard.set(title, forKey: localTitleKey)
        UserDefaults.standard.set(message, forKey: localMessageKey)
        UserDefaults.standard.set(url.absoluteString, forKey: localURLKey)
    }

    private func unlockApp() {
        self.isLocked = false
        UserDefaults.standard.removeObject(forKey: localLockKey)
        UserDefaults.standard.removeObject(forKey: localTitleKey)
        UserDefaults.standard.removeObject(forKey: localMessageKey)
        UserDefaults.standard.removeObject(forKey: localURLKey)
    }

    private func isVersion(_ v1: String, olderThan v2: String) -> Bool {
        return v1.compare(v2, options: .numeric) == .orderedAscending
    }
}

// MARK: - Native Lockout Full-Screen Overlay View
public struct RemoteGatekeeperLockView: View {
    @ObservedObject var gatekeeper: RemoteGatekeeper = .shared

    public init() {}

    public var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()

            // Subtle dark radial gradient
            RadialGradient(
                colors: [
                    Color(red: 0.75, green: 0.15, blue: 0.15).opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.9, green: 0.2, blue: 0.2).opacity(0.12))
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle().stroke(Color(red: 0.9, green: 0.2, blue: 0.2).opacity(0.35), lineWidth: 1.5)
                        )

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                }

                VStack(spacing: 10) {
                    Text(gatekeeper.lockTitle)
                        .font(.custom("Baskerville", size: 28).weight(.bold))
                        .foregroundColor(.white)

                    Text(gatekeeper.lockMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                        .lineSpacing(4)
                }

                HStack(spacing: 14) {
                    Button(action: {
                        NSWorkspace.shared.open(gatekeeper.downloadURL)
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Latest Version")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                            Text("Quit Somnius")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white.opacity(0.85))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .zIndex(9999)
    }
}
