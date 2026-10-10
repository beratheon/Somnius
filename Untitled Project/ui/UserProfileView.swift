import SwiftUI
import AppKit

struct UserProfileView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var watchlistManager = WatchlistManager.shared
    @ObservedObject private var liveCatalogService = LiveCatalogService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: SettingsCategory = .player
    @State private var inputKey: String = Config.realDebridApiKey
    @State private var tvdbInputKey: String = Config.tvdbApiKey
    @State private var tvdbStatusMessage: String?
    @State private var setupMode: String = Config.streamingSetupMode
    @State private var showOnlyCached: Bool = Config.showOnlyCachedResults
    @State private var defaultPlayer: String = Config.defaultPlayerSelection
    @State private var preferredSubLang: String = Config.preferredSubtitleLanguage
    @State private var autoPlayNext: Bool = Config.autoPlayNextEpisode
    @State private var autoPlayMaxSize: Double = Config.autoPlayMaxGbSize
    @State private var autoPlayQuality: String = Config.autoPlayPreferredQuality
    @State private var autoPlayPreferHDR: Bool = Config.autoPlayPreferHDR
    @State private var autoPlayPreferSurround: Bool = Config.autoPlayPreferSurround
    @State private var autoPlayCachedOnly: Bool = Config.autoPlayCachedOnly
    @State private var autoPlaySkipShortClips: Bool = Config.autoPlaySkipShortClips
    @State private var bufferSeconds: Double = Config.bufferAheadSeconds
    @State private var preferredQuality: String = Config.preferredStreamQuality
    @State private var subtitleColor: String = Config.subtitleColorPreference
    @State private var subtitleFontSize: Double = Double(Config.subtitleFontSizePreference)
    @State private var staticSubtitles: Bool = Config.staticSubtitles
    @State private var fastStartBuffering: Bool = Config.fastStartBuffering

    @AppStorage("enableExternalAudioInjection") var enableExternalAudioInjection: Bool = true
    @AppStorage("preferredAudioLanguage") var preferredAudioLanguage: String = "tr"
    @AppStorage("enablePALSpeedupCorrection") var enablePALSpeedupCorrection: Bool = true

    @ObservedObject private var addonManager = StremioAddonManager.shared
    @State private var newAddonUrlInput: String = ""
    @State private var addonInstallError: String? = nil

    @State private var statusMessage: String?
    @State private var isRefreshingCloud: Bool = false
    @State private var showImportSheet: Bool = false
    @State private var importJsonText: String = ""
    @State private var showExportAlert: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var showAddCatalogSheet: Bool = false
    @State private var configuredAddonForSheet: InstalledAddon? = nil
    @State private var affiliateIdInput: String = Config.realDebridAffiliateId
    @State private var affiliateUrlInput: String = Config.realDebridAffiliateUrlString
    @State private var showAffiliateSettings: Bool = false
    @ObservedObject private var adManager = AdPlacementManager.shared
    @ObservedObject private var accountManager = AccountManager.shared

    var isEmbeddedPage: Bool = false
    var onSelectMediaItem: (MediaItem) -> Void
    var onSelectTorrentLink: (String) -> Void

    enum SettingsCategory: String, CaseIterable, Identifiable {
        case setupMode = "Setup & Engine"
        case debridAccount = "Debrid Account"
        case player = "Player & Buffering"
        case subtitles = "Subtitles"
        case audioLanguage = "Audio & Language"
        case streaming = "Sources & Quality"
        case addons = "Add-ons"
        case catalogs = "Catalogs"
        case cloud = "Debrid Cloud"
        case watchlist = "Watchlist & History"
        case updates = "Updates & Beta"
        case monetization = "Support & Ads"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .setupMode: return "gearshape.2.fill"
            case .debridAccount: return "key.fill"
            case .player: return "play.tv.fill"
            case .subtitles: return "captions.bubble.fill"
            case .audioLanguage: return "waveform"
            case .streaming: return "sparkles.tv"
            case .addons: return "puzzlepiece.extension.fill"
            case .catalogs: return "square.stack.3d.up.fill"
            case .cloud: return "icloud.fill"
            case .watchlist: return "bookmark.fill"
            case .updates: return "arrow.triangle.2.circlepath.circle.fill"
            case .monetization: return "heart.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Settings Sidebar
            VStack(alignment: .leading, spacing: 6) {
                // Window Header
                HStack(spacing: 12) {
                    // Claude-like minimalist full moon icon (matching Somnius aesthetic)
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [Color.white, Color(white: 0.85)]),
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 10
                                )
                            )
                            .frame(width: 19, height: 19)
                            .shadow(color: Color.white.opacity(0.4), radius: 5, x: 0, y: 0)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Settings")
                            .font(.custom("Baskerville", size: 21))
                            .foregroundColor(.white)
                        Text("Preferences & Add-ons")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.08))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(SettingsCategory.allCases.filter { cat in
                            if cat == .setupMode { return false } // Replaced by clean player defaults
                            if cat == .debridAccount || cat == .cloud {
                                // Only show if user has an active configured token from their add-on
                                return !Config.realDebridApiKey.isEmpty
                            }
                            return true
                        }) { cat in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = cat
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: cat.icon)
                                        .font(.subheadline)
                                        .frame(width: 20)
                                        .foregroundColor(selectedCategory == cat ? .white : .white.opacity(0.55))

                                    Text(cat.rawValue)
                                        .font(.subheadline.weight(selectedCategory == cat ? .semibold : .regular))
                                        .foregroundColor(selectedCategory == cat ? .white : .white.opacity(0.8))

                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(selectedCategory == cat ? Color.white.opacity(0.12) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    selectedCategory == cat ?
                                        RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 0.8) : nil
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                Spacer()

                // Return / Close Button (Only when presented as modal sheet)
                if !isEmbeddedPage {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                            Text("Back to App")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
            .frame(width: 250)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.95))

            Divider().background(Color.white.opacity(0.08))

            // MARK: - Right Detailed Content Pane
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // Pane Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedCategory.rawValue)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text(categorySubtitle(selectedCategory))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 6)

                    // Dynamic Section View
                    switch selectedCategory {
                    case .setupMode:
                        setupModeView
                    case .debridAccount:
                        debridAccountView
                    case .player:
                        playerBufferingView
                    case .subtitles:
                        subtitlesSettingsView
                    case .audioLanguage:
                        audioLanguageSettingsView
                    case .streaming:
                        sourcesQualityView
                    case .addons:
                        stremioAddonsView
                    case .catalogs:
                        catalogsManagementView
                    case .cloud:
                        debridCloudView
                    case .watchlist:
                        watchlistHistoryView
                    case .updates:
                        updatesBetaView
                    case .monetization:
                        monetizationAdsSettingsView
                    }
                }
                .padding(26)
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        }
        .frame(
            minWidth: isEmbeddedPage ? nil : 1100,
            idealWidth: isEmbeddedPage ? nil : 1400,
            maxWidth: .infinity,
            minHeight: isEmbeddedPage ? nil : 720,
            idealHeight: isEmbeddedPage ? nil : 900,
            maxHeight: .infinity
        )
        .clipShape(RoundedRectangle(cornerRadius: isEmbeddedPage ? 0 : 22, style: .continuous))
        .overlay(
            Group {
                if !isEmbeddedPage {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
            }
        )
        .shadow(color: isEmbeddedPage ? .clear : .black.opacity(0.85), radius: isEmbeddedPage ? 0 : 36, x: 0, y: isEmbeddedPage ? 0 : 18)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showImportSheet) {
            importCatalogsSheet
        }
        .sheet(isPresented: $showAddCatalogSheet) {
            addCatalogSheet
        }
        .sheet(item: $configuredAddonForSheet) { addon in
            AddonSettingsModalView(addon: addon) {
                configuredAddonForSheet = nil
                viewModel.fetchContent()
            }
        }
        .alert("Catalogs Exported", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The current active catalogs configuration has been copied to your clipboard as JSON.")
        }
    }

    private func categorySubtitle(_ category: SettingsCategory) -> String {
        switch category {
        case .setupMode: return "Switch between Classic P2P and Real-Debrid streaming engines"
        case .debridAccount: return "Configure and inspect your Real-Debrid API credentials"
        case .player: return "Tune hardware decoding, instant start, and buffer durations"
        case .subtitles: return "Static subtitle rendering, sizes, and default languages"
        case .audioLanguage: return "Audio stream settings, PAL speedup correction, and lip-sync calibration"
        case .streaming: return "Preferred resolutions, seed filters, and cache controls"
        case .addons: return "Manage external stream add-ons and manifest extensions"
        case .catalogs: return "Manage live catalogs, import/export configurations, or remove sections"
        case .cloud: return "Manage active torrents in your Real-Debrid cloud storage"
        case .watchlist: return "Browse and organize your saved titles and continue watching history"
        case .updates: return "Configure auto-updates via Sparkle, GitHub Releases, and opt into Beta channel"
        case .monetization: return "Support Somnius development with non-intrusive sponsor ads, or configure referral links"
        }
    }

    // MARK: - 1. Setup & Engine View
    private var setupModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Classic Option
                Button(action: {
                    setupMode = "classic"
                    Config.streamingSetupMode = "classic"
                }) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Spacer()
                            if setupMode == "classic" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        Text("Classic Streaming")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text("Direct fast streaming without external accounts. Curated for verified fast peers.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(setupMode == "classic" ? Color.blue.opacity(0.15) : Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(setupMode == "classic" ? Color.blue : Color.white.opacity(0.08), lineWidth: 1.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Debrid Option
                Button(action: {
                    setupMode = "debrid"
                    Config.streamingSetupMode = "debrid"
                }) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "bolt.shield.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                            Spacer()
                            if setupMode == "debrid" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        Text("Real-Debrid Streaming")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text("Multi-gigabit cloud CDN. Streams 80GB+ 4K Remuxes & Dolby Vision instantly.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(setupMode == "debrid" ? Color.purple.opacity(0.15) : Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(setupMode == "debrid" ? Color.purple : Color.white.opacity(0.08), lineWidth: 1.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            if setupMode == "debrid" {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Turbo Engine (Real-Debrid) Configuration")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    HStack(spacing: 10) {
                        SecureField("Paste your Real-Debrid API token here...", text: $inputKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Save Token") {
                            let clean = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            Config.realDebridApiKey = clean
                            inputKey = clean
                            if var active = accountManager.activeAccount {
                                active.debridApiKey = clean.isEmpty ? nil : clean
                                active.setupMode = clean.isEmpty ? "classic" : "debrid"
                                accountManager.updateAccount(active)
                            }
                            statusMessage = clean.isEmpty ? "API Key removed." : "API Key saved successfully for \(accountManager.activeAccount?.username ?? "profile")."
                            viewModel.fetchContent()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        
                        if let url = URL(string: "https://real-debrid.com/apitoken") {
                            Button("Get Token") {
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Current Active Engine: \(setupMode == "debrid" ? "Real-Debrid Mode" : "Classic Mode")")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("In Classic mode, the app filters for high-speed seeders and cached links. In Debrid mode, torrents are converted into instant encrypted HTTPS streams via Real-Debrid.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
    }

    // MARK: - 2. Debrid Account View
    private var debridAccountView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Real-Debrid API Token", systemImage: "key.fill")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        if let url = URL(string: "https://real-debrid.com/apitoken") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Get API Key")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    SecureField("Paste your Real-Debrid API key...", text: $inputKey)
                        .textFieldStyle(.roundedBorder)

                    Button("Save Token") {
                        let clean = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        Config.realDebridApiKey = clean
                        inputKey = clean
                        if var active = accountManager.activeAccount {
                            active.debridApiKey = clean.isEmpty ? nil : clean
                            active.setupMode = clean.isEmpty ? "classic" : "debrid"
                            accountManager.updateAccount(active)
                        }
                        statusMessage = clean.isEmpty ? "API Key removed." : "API Key saved successfully for \(accountManager.activeAccount?.username ?? "profile")."
                        viewModel.fetchContent()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)

                    if !inputKey.isEmpty {
                        Button("Clear") {
                            inputKey = ""
                            Config.realDebridApiKey = ""
                            if var active = accountManager.activeAccount {
                                active.debridApiKey = nil
                                active.setupMode = "classic"
                                accountManager.updateAccount(active)
                            }
                            statusMessage = "API Key cleared."
                            viewModel.fetchContent()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let user = viewModel.realDebridUser {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected as \(user.username) (\(user.type.capitalized))")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        Text("•")
                            .foregroundColor(.gray)
                        Text("\(user.points) Fidelity Points")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                } else if !Config.realDebridApiKey.isEmpty {
                    Text("Configured (Checking status...)")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("No API key configured. Classic mode active.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if let msg = statusMessage {
                    Text(msg)
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)

            // Real-Debrid Affiliate & Partner Card
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Real-Debrid Affiliate & Referral Program")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Text("Partner")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                        Text("Earn commissions and reward points by sharing Somnius with your referral link.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(action: {
                        NSWorkspace.shared.open(Config.realDebridAffiliateUrl)
                    }) {
                        HStack(spacing: 5) {
                            Text("Open Affiliate Link")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Expandable Affiliate Settings
                DisclosureGroup("Configure Affiliate Referral ID / URL", isExpanded: $showAffiliateSettings) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Enter your Real-Debrid Affiliate ID or full Referral URL. Users tapping 'Get Real-Debrid' in Setup will subscribe using your link.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 10) {
                            TextField("Affiliate ID (e.g. 1234567)", text: $affiliateIdInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))

                            Button("Save ID") {
                                Config.realDebridAffiliateId = affiliateIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }

                        HStack(spacing: 10) {
                            TextField("Or Full Referral URL (e.g. https://real-debrid.com/?id=...)", text: $affiliateUrlInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))

                            Button("Save URL") {
                                Config.realDebridAffiliateUrlString = affiliateUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            .buttonStyle(.bordered)
                        }

                        Text("Current Active Link: \(Config.realDebridAffiliateUrl.absoluteString)")
                            .font(.caption2.monospaced())
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(16)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.18), lineWidth: 1))

            // TheTVDB (TVDB) Metadata Engine Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("TheTVDB Metadata Engine", systemImage: "tv.fill")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Active & Verified (v4)")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }

                Text("Powers enriched TV show metadata, missing episode backfilling, high-resolution 16:9 episode stills, clear logos, and cast automatically for all profiles.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
    }

    // MARK: - 3. Player & Buffering View
    private var playerBufferingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Fast Start Buffering Toggle
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Instant Playback Start (Fast Buffering)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Starts playing immediately on the first decoded frames instead of waiting for full forward buffer.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $fastStartBuffering)
                    .toggleStyle(.switch)
                    .onChange(of: fastStartBuffering) { _, val in
                        Config.fastStartBuffering = val
                    }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Forward Buffer Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Forward Buffer Ahead")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(bufferSeconds)) seconds")
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                }
                Slider(value: $bufferSeconds, in: 10...120, step: 5)
                    .onChange(of: bufferSeconds) { _, val in
                        Config.bufferAheadSeconds = val
                    }
                Text("Higher buffer ahead guarantees smooth playback on massive 4K Remux streams.")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Player Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Video Player")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Picker("", selection: $defaultPlayer) {
                    Text("Built-in Player").tag("native")
                    Text("IINA").tag("iina")
                    Text("VLC").tag("vlc")
                    Text("Infuse").tag("infuse")
                }
                .pickerStyle(.segmented)
                .onChange(of: defaultPlayer) { _, val in
                    Config.defaultPlayerSelection = val
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
    }

    // MARK: - 4. Subtitles Settings View
    private var subtitlesSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Static Subtitles Toggle
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Static Subtitles (No Motion Animation)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Renders crisp, instantaneous subtitles with no motion or sliding transitions.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $staticSubtitles)
                    .toggleStyle(.switch)
                    .onChange(of: staticSubtitles) { _, val in
                        Config.staticSubtitles = val
                    }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Language Picker
            HStack {
                Text("Preferred Subtitle Language")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Picker("", selection: $preferredSubLang) {
                    Text("English").tag("en")
                    Text("French").tag("fr")
                    Text("Spanish").tag("es")
                    Text("German").tag("de")
                    Text("Turkish").tag("tr")
                    Text("Italian").tag("it")
                    Text("Portuguese").tag("pt")
                    Text("Russian").tag("ru")
                    Text("Japanese").tag("ja")
                    Text("Korean").tag("ko")
                    Text("Arabic").tag("ar")
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                .onChange(of: preferredSubLang) { _, val in
                    Config.preferredSubtitleLanguage = val
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Subtitle Color & Size
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Subtitle Text Size")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(subtitleFontSize)) pt")
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                }
                Slider(value: $subtitleFontSize, in: 14...36, step: 2)
                    .onChange(of: subtitleFontSize) { _, val in
                        Config.subtitleFontSizePreference = CGFloat(val)
                    }

                Divider().background(Color.white.opacity(0.08))

                HStack {
                    Text("Subtitle Color")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $subtitleColor) {
                        Text("OLED Yellow").tag("yellow")
                        Text("Crisp White").tag("white")
                        Text("Neon Cyan").tag("cyan")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    .onChange(of: subtitleColor) { _, val in
                        Config.subtitleColorPreference = val
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
    }

    // MARK: - 5. Audio & Language View
    private var audioLanguageSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Preferred Language Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Audio Language")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Picker("", selection: $preferredAudioLanguage) {
                    Text("Turkish (tr)").tag("tr")
                    Text("English (en)").tag("en")
                    Text("German (de)").tag("de")
                    Text("French (fr)").tag("fr")
                    Text("Spanish (es)").tag("es")
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // PAL Speedup Correction Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PAL Speedup Correction (25fps → 23.976fps)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Applies FFmpeg atempo=0.95904 filter to synchronize 25fps European TV broadcast audio tracks to 23.976fps cinema releases without pitch distortion.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $enablePALSpeedupCorrection)
                    .toggleStyle(.switch)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Local Audio Proxy Status
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Local HLS Audio Proxy Engine")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Active on 127.0.0.1 • Swift NWListener • Multi-Track HLS Master Playlists")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
    }

    // MARK: - 6. Sources & Quality View
    private var sourcesQualityView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quality Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Streaming Quality")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Picker("", selection: $preferredQuality) {
                    Text("4K UHD Remux").tag("4k")
                    Text("1080p FHD").tag("1080p")
                    Text("720p HD").tag("720p")
                }
                .pickerStyle(.segmented)
                .onChange(of: preferredQuality) { _, val in
                    Config.preferredStreamQuality = val
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Cached Results Toggle
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Show Only Cached Links (RD+)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Hides uncached torrents that require background debrid downloading.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $showOnlyCached)
                    .toggleStyle(.switch)
                    .onChange(of: showOnlyCached) { _, val in
                        Config.showOnlyCachedResults = val
                    }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Auto-play Next Episode
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto-Play Next Episode")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Seamlessly jumps to the next episode when watching TV shows.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $autoPlayNext)
                    .toggleStyle(.switch)
                    .onChange(of: autoPlayNext) { _, val in
                        Config.autoPlayNextEpisode = val
                    }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Auto-Play Stream Rules & Bandwidth Limiter
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text("Auto-Play Rules & Bandwidth Limits")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }

                // File Size Limiter
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Maximum Stream File Size")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(autoPlayMaxSize == 0 ? "No Limit" : "\(Int(autoPlayMaxSize)) GB")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                    }
                    Text("Caps candidate stream file sizes during Auto-Play to prevent buffering on moderate internet connections.")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Picker("", selection: $autoPlayMaxSize) {
                        Text("4 GB").tag(4.0)
                        Text("8 GB").tag(8.0)
                        Text("15 GB").tag(15.0)
                        Text("25 GB").tag(25.0)
                        Text("50 GB").tag(50.0)
                        Text("Unlimited").tag(0.0)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: autoPlayMaxSize) { _, val in
                        Config.autoPlayMaxGbSize = val
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                // Preferred Quality for Auto-Play
                VStack(alignment: .leading, spacing: 6) {
                    Text("Auto-Play Target Resolution")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Picker("", selection: $autoPlayQuality) {
                        Text("4K UHD").tag("4k")
                        Text("1080p FHD").tag("1080p")
                        Text("720p HD").tag("720p")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: autoPlayQuality) { _, val in
                        Config.autoPlayPreferredQuality = val
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                // Attributes & Filters
                Toggle("Prefer Dolby Vision & HDR10 Releases", isOn: $autoPlayPreferHDR)
                    .toggleStyle(.switch)
                    .onChange(of: autoPlayPreferHDR) { _, val in
                        Config.autoPlayPreferHDR = val
                    }

                Toggle("Prefer 5.1 / 7.1 / Dolby Atmos Surround Audio", isOn: $autoPlayPreferSurround)
                    .toggleStyle(.switch)
                    .onChange(of: autoPlayPreferSurround) { _, val in
                        Config.autoPlayPreferSurround = val
                    }

                Toggle("Auto-Skip Hoster Notice Clips (< 90s Videos)", isOn: $autoPlaySkipShortClips)
                    .toggleStyle(.switch)
                    .onChange(of: autoPlaySkipShortClips) { _, val in
                        Config.autoPlaySkipShortClips = val
                    }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
    }

    // MARK: - 6b. Stremio Add-ons Management View
    private var stremioAddonsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1-Click Community Streaming Pack Banner
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Community Add-ons Made for Streaming")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Decentralized, open community indexers (Torrentio, Zilean, Bitmagnet, OpenSubtitles).")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            await addonManager.installCommunityStreamingPack(debridKey: Config.realDebridApiKey)
                            viewModel.fetchContent()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if addonManager.isInstalling {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: addonManager.installedAddons.isEmpty ? "arrow.down.circle.fill" : "arrow.clockwise")
                            }
                            Text(addonManager.installedAddons.isEmpty ? "Install Pack (1-Click)" : "Update Streaming Pack")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(addonManager.isInstalling)
                }

                HStack(spacing: 8) {
                    Text(Config.isDebridMode ? "⚡ Connected to Debrid (Fast Cloud Streaming)" : "Standard Mode • (Optional Debrid available for faster 4K cloud playback)")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Config.isDebridMode ? .yellow : .white.opacity(0.6))

                    Spacer()

                    Text("\(addonManager.installedAddons.count) Add-ons Active")
                        .font(.caption2.monospaced())
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))

            // Add Custom Manifest URL
            VStack(alignment: .leading, spacing: 8) {
                Text("Install Custom Add-on Manifest URL")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                HStack(spacing: 10) {
                    TextField("Enter manifest URL (e.g. https://.../manifest.json)", text: $newAddonUrlInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    Button(action: {
                        guard !newAddonUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        addonInstallError = nil
                        Task {
                            do {
                                _ = try await addonManager.installAddon(rawUrl: newAddonUrlInput)
                                newAddonUrlInput = ""
                            } catch {
                                addonInstallError = error.localizedDescription
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if addonManager.isInstalling {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Install")
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(addonManager.isInstalling || newAddonUrlInput.isEmpty)
                }

                if let err = addonInstallError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)

            // Installed Add-ons
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Installed Add-ons (\(addonManager.installedAddons.count))")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                }

                if addonManager.installedAddons.isEmpty {
                    Text("No add-ons installed. Install a community add-on below to enable stream aggregation.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(addonManager.installedAddons) { addon in
                            HStack(spacing: 12) {
                                Image(systemName: "puzzlepiece.fill")
                                    .font(.title3)
                                    .foregroundColor(addon.isEnabled ? .cyan : .gray)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(addon.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        Text("v\(addon.version)")
                                            .font(.caption2.monospaced())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(4)
                                            .foregroundColor(.gray)
                                    }

                                    Text(addon.description)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)

                                    Text(addon.manifestUrl)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.35))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { addon.isEnabled },
                                    set: { _ in addonManager.toggleAddon(id: addon.id) }
                                ))
                                .toggleStyle(.switch)
                                .scaleEffect(0.85)

                                Button(action: {
                                    configuredAddonForSheet = addon
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(8)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Configure Add-on Settings & Provider Keys")

                                Button(action: {
                                    addonManager.removeAddon(id: addon.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(8)
                                        .background(Color.red.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(10)
                        }
                    }
                }
            }

            // Community Add-ons Catalog (if any public templates configured)
            if !addonManager.communityTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Popular Community Add-ons")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(addonManager.communityTemplates) { template in
                            let isInstalled = addonManager.installedAddons.contains(where: { $0.id == template.id || $0.manifestUrl == template.manifestUrl })
                            HStack(spacing: 12) {
                                Image(systemName: template.icon)
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text(template.description)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Button(action: {
                                    Task {
                                        try? await addonManager.installAddon(rawUrl: template.manifestUrl)
                                    }
                                }) {
                                    Text(isInstalled ? "Installed" : "Install")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(isInstalled ? Color.white.opacity(0.08) : Color.blue.opacity(0.25))
                                        .foregroundColor(isInstalled ? .gray : .cyan)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isInstalled)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6. Catalogs Management View (Add, Remove, Toggle, Import, Export)
    private var catalogsManagementView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Toolbar: Add Catalog, Import, Export, Reset Defaults
            HStack(spacing: 10) {
                Button(action: {
                    showAddCatalogSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Catalog")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    showImportSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import JSON")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    let json = liveCatalogService.exportCatalogsJSON()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(json, forType: .string)
                    showExportAlert = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export JSON")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    liveCatalogService.resetToDefaults()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Defaults")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: {
                    Task {
                        await liveCatalogService.syncAllCatalogs(force: true)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync All")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(liveCatalogService.isSyncing)
            }

            Text("Manage, reorder, or delete custom discovery catalogs. Catalogs toggled off will not be shown on the home discovery feed.")
                .font(.caption)
                .foregroundColor(.gray)

            // Catalogs List
            VStack(spacing: 8) {
                ForEach(liveCatalogService.catalogs) { catalog in
                    HStack(spacing: 12) {
                        Image(systemName: catalog.type == "series" ? "tv" : "film")
                            .foregroundColor(.purple)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(catalog.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)

                            HStack(spacing: 8) {
                                Text(catalog.category)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text("\(catalog.items.count) titles")
                                    .font(.caption2)
                                    .foregroundColor(.cyan)
                            }
                        }

                        Spacer()

                        // Toggle active state
                        Toggle("", isOn: Binding(
                            get: { catalog.isEnabled },
                            set: { liveCatalogService.toggleCatalog(id: catalog.id, isEnabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)

                        // Delete / Remove Catalog Button
                        Button(action: {
                            withAnimation {
                                liveCatalogService.removeCatalog(id: catalog.id)
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                                .padding(6)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - 7. Debrid Cloud View
    private var debridCloudView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Active RealDebrid Cloud Torrents")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    isRefreshingCloud = true
                    viewModel.fetchRealDebridTorrents()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isRefreshingCloud = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Cloud")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }

            if viewModel.realDebridTorrents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.gray)
                    Text("No active debrid cloud torrents found.")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(viewModel.realDebridTorrents) { torrent in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(torrent.filename)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)

                            HStack(spacing: 12) {
                                Text("Status: \(torrent.status.capitalized)")
                                    .font(.caption)
                                    .foregroundColor(torrent.status == "downloaded" ? .green : .yellow)

                                if let bytes = torrent.bytes, bytes > 0 {
                                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Spacer()

                        if let links = torrent.links, let firstLink = links.first {
                            Button("Play Stream") {
                                dismiss()
                                onSelectTorrentLink(firstLink)
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - 8. Watchlist & History View
    private var watchlistHistoryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Clear controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Watchlist & History Management")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text("\(watchlistManager.watchlist.count) saved titles • \(watchlistManager.history.count) items in history")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                if !watchlistManager.history.isEmpty {
                    Button(action: {
                        withAnimation { watchlistManager.clearHistory() }
                    }) {
                        Text("Clear History")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if !watchlistManager.watchlist.isEmpty {
                    Button(action: {
                        withAnimation { watchlistManager.clearWatchlist() }
                    }) {
                        Text("Clear Watchlist")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Continue Watching Section
            if !watchlistManager.history.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Continue Watching")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(watchlistManager.history) { historyItem in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(historyItem.mediaItem.title)
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        if let s = historyItem.seasonNumber, let e = historyItem.episodeNumber {
                                            Text("S\(s):E\(e)")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        Text("\(Int(historyItem.progressFraction * 100))% completed")
                                            .font(.caption2)
                                            .foregroundColor(.cyan)
                                    }

                                    Button(action: {
                                        withAnimation {
                                            watchlistManager.removeHistory(id: historyItem.mediaItem.id)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }

            // Watchlist Grid with Individual Delete Buttons
            if watchlistManager.watchlist.isEmpty && watchlistManager.history.isEmpty {
                Text("No items saved or watched yet.")
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Saved to Watchlist")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 14)], spacing: 16) {
                        ForEach(watchlistManager.watchlist) { item in
                            ZStack(alignment: .topTrailing) {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let poster = item.posterUrl {
                                        AsyncImage(url: poster) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.white.opacity(0.1))
                                        }
                                        .frame(height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .help(item.title)
                                .onTapGesture {
                                    dismiss()
                                    onSelectMediaItem(item)
                                }

                                // Delete button
                                Button(action: {
                                    withAnimation {
                                        watchlistManager.removeFromWatchlist(id: item.id)
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(6)
                            }
                        }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 8)

            // Factory Reset / Blank Slate Action
            HStack(spacing: 14) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset App to Blank Slate (Fresh Install Mode)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Clears all accounts, watch history, saved lists, and stored tokens so the app behaves as a brand-new install.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: {
                    showResetConfirm = true
                }) {
                    Text("Reset to Blank Slate")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(14)
            .background(Color.red.opacity(0.05))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
        }
        .confirmationDialog("Reset to Blank Slate", isPresented: $showResetConfirm, actions: {
            Button("Reset Everything", role: .destructive) {
                watchlistManager.clearAllUserData()
                UserDefaults.standard.removeObject(forKey: "Somnius_User_Accounts_v2")
                UserDefaults.standard.removeObject(forKey: "Somnius_Active_Account_ID_v2")
                Config.realDebridApiKey = ""
                Config.hasCompletedOnboarding = false
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("This will purge all local watch data, accounts, and credentials, returning Somnius to the initial setup screen.")
        })
    }

    // MARK: - 9. Updates & Beta View (Sparkle Integration)
    private var updatesBetaView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Check for Updates action card
            HStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Somnius Auto-Updater")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text("Powered by Sparkle. Automatically checks GitHub Releases for new builds.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: {
                    AppUpdater.shared.checkForUpdates()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Check for Updates")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(18)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)

            // Beta Channel Opt-In
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receive Beta Channel Updates")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Get early access to cutting-edge features, new players, and bug fixes before public release.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { AppUpdater.shared.receiveBetaUpdates },
                    set: { AppUpdater.shared.receiveBetaUpdates = $0 }
                ))
                .toggleStyle(.switch)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // GitHub Repository Config
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub Repository (Owner/Repo)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("The GitHub repository that hosts your release tags, dmg installers, and appcast.xml.")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.gray)
                    TextField("e.g. yourname/Somnius", text: Binding(
                        get: { Config.updateRepository },
                        set: {
                            Config.updateRepository = $0
                            AppUpdater.shared.configureFeedURL()
                        }
                    ))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)

            // Build Info
            HStack {
                Text("Current Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("Build Channel: \(AppUpdater.shared.receiveBetaUpdates ? "Beta" : "Stable")")
                    .font(.caption.bold())
                    .foregroundColor(AppUpdater.shared.receiveBetaUpdates ? .orange : .green)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 10. Support & Ads View (Ad SDK Integration)
    private var monetizationAdsSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Overview Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Support Somnius", systemImage: "heart.fill")
                        .font(.headline.bold())
                        .foregroundColor(.pink)
                    Spacer()
                    Text(adManager.isAdsEnabled ? "Ads Active" : "Ads Disabled")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(adManager.isAdsEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.2))
                        .foregroundColor(adManager.isAdsEnabled ? .green : .gray)
                        .clipShape(Capsule())
                }

                Text("Somnius is free, open, and client-side. We keep the platform completely unrestricted through non-intrusive sponsorships.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)

            // Ads Toggle Card (Requirement 5)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Support Somnius with ads")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Displays non-blocking sponsor cards during setup and initial stream buffer loading. Ads never interrupt your playback or lock content.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $adManager.isAdsEnabled)
                        .toggleStyle(.switch)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)

            // Future Ad-Free Tier Placeholder (Requirement 5 Stub)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Somnius Ad-Free Supporter Pass")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("COMING SOON")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(Color.purple)
                                .clipShape(Capsule())
                        }
                        Text("Permanent zero-ad experience across all devices plus early beta builds and supporter profile badge.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button("Unlock Ad-Free") {}
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white.opacity(0.5))
                        .cornerRadius(6)
                        .disabled(true)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))

            // Real-Debrid Affiliate Settings
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Real-Debrid Affiliate Referral Link", systemImage: "bolt.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(Color(red: 0.22, green: 0.82, blue: 0.6))
                    Spacer()
                    Text("Partner ID: \(Config.realDebridAffiliateId)")
                        .font(.caption.monospaced())
                        .foregroundColor(.white.opacity(0.6))
                }

                Text("Users who tap 'Get Real-Debrid' in Setup will subscribe using your partner link, earning you Fidelity Points and free premium days.")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack(spacing: 10) {
                    TextField("Affiliate ID (e.g. 10141263)", text: $affiliateIdInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 240)

                    Button("Save Affiliate ID") {
                        Config.realDebridAffiliateId = affiliateIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
    }

    // MARK: - Import Catalogs Sheet
    private var importCatalogsSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Import Catalogs JSON")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Button("Cancel") { showImportSheet = false }
            }

            Text("Paste a valid catalogs JSON export array below to import into your streaming setup.")
                .font(.caption)
                .foregroundColor(.gray)

            TextEditor(text: $importJsonText)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .frame(height: 240)

            HStack {
                Spacer()
                Button("Import Catalogs") {
                    do {
                        _ = try liveCatalogService.importCatalogs(from: importJsonText)
                        showImportSheet = false
                    } catch {
                        // error handling
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding(20)
        .frame(width: 500, height: 380)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }

    // MARK: - Add New Catalog Sheet (TMDB, TVDB & Custom Catalogs)
    private var addCatalogSheet: some View {
        AddCatalogModalView(isPresented: $showAddCatalogSheet)
    }
}

struct AddCatalogModalView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var catalogService = LiveCatalogService.shared

    @State private var selectedTab: Int = 0 // 0: TMDB Presets, 1: TVDB / Series Presets, 2: Custom Manifest Endpoint
    @State private var customName: String = ""
    @State private var customType: String = "movie"
    @State private var customCategory: String = "Custom Discovery"
    @State private var customEndpoint: String = ""
    @State private var addedNotice: String? = nil

    struct CatalogPresetItem: Identifiable {
        let id: String
        let name: String
        let type: String
        let category: String
        let endpointPath: String
        let icon: String
        let source: String
    }

    private let tmdbPresets: [CatalogPresetItem] = [
        CatalogPresetItem(id: "tmdb.movie.now_playing", name: "In Theaters Now", type: "movie", category: "TMDB Live", endpointPath: "catalog/movie/tmdb-today.json", icon: "film.fill", source: "TMDB"),
        CatalogPresetItem(id: "tmdb.movie.trending_daily", name: "Trending Daily", type: "movie", category: "TMDB Live", endpointPath: "catalog/movie/tmdb-latest.json", icon: "flame.fill", source: "TMDB"),
        CatalogPresetItem(id: "tmdb.movie.top_rated", name: "All-Time Top Rated", type: "movie", category: "TMDB Live", endpointPath: "catalog/movie/mdblist-pub%3A2236.json", icon: "star.fill", source: "TMDB"),
        CatalogPresetItem(id: "tmdb.movie.scifi_space", name: "Sci-Fi & Cosmic Movies", type: "movie", category: "TMDB Genres", endpointPath: "catalog/movie/mdblist-pub%3A1001.json", icon: "sparkles", source: "TMDB"),
        CatalogPresetItem(id: "tmdb.movie.action_thriller", name: "Action & Adrenaline", type: "movie", category: "TMDB Genres", endpointPath: "catalog/movie/mdblist-pub%3A1002.json", icon: "bolt.fill", source: "TMDB"),
        CatalogPresetItem(id: "tmdb.movie.animation_pixar", name: "Animated Masterpieces", type: "movie", category: "TMDB Genres", endpointPath: "catalog/movie/mdblist-pub%3A1003.json", icon: "wand.and.stars", source: "TMDB")
    ]

    private let tvdbPresets: [CatalogPresetItem] = [
        CatalogPresetItem(id: "tvdb.series.trending_week", name: "Trending TV Shows", type: "series", category: "TVDB Live", endpointPath: "catalog/series/tmdb-latest-shows.json", icon: "tv.fill", source: "TheTVDB"),
        CatalogPresetItem(id: "tvdb.series.popular_now", name: "Binge-Worthy Dramas", type: "series", category: "TVDB Live", endpointPath: "catalog/series/trakt-trending.json", icon: "play.tv.fill", source: "TheTVDB"),
        CatalogPresetItem(id: "tvdb.series.top_rated", name: "Top Rated Television", type: "series", category: "TVDB Live", endpointPath: "catalog/series/tmdb-today-shows.json", icon: "crown.fill", source: "TheTVDB"),
        CatalogPresetItem(id: "tvdb.series.hbo_prestige", name: "HBO & Max Originals", type: "series", category: "TV Networks", endpointPath: "catalog/series/mdblist-pub%3A3086.json", icon: "sparkles.tv", source: "TheTVDB"),
        CatalogPresetItem(id: "tvdb.series.apple_plus", name: "Apple TV+ Series", type: "series", category: "TV Networks", endpointPath: "catalog/series/mdblist-pub%3A3087.json", icon: "applelogo", source: "TheTVDB"),
        CatalogPresetItem(id: "tvdb.series.netflix_hits", name: "Netflix Originals", type: "series", category: "TV Networks", endpointPath: "catalog/series/mdblist-pub%3A3088.json", icon: "play.rectangle.fill", source: "TheTVDB")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add New Discovery Catalog")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Add curated TMDB, TVDB, Trakt, or custom manifest catalogs.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            // Tabs Selector
            Picker("", selection: $selectedTab) {
                Text("TMDB Movies").tag(0)
                Text("TVDB & TV Shows").tag(1)
                Text("Custom Manifest Endpoint").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 18)

            Divider().background(Color.white.opacity(0.1))

            // Body Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    if let notice = addedNotice {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(notice)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                    }

                    if selectedTab == 0 {
                        presetsGridView(presets: tmdbPresets)
                    } else if selectedTab == 1 {
                        presetsGridView(presets: tvdbPresets)
                    } else {
                        customCatalogForm
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 700, height: 530)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .preferredColorScheme(.dark)
    }

    private func presetsGridView(presets: [CatalogPresetItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Select a catalog to add it instantly to your Home discovery rows:")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(presets) { preset in
                    let isAlreadyAdded = catalogService.catalogs.contains(where: { $0.id == preset.id || $0.name == preset.name })
                    HStack(spacing: 12) {
                        Image(systemName: preset.icon)
                            .font(.title3)
                            .foregroundColor(.cyan)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            HStack(spacing: 6) {
                                Text(preset.source)
                                    .font(.caption2.bold())
                                    .foregroundColor(.purple)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(preset.category)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Button(action: {
                            let newCat = LiveCatalog(
                                id: preset.id,
                                name: preset.name,
                                type: preset.type,
                                endpointPath: preset.endpointPath,
                                category: preset.category
                            )
                            catalogService.addCatalog(newCat)
                            withAnimation {
                                addedNotice = "✓ Added \(preset.name) to your home catalogs!"
                            }
                        }) {
                            Text(isAlreadyAdded ? "Added" : "+ Add")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isAlreadyAdded ? Color.white.opacity(0.08) : Color.blue)
                                .foregroundColor(isAlreadyAdded ? .gray : .white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isAlreadyAdded)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                }
            }
        }
    }

    private var customCatalogForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Custom Manifest Catalog Endpoint")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("Catalog Name")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                TextField("e.g. My Favorite Sci-Fi", text: $customName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Media Type")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Picker("", selection: $customType) {
                        Text("Movie").tag("movie")
                        Text("TV Series").tag("series")
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Category Section")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    TextField("e.g. Custom Discovery", text: $customCategory)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Catalog Endpoint Path or Full URL")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                TextField("catalog/movie/popular.json or https://...", text: $customEndpoint)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }

            Button(action: {
                guard !customName.isEmpty, !customEndpoint.isEmpty else { return }
                let newCat = LiveCatalog(
                    id: "custom.\(UUID().uuidString.prefix(8))",
                    name: customName,
                    type: customType,
                    endpointPath: customEndpoint,
                    category: customCategory.isEmpty ? "Custom Discovery" : customCategory
                )
                catalogService.addCatalog(newCat)
                withAnimation {
                    addedNotice = "✓ Successfully created \(customName)!"
                    customName = ""
                    customEndpoint = ""
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Save & Add Catalog")
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(customName.isEmpty || customEndpoint.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(customName.isEmpty || customEndpoint.isEmpty)
        }
    }
}

// MARK: - Add-on Specific Settings Modal View
struct AddonSettingsModalView: View {
    let addon: InstalledAddon
    var onDismiss: () -> Void

    @State private var inputProviderKey: String = Config.realDebridApiKey
    @State private var statusNote: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "gearshape.2.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(addon.name) Settings")
                        .font(.custom("Baskerville", size: 22))
                        .foregroundColor(.white)
                    Text("v\(addon.version) • Configure external resolver credentials for this add-on")
                        .font(.custom("Helvetica", size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Button("Done") {
                    onDismiss()
                }
                .font(.custom("Helvetica", size: 13).weight(.bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.12))
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }

            Divider().background(Color.white.opacity(0.1))

            // Add-on info
            VStack(alignment: .leading, spacing: 6) {
                Text("Manifest Source URL")
                    .font(.custom("Helvetica", size: 11).weight(.bold))
                    .foregroundColor(.white.opacity(0.6))
                Text(addon.manifestUrl)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
            }

            // External Debrid / Resolver Provider Token
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Debrid / Resolver API Key (Optional)")
                        .font(.custom("Helvetica", size: 12).weight(.bold))
                        .foregroundColor(.white)
                    Spacer()
                    Link("Get API Token ↗", destination: URL(string: "https://real-debrid.com/apitoken")!)
                        .font(.custom("Helvetica", size: 11))
                        .foregroundColor(.cyan)
                }

                Text("If this add-on indexes torrent or restricted streams, entering your debrid token allows the add-on to convert them into instant encrypted HTTPS streams.")
                    .font(.custom("Helvetica", size: 12))
                    .foregroundColor(.gray)

                HStack(spacing: 10) {
                    SecureField("Paste API Token here...", text: $inputProviderKey)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    Button(action: {
                        let clean = inputProviderKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        Config.realDebridApiKey = clean
                        Config.streamingSetupMode = clean.isEmpty ? "classic" : "debrid"
                        statusNote = clean.isEmpty ? "✓ Provider key removed." : "✓ Provider key saved and activated for this add-on."
                    }) {
                        Text("Save Token")
                            .font(.custom("Helvetica", size: 13).weight(.bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if let note = statusNote {
                    Text(note)
                        .font(.custom("Helvetica", size: 12))
                        .foregroundColor(.green)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)

            Spacer()
        }
        .padding(24)
        .frame(width: 580, height: 420)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .preferredColorScheme(.dark)
    }
}
