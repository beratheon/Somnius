import Foundation
import SwiftUI
import Combine

// MARK: - Ad Configuration Model
public struct AdConfigData: Codable, Sendable {
    public var enabled: Bool
    public var provider: String
    public var apiKey: String
    public var cooldowns: [String: Int] // Placement key -> Cooldown in minutes
    public var supportAdsToggleDefault: Bool

    public static let `default` = AdConfigData(
        enabled: true,
        provider: "mock",
        apiKey: "MOCK_ADEX_KEY_SOMNIUS_2026",
        cooldowns: [
            AdPlacement.setupScreen.rawValue: 5,
            AdPlacement.playerLoading.rawValue: 2
        ],
        supportAdsToggleDefault: true
    )
}

// MARK: - Ad Log Record (For Reconciliation)
public struct AdTelemetryRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let adId: String
    public let placement: String
    public let eventType: String // "impression" or "click"
    public let timestamp: Date

    public init(id: UUID = UUID(), adId: String, placement: String, eventType: String, timestamp: Date = Date()) {
        self.id = id
        self.adId = adId
        self.placement = placement
        self.eventType = eventType
        self.timestamp = timestamp
    }
}

// MARK: - AdPlacementManager
@MainActor
public final class AdPlacementManager: ObservableObject {
    public static let shared = AdPlacementManager()

    // MARK: User Settings
    private let userAdsToggleKey = "somnius_support_ads_enabled_v1"
    private let telemetryStorageKey = "somnius_ad_telemetry_records_v1"

    @Published public var isAdsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAdsEnabled, forKey: userAdsToggleKey)
        }
    }

    // Active Ads per Placement
    @Published public private(set) var activeSetupAd: AdItem? = nil
    @Published public private(set) var activePlayerLoadingAd: AdItem? = nil

    // Cooldown state
    private var lastShownTimestamps: [AdPlacement: Date] = [:]
    private var provider: AdProvider
    private var config: AdConfigData

    private init() {
        // Load configuration file
        self.config = Self.loadConfiguration()

        // User preference (default true unless user turned off)
        if UserDefaults.standard.object(forKey: userAdsToggleKey) != nil {
            self.isAdsEnabled = UserDefaults.standard.bool(forKey: userAdsToggleKey)
        } else {
            self.isAdsEnabled = config.supportAdsToggleDefault
        }

        // Initialize provider (swappable with actual SDK)
        let mock = MockAdProvider()
        self.provider = mock

        Task {
            try? await mock.initialize(apiKey: self.config.apiKey, config: ["provider": self.config.provider])
        }
    }

    // MARK: - Configuration Loader
    private static func loadConfiguration() -> AdConfigData {
        // 1. Look in main bundle
        if let url = Bundle.main.url(forResource: "AdConfig", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AdConfigData.self, from: data) {
            return decoded
        }

        // 2. Look in application support / workspace directory
        let localPath = FileManager.default.currentDirectoryPath + "/Untitled Project/Resources/AdConfig.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: localPath)),
           let decoded = try? JSONDecoder().decode(AdConfigData.self, from: data) {
            return decoded
        }

        return AdConfigData.default
    }

    // MARK: - Placement Eligibility
    public func isEligible(for placement: AdPlacement) -> Bool {
        guard config.enabled else { return false }
        guard isAdsEnabled else { return false }

        let cooldownMinutes = config.cooldowns[placement.rawValue] ?? 2
        if let lastShown = lastShownTimestamps[placement] {
            let elapsed = Date().timeIntervalSince(lastShown)
            if elapsed < Double(cooldownMinutes * 60) {
                return false // Still in cooldown
            }
        }
        return true
    }

    // MARK: - Request and Display Ads
    @discardableResult
    public func maybeShowAd(for placement: AdPlacement) async -> AdItem? {
        guard isEligible(for: placement) else {
            return nil
        }

        // Fetch ad item from current provider
        if let ad = await provider.requestAd(for: placement) {
            lastShownTimestamps[placement] = Date()
            switch placement {
            case .setupScreen:
                self.activeSetupAd = ad
            case .playerLoading:
                self.activePlayerLoadingAd = ad
            }
            recordImpression(for: ad, placement: placement)
            return ad
        }
        return nil
    }

    public func dismissAd(for placement: AdPlacement) {
        switch placement {
        case .setupScreen:
            self.activeSetupAd = nil
        case .playerLoading:
            self.activePlayerLoadingAd = nil
        }
    }

    // MARK: - Telemetry & Reconciliation
    public func recordImpression(for ad: AdItem, placement: AdPlacement) {
        provider.recordImpression(for: ad, placement: placement)
        logTelemetry(adId: ad.id, placement: placement.rawValue, eventType: "impression")
    }

    public func recordClick(for ad: AdItem, placement: AdPlacement) {
        provider.recordClick(for: ad, placement: placement)
        logTelemetry(adId: ad.id, placement: placement.rawValue, eventType: "click")

        if let dest = ad.destinationUrl {
            NSWorkspace.shared.open(dest)
        }
    }

    private func logTelemetry(adId: String, placement: String, eventType: String) {
        var existing: [AdTelemetryRecord] = []
        if let data = UserDefaults.standard.data(forKey: telemetryStorageKey),
           let decoded = try? JSONDecoder().decode([AdTelemetryRecord].self, from: data) {
            existing = decoded
        }
        existing.append(AdTelemetryRecord(adId: adId, placement: placement, eventType: eventType))
        // Cap telemetry array to last 500 records
        if existing.count > 500 {
            existing.removeFirst(existing.count - 500)
        }
        if let encoded = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(encoded, forKey: telemetryStorageKey)
        }
    }

    // MARK: - Swappable Provider Setter (For future SDK wiring)
    public func setProvider(_ newProvider: AdProvider) {
        self.provider = newProvider
    }
}

// MARK: - Reusable Non-Intrusive Ad Banner Views
public struct AdBannerCardView: View {
    let ad: AdItem
    let placement: AdPlacement
    var onDismiss: (() -> Void)? = nil

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: ad.iconSystemName ?? "sparkles")
                    .font(.system(size: 16))
                    .foregroundColor(Color.cyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("SPONSORED")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white.opacity(0.7))
                        .clipShape(Capsule())

                    Text(ad.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                if let subtitle = ad.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Call to action button
            Button(action: {
                AdPlacementManager.shared.recordClick(for: ad, placement: placement)
            }) {
                HStack(spacing: 4) {
                    Text(ad.callToAction)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.2))
                .foregroundColor(Color.cyan)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.13).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
