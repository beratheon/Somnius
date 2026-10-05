import Foundation
import SwiftUI

// MARK: - Ad Placement Enumeration
public enum AdPlacement: String, Codable, CaseIterable, Sendable {
    case setupScreen = "setup_screen"
    case playerLoading = "player_loading"
}

// MARK: - Ad Content Model
public struct AdItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let callToAction: String
    public let destinationUrl: URL?
    public let bannerImageUrl: URL?
    public let iconSystemName: String?
    public let networkName: String
    public let isSponsored: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        callToAction: String = "Learn More",
        destinationUrl: URL? = nil,
        bannerImageUrl: URL? = nil,
        iconSystemName: String? = "sparkles",
        networkName: String = "AdEx Network",
        isSponsored: Bool = true
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.callToAction = callToAction
        self.destinationUrl = destinationUrl
        self.bannerImageUrl = bannerImageUrl
        self.iconSystemName = iconSystemName
        self.networkName = networkName
        self.isSponsored = isSponsored
    }
}

// MARK: - AdProvider Protocol
/// Network-agnostic protocol allowing easy replacement with real SDKs (e.g. AdEx, AppLovin, custom DSP).
public protocol AdProvider: AnyObject, Sendable {
    var name: String { get }
    func initialize(apiKey: String, config: [String: Any]) async throws
    func requestAd(for placement: AdPlacement) async -> AdItem?
    func recordImpression(for ad: AdItem, placement: AdPlacement)
    func recordClick(for ad: AdItem, placement: AdPlacement)
}

// MARK: - MockAdProvider Implementation
/// Default implementation that logs events to console and provides non-blocking mock creatives.
public final class MockAdProvider: AdProvider, @unchecked Sendable {
    public let name: String = "MockAdProvider (SDK Scaffold)"
    private var isInitialized: Bool = false

    public init() {}

    public func initialize(apiKey: String, config: [String: Any]) async throws {
        // [SDK Integration Point]: Call real ad network SDK initialization here
        print("📢 [AdProvider: \(name)] Initialized with API Key: \(apiKey.prefix(6))... Config: \(config.keys)")
        isInitialized = true
    }

    public func requestAd(for placement: AdPlacement) async -> AdItem? {
        guard isInitialized else {
            print("⚠️ [AdProvider: \(name)] requestAd called before initialization.")
            return nil
        }

        // [SDK Integration Point]: Replace with network SDK ad request (e.g. AdEx.requestBanner / interstitial)
        switch placement {
        case .setupScreen:
            return AdItem(
                id: "mock_setup_sponsor_01",
                title: "Somnius Cloud Engine",
                subtitle: "Experience ultra-fast 4K HDR playback and uncapped throughput across your devices.",
                callToAction: "Discover",
                destinationUrl: URL(string: "https://real-debrid.com/?id=10141263"),
                bannerImageUrl: nil,
                iconSystemName: "bolt.badge.automatic.fill",
                networkName: "AdEx Partner Network"
            )

        case .playerLoading:
            return AdItem(
                id: "mock_buffer_sponsor_02",
                title: "Sponsored by UltraVPN",
                subtitle: "High-speed encrypted streaming with zero ISP throttling.",
                callToAction: "Explore",
                destinationUrl: URL(string: "https://1.1.1.1"),
                bannerImageUrl: nil,
                iconSystemName: "shield.lefthalf.filled.badge.checkmark",
                networkName: "AdEx Partner Network"
            )
        }
    }

    public func recordImpression(for ad: AdItem, placement: AdPlacement) {
        // [SDK Integration Point]: Fire network SDK impression tracking beacon
        print("📈 [AdProvider: \(name)] Impression tracked for '\(ad.title)' [\(placement.rawValue)]")
    }

    public func recordClick(for ad: AdItem, placement: AdPlacement) {
        // [SDK Integration Point]: Fire network SDK click tracking beacon
        print("🖱️ [AdProvider: \(name)] Click tracked for '\(ad.title)' [\(placement.rawValue)] -> \(ad.destinationUrl?.absoluteString ?? "no-url")")
    }
}
