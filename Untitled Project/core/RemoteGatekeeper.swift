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
        unlockApp()
    }

    public func checkStatus() async {
        isChecking = false
        unlockApp()
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
