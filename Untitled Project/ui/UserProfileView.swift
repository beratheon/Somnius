import SwiftUI
import AppKit

struct UserProfileView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var watchlistManager = WatchlistManager.shared
    @ObservedObject private var liveCatalogService = LiveCatalogService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: SettingsCategory = .setupMode
    @State private var inputKey: String = Config.realDebridApiKey
    @State private var tvdbInputKey: String = Config.tvdbApiKey
    @State private var tvdbStatusMessage: String?
    @State private var setupMode: String = Config.streamingSetupMode
    @State private var showOnlyCached: Bool = Config.showOnlyCachedResults
    @State private var defaultPlayer: String = Config.defaultPlayerSelection
    @State private var preferredSubLang: String = Config.preferredSubtitleLanguage
    @State private var autoPlayNext: Bool = Config.autoPlayNextEpisode
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

    var onSelectMediaItem: (MediaItem) -> Void
    var onSelectTorrentLink: (String) -> Void

    enum SettingsCategory: String, CaseIterable, Identifiable {
        case setupMode = "Setup & Engine"
        case debridAccount = "Debrid Account"
        case player = "Player & Buffering"
        case subtitles = "Subtitles"
        case audioLanguage = "Audio & Language"
        case streaming = "Sources & Quality"
        case addons = "Add-ons (Stremio)"
        case catalogs = "Catalogs"
        case cloud = "Debrid Cloud"
        case watchlist = "Watchlist & History"
        case updates = "Updates & Beta"

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
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Settings Sidebar
            VStack(alignment: .leading, spacing: 6) {
                // Window Header
                HStack(spacing: 12) {
                    // Claude-like minimalist full moon icon (matching Somnus aesthetic)
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
                        Text(viewModel.realDebridUser != nil ? viewModel.realDebridUser!.username : (Config.isDebridMode ? "Debrid Mode" : "Classic Mode"))
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
                        ForEach(SettingsCategory.allCases) { cat in
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

                // Return / Close Button (Matching ≤ Back Aesthetic)
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
                    }
                }
                .padding(26)
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        }
        .frame(minWidth: 1100, idealWidth: 1400, maxWidth: 1400, minHeight: 720, idealHeight: 900, maxHeight: 900)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.85), radius: 36, x: 0, y: 18)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showImportSheet) {
            importCatalogsSheet
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
        case .addons: return "Install external scraping add-ons via Stremio Add-on Protocol v3"
        case .catalogs: return "Manage live catalogs, import/export configurations, or remove sections"
        case .cloud: return "Manage active torrents in your Real-Debrid cloud storage"
        case .watchlist: return "Browse and organize your saved titles and continue watching history"
        case .updates: return "Configure auto-updates via Sparkle, GitHub Releases, and opt into Beta channel"
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
                        statusMessage = clean.isEmpty ? "API Key removed." : "API Key saved successfully."
                        viewModel.fetchContent()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)

                    if !inputKey.isEmpty {
                        Button("Clear") {
                            inputKey = ""
                            Config.realDebridApiKey = ""
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
                        Text("Connected (v4)")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }

                Text("Powers enriched TV show metadata, missing episode backfilling, high-resolution 16:9 episode stills, clear logos, and cast.")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack(spacing: 10) {
                    SecureField("TheTVDB API key...", text: $tvdbInputKey)
                        .textFieldStyle(.roundedBorder)

                    Button("Save Key") {
                        let clean = tvdbInputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        Config.tvdbApiKey = clean.isEmpty ? Config.defaultTVDBApiKey : clean
                        tvdbInputKey = Config.tvdbApiKey
                        tvdbStatusMessage = "TheTVDB API Key updated."
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button("Reset Default") {
                        Config.tvdbApiKey = Config.defaultTVDBApiKey
                        tvdbInputKey = Config.defaultTVDBApiKey
                        tvdbStatusMessage = "Reset to default verified TheTVDB key."
                    }
                    .buttonStyle(.bordered)
                }

                if let tvdbMsg = tvdbStatusMessage {
                    Text(tvdbMsg)
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                }
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
        }
    }

    // MARK: - 6b. Stremio Add-ons Management View
    private var stremioAddonsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Legal & Protocol Banner
            HStack(spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Decoupled Add-on Architecture")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Somnius is an agnostic media player shell. Streaming scrapers run externally via the open Stremio Add-on Protocol (v3). You can install custom community manifests or configure Real-Debrid tokens securely on your local device.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(Color.cyan.opacity(0.08))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.2), lineWidth: 1))

            // Add Custom Manifest URL
            VStack(alignment: .leading, spacing: 8) {
                Text("Install Add-on from Manifest URL")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                HStack(spacing: 10) {
                    TextField("Enter manifest URL (e.g. https://.../manifest.json or stremio://...)", text: $newAddonUrlInput)
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

            // Community Add-ons Catalog
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

    // MARK: - 6. Catalogs Management View (Add, Remove, Toggle, Import, Export)
    private var catalogsManagementView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Toolbar: Import, Export, Reset Defaults
            HStack(spacing: 10) {
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Watchlist (\(watchlistManager.watchlist.count) saved) & History (\(watchlistManager.history.count) items)")
                .font(.headline.bold())
                .foregroundColor(.white)

            if watchlistManager.watchlist.isEmpty && watchlistManager.history.isEmpty {
                Text("No items saved or watched yet.")
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 14)], spacing: 16) {
                    ForEach(watchlistManager.watchlist) { item in
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
                    }
                }
            }
        }
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
                    Text("Somnus Auto-Updater")
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
                    TextField("e.g. yourname/Somnus", text: Binding(
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
}
