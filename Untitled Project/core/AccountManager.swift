import Foundation
import SwiftUI
import Combine

// MARK: - User Account Model
public struct UserAccount: Identifiable, Codable, Equatable {
    public var id: UUID
    public var username: String
    public var email: String?
    public var avatarIcon: String
    public var avatarColor: String
    public var setupMode: String // "classic" or "debrid"
    public var debridApiKey: String?
    public var preferredQuality: String // "4k", "1080p", "720p"
    public var preferredLanguage: String // "en", "tr", "fr", "de"
    public var isGuest: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        username: String,
        email: String? = nil,
        avatarIcon: String = "person.fill",
        avatarColor: String = "purple",
        setupMode: String = "debrid",
        debridApiKey: String? = nil,
        preferredQuality: String = "4k",
        preferredLanguage: String = "en",
        isGuest: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarIcon = avatarIcon
        self.avatarColor = avatarColor
        self.setupMode = setupMode
        self.debridApiKey = debridApiKey
        self.preferredQuality = preferredQuality
        self.preferredLanguage = preferredLanguage
        self.isGuest = isGuest
        self.createdAt = createdAt
    }
}

// MARK: - Account Manager
@MainActor
public class AccountManager: ObservableObject {
    public static let shared = AccountManager()

    private let storageKey = "Somnius_User_Accounts_v2"
    private let activeAccountIdKey = "Somnius_Active_Account_ID_v2"

    @Published public private(set) var accounts: [UserAccount] = []
    @Published public private(set) var activeAccount: UserAccount?
    @Published public var showAccountModal: Bool = false
    @Published public var isSwitchingProfile: Bool = false
    @Published public var switchingProfileTarget: UserAccount? = nil

    public static let availableAvatarIcons = [
        "person.fill",
        "sparkles",
        "film.fill",
        "moon.stars.fill",
        "bolt.fill",
        "play.tv.fill",
        "crown.fill",
        "star.fill",
        "flame.fill",
        "popcorn.fill"
    ]

    public static let availableAvatarColors = [
        "purple",
        "blue",
        "cyan",
        "green",
        "orange",
        "pink",
        "red",
        "yellow"
    ]

    private init() {
        loadAccounts()
    }

    // MARK: - Persistence
    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([UserAccount].self, from: data)
            self.accounts = decoded

            if let activeIdStr = UserDefaults.standard.string(forKey: activeAccountIdKey),
               let activeId = UUID(uuidString: activeIdStr),
               let found = accounts.first(where: { $0.id == activeId }) {
                self.activeAccount = found
                applyAccountSettings(found)
            } else if let first = accounts.first {
                self.activeAccount = first
                applyAccountSettings(first)
            }
        } catch {
            print("Failed to decode accounts: \(error.localizedDescription)")
        }
    }

    private func saveAccounts() {
        do {
            let data = try JSONEncoder().encode(accounts)
            UserDefaults.standard.set(data, forKey: storageKey)
            if let active = activeAccount {
                UserDefaults.standard.set(active.id.uuidString, forKey: activeAccountIdKey)
            }
        } catch {
            print("Failed to encode accounts: \(error.localizedDescription)")
        }
    }

    // MARK: - Account Management
    public func createAccount(
        username: String,
        email: String? = nil,
        avatarIcon: String,
        avatarColor: String,
        setupMode: String,
        debridApiKey: String?,
        preferredQuality: String = "4k",
        preferredLanguage: String = "en",
        isGuest: Bool = false
    ) -> UserAccount {
        let trimmedKey = debridApiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = UserAccount(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email?.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarIcon: avatarIcon,
            avatarColor: avatarColor,
            setupMode: setupMode,
            debridApiKey: (trimmedKey?.isEmpty == false) ? trimmedKey : nil,
            preferredQuality: preferredQuality,
            preferredLanguage: preferredLanguage,
            isGuest: isGuest
        )

        accounts.append(account)
        saveAccounts()
        switchAccountWithTransition(account)
        return account
    }

    public func selectAccount(_ account: UserAccount) {
        self.activeAccount = account
        UserDefaults.standard.set(account.id.uuidString, forKey: activeAccountIdKey)
        applyAccountSettings(account)
        Config.hasCompletedOnboarding = true
        WatchlistManager.shared.reloadForCurrentProfile()
    }

    public func switchAccountWithTransition(_ account: UserAccount) {
        self.switchingProfileTarget = account
        self.isSwitchingProfile = true
        self.showAccountModal = false

        Task { @MainActor in
            // Exactly 1.2 second elegant transition so user clearly notices profile switch
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.selectAccount(account)
            withAnimation(.easeInOut(duration: 0.35)) {
                self.isSwitchingProfile = false
                self.switchingProfileTarget = nil
            }
        }
    }

    public func updateAccount(_ updated: UserAccount) {
        if let idx = accounts.firstIndex(where: { $0.id == updated.id }) {
            accounts[idx] = updated
            if activeAccount?.id == updated.id {
                activeAccount = updated
                applyAccountSettings(updated)
            }
            saveAccounts()
        }
    }

    public func deleteAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        if activeAccount?.id == id {
            activeAccount = accounts.first
            if let active = activeAccount {
                applyAccountSettings(active)
            }
        }
        saveAccounts()
    }

    private func applyAccountSettings(_ account: UserAccount) {
        Config.streamingSetupMode = account.setupMode
        let key = account.debridApiKey ?? ""
        Config.realDebridApiKey = key
        Config.preferredStreamQuality = account.preferredQuality
        Config.preferredSubtitleLanguage = account.preferredLanguage

        // Update installed add-ons with this profile's key
        Task { @MainActor in
            await StremioAddonManager.shared.updateDebridForInstalledAddons(debridKey: key)
        }
    }

    public static func colorForName(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "purple": return Color.purple
        case "blue": return Color.blue
        case "cyan": return Color.cyan
        case "green": return Color.green
        case "orange": return Color.orange
        case "pink": return Color.pink
        case "red": return Color.red
        case "yellow": return Color.yellow
        default: return Color.purple
        }
    }
}
