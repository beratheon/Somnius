import Foundation
import SwiftUI
import AppKit
import Combine

// MARK: - Somnius Non-Blocking Update Notifier
@MainActor
public final class RemoteGatekeeper: ObservableObject {
    public static let shared = RemoteGatekeeper()

    @Published public var isLocked: Bool = false // Never lock the app
    @Published public var hasUpdateAvailable: Bool = false
    @Published public var updateVersion: String = ""
    @Published public var updateReleaseNotes: String = "A new version of Somnius is ready to install."
    @Published public var downloadURL: URL = URL(string: "https://github.com/beratheon/Somnius/releases/latest")!
    @Published public var showUpdateModal: Bool = false
    
    private var hasDismissedForThisSession: Bool = false

    private init() {
        self.isLocked = false
        Task { [weak self] in
            await self?.checkStatus()
        }
    }

    public func checkStatus() async {
        guard !hasDismissedForThisSession else { return }
        
        // Query GitHub releases API for latest release version
        let repo = Config.updateRepository.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repo.isEmpty, let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            return
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 5.0
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("Somnius-App", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            
            struct GHRelease: Decodable {
                let tag_name: String
                let name: String?
                let body: String?
                let html_url: String?
            }
            
            let release = try JSONDecoder().decode(GHRelease.self, from: data)
            let latestTag = release.tag_name.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let currentVer = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isVersion(currentVer, olderThan: latestTag) {
                self.hasUpdateAvailable = true
                self.updateVersion = release.tag_name
                if let body = release.body, !body.isEmpty {
                    self.updateReleaseNotes = body
                }
                if let html = release.html_url, let dUrl = URL(string: html) {
                    self.downloadURL = dUrl
                }
                if !self.hasDismissedForThisSession {
                    self.showUpdateModal = true
                }
            }
        } catch {
            // Quiet fallback, no disruptive errors
        }
    }

    public func dismissUntilNextLaunch() {
        self.hasDismissedForThisSession = true
        self.showUpdateModal = false
    }

    private func isVersion(_ v1: String, olderThan v2: String) -> Bool {
        return v1.compare(v2, options: .numeric) == .orderedAscending
    }
}

// MARK: - Somnius Sleek Non-Blocking Update Dialog
public struct RemoteGatekeeperLockView: View {
    @ObservedObject var gatekeeper: RemoteGatekeeper = .shared

    public init() {}

    public var body: some View {
        if gatekeeper.showUpdateModal {
            ZStack {
                Color.black.opacity(0.55)
                    .background(.ultraThinMaterial.opacity(0.4))
                    .ignoresSafeArea()
                    .onTapGesture {
                        gatekeeper.dismissUntilNextLaunch()
                    }

                VStack(spacing: 20) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )

                        Image(systemName: "sparkles")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 8) {
                        Text("Somnius Update Available")
                            .font(.custom("Baskerville", size: 24))
                            .foregroundColor(.white)

                        Text("A new release (\(gatekeeper.updateVersion)) is ready. Enjoy new player controls, refined subtitles, and improved stability.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 380)
                    }

                    HStack(spacing: 14) {
                        // Install Now
                        Button(action: {
                            #if os(macOS)
                            NSWorkspace.shared.open(gatekeeper.downloadURL)
                            #endif
                            AppUpdater.shared.checkForUpdates()
                            gatekeeper.showUpdateModal = false
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Install Now")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        // Remind Me Later
                        Button(action: {
                            gatekeeper.dismissUntilNextLaunch()
                        }) {
                            Text("Remind Me Later")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 12)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .zIndex(9999)
        }
    }
}
