import SwiftUI

struct UserProfileView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var watchlistManager = WatchlistManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ProfileTab = .history
    @State private var inputKey: String = Config.realDebridAPIKey
    @State private var showOnlyCached: Bool = Config.showOnlyCachedResults
    @State private var defaultPlayer: String = Config.defaultPlayerSelection
    @State private var preferredSubLang: String = Config.preferredSubtitleLanguage
    @State private var autoPlayNext: Bool = Config.autoPlayNextEpisode
    @State private var bufferSeconds: Double = Config.bufferAheadSeconds
    @State private var preferredQuality: String = Config.preferredStreamQuality
    @State private var engineMode: String = Config.playbackEngineMode
    @State private var subtitleColor: String = Config.subtitleColorPreference
    @State private var statusMessage: String?
    @State private var isRefreshingCloud: Bool = false

    var onSelectMediaItem: (MediaItem) -> Void
    var onSelectTorrentLink: (String) -> Void

    enum ProfileTab: String, CaseIterable, Identifiable {
        case history = "Continue Watching"
        case watchlist = "My Watchlist"
        case favorites = "Favorites"
        case debridCloud = "Debrid Cloud"
        case settings = "Settings"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .history: return "play.circle.fill"
            case .watchlist: return "bookmark.fill"
            case .favorites: return "heart.fill"
            case .debridCloud: return "icloud.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Profile Header Bar
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)

                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(viewModel.realDebridUser?.username ?? "Debrid User")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text((viewModel.realDebridUser?.type ?? "Free").uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(6)
                    }

                    HStack(spacing: 14) {
                        if let points = viewModel.realDebridUser?.points {
                            Label("\(points) Fidelity Points", systemImage: "star.fill")
                                .font(.caption.bold())
                                .foregroundColor(.yellow)
                        }

                        Label("\(watchlistManager.watchlist.count) Saved", systemImage: "bookmark")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Label("\(watchlistManager.history.count) Watched", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.black.opacity(0.4))

            // Tab Selector Chips Bar
            HStack(spacing: 10) {
                ForEach(ProfileTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.blue : Color.white.opacity(0.08))
                        .foregroundColor(selectedTab == tab ? .white : .gray)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))

            Divider().background(Color.white.opacity(0.1))

            // Main Content Area based on Selected Tab
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .history:
                        historySection
                    case .watchlist:
                        watchlistGrid(items: watchlistManager.watchlist, emptyTitle: "Your Watchlist is Empty", emptySub: "Click the bookmark icon on any movie or show to save it here.")
                    case .favorites:
                        watchlistGrid(items: watchlistManager.favorites, emptyTitle: "No Favorites Yet", emptySub: "Add your top rated movies and series to your favorites collection.")
                    case .debridCloud:
                        debridCloudSection
                    case .settings:
                        settingsSection
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, idealWidth: 880, minHeight: 560, idealHeight: 680)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .preferredColorScheme(.dark)
        .onAppear {
            inputKey = Config.realDebridAPIKey
            showOnlyCached = Config.showOnlyCachedResults
            defaultPlayer = Config.defaultPlayerSelection
            preferredSubLang = Config.preferredSubtitleLanguage
            autoPlayNext = Config.autoPlayNextEpisode
            bufferSeconds = Config.bufferAheadSeconds
            preferredQuality = Config.preferredStreamQuality
            engineMode = Config.playbackEngineMode
            subtitleColor = Config.subtitleColorPreference
            viewModel.fetchRealDebridTorrents()
        }
    }

    // MARK: - Continue Watching Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Continue Watching")
                    .font(.headline.bold())
                    .foregroundColor(.white)

                Spacer()

                if !watchlistManager.history.isEmpty {
                    Button("Clear History") {
                        watchlistManager.clearHistory()
                    }
                    .font(.caption.bold())
                    .foregroundColor(.red.opacity(0.8))
                    .buttonStyle(.plain)
                }
            }

            if watchlistManager.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No Recent History")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Movies and TV episodes you stream will appear here with progress bars so you can resume anytime.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: 230), spacing: 16)], spacing: 16) {
                    ForEach(watchlistManager.history) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                ZStack(alignment: .bottom) {
                                    if let backdrop = item.mediaItem.backdropUrl ?? item.mediaItem.posterUrl {
                                        AsyncImage(url: backdrop) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.white.opacity(0.1))
                                        }
                                        .frame(height: 115)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 115)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }

                                    // Play Overlay Button
                                    Button(action: {
                                        dismiss()
                                        onSelectMediaItem(item.mediaItem)
                                    }) {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 38, height: 38)
                                            .overlay(
                                                Image(systemName: "play.fill")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.bottom, 36)

                                    // Progress Bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(Color.black.opacity(0.6))
                                                .frame(height: 4)
                                            Rectangle()
                                                .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: geo.size.width * CGFloat(item.progressFraction), height: 4)
                                        }
                                    }
                                    .frame(height: 4)
                                }

                                // Delete from History Button
                                Button(action: {
                                    watchlistManager.removeHistory(id: item.mediaItem.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                                .padding(6)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.mediaItem.title)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                HStack {
                                    if let s = item.seasonNumber, let e = item.episodeNumber {
                                        Text("S\(s) E\(e)")
                                            .font(.caption.bold())
                                            .foregroundColor(.cyan)
                                    } else {
                                        Text("Movie")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Text("\(Int(item.progressFraction * 100))%")
                                        .font(.caption2.monospacedDigit().bold())
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Media Item Grid (Watchlist / Favorites)
    private func watchlistGrid(items: [MediaItem], emptyTitle: String, emptySub: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text(emptyTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(emptySub)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 170), spacing: 16)], spacing: 16) {
                    ForEach(items) { item in
                        Button(action: {
                            dismiss()
                            onSelectMediaItem(item)
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                if let poster = item.posterUrl {
                                    AsyncImage(url: poster) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Color.white.opacity(0.1))
                                    }
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                Text(item.title)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Debrid Cloud Section
    private var debridCloudSection: some View {
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
                            .rotationEffect(.degrees(isRefreshingCloud ? 360 : 0))
                            .animation(isRefreshingCloud ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshingCloud)
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

                                if let prog = torrent.progress {
                                    Text("\(Int(prog))%")
                                        .font(.caption.bold())
                                        .foregroundColor(.cyan)
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
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Player & Scraper Settings")
                .font(.headline.bold())
                .foregroundColor(.white)

            // Default Video Player Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Video Player")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Picker("Player", selection: $defaultPlayer) {
                    Text("Native In-App Player (Recommended)").tag("native")
                    Text("IINA Player \(ExternalPlayer.iina.isInstalled ? "✓" : "(Not Installed)")").tag("iina")
                    Text("VLC Media Player \(ExternalPlayer.vlc.isInstalled ? "✓" : "(Not Installed)")").tag("vlc")
                    Text("Infuse \(ExternalPlayer.infuse.isInstalled ? "✓" : "(Not Installed)")").tag("infuse")
                }
                .pickerStyle(.segmented)
                .onChange(of: defaultPlayer) { _, val in
                    Config.defaultPlayerSelection = val
                }

                Text("External players handle high-bitrate 4K Remux / TrueHD MKV files with custom audio pass-through.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Preferred Subtitle Language
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Subtitle Language")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Picker("Subtitle Language", selection: $preferredSubLang) {
                    Text("English").tag("en")
                    Text("French (Français)").tag("fr")
                    Text("Spanish (Español)").tag("es")
                    Text("German (Deutsch)").tag("de")
                    Text("Turkish (Türkçe)").tag("tr")
                    Text("Italian (Italiano)").tag("it")
                    Text("Portuguese (Português)").tag("pt")
                    Text("Russian (Русский)").tag("ru")
                    Text("Japanese (日本語)").tag("ja")
                    Text("Korean (한국어)").tag("ko")
                    Text("Arabic (العربية)").tag("ar")
                }
                .pickerStyle(.menu)
                .onChange(of: preferredSubLang) { _, val in
                    Config.preferredSubtitleLanguage = val
                }

                Text("Subtitles in this language will be automatically loaded from OpenSubtitles v3 when available.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Forward Buffer Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Stream Forward Buffer Duration")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Picker("Forward Buffer", selection: $bufferSeconds) {
                    Text("30 Seconds (Fast Start)").tag(30.0)
                    Text("60 Seconds (Recommended)").tag(60.0)
                    Text("120 Seconds (High Bitrate 4K)").tag(120.0)
                }
                .pickerStyle(.segmented)
                .onChange(of: bufferSeconds) { _, val in
                    Config.bufferAheadSeconds = val
                }

                Text("Higher buffer prevents stalls on heavy 4K UHD streams over high-speed internet connections.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Preferred Stream Quality (4K, 1080p, 720p)
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Stream Quality")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Picker("Quality", selection: $preferredQuality) {
                    Text("4K HDR & Remux (Highest Fidelity)").tag("4k")
                    Text("1080p BluRay / FHD (Fast & Smooth)").tag("1080p")
                    Text("720p HD (Data Saver)").tag("720p")
                }
                .pickerStyle(.segmented)
                .onChange(of: preferredQuality) { _, val in
                    Config.preferredStreamQuality = val
                }

                Text("Sources matching your preferred resolution receive the highest priority ranking in scrapers.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // In-App Video Playback Engine
            VStack(alignment: .leading, spacing: 8) {
                Text("In-App Video Engine")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Picker("Engine", selection: $engineMode) {
                    Text("Auto (AVPlayer with Soia Fallback)").tag("auto")
                    Text("Apple Native (AVPlayer)").tag("avplayer")
                    Text("Soia Hardware Engine (libmpv)").tag("soia")
                }
                .pickerStyle(.segmented)
                .onChange(of: engineMode) { _, val in
                    Config.playbackEngineMode = val
                }

                Text("Soia Engine uses embedded libmpv with VideoToolbox hardware acceleration and tone maps Dolby Vision MKVs.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Subtitle Default Appearance
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Subtitle Color")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Picker("Subtitle Color", selection: $subtitleColor) {
                    Text("Warm Yellow (Recommended for HDR/OLED)").tag("yellow")
                    Text("Crisp White").tag("white")
                    Text("Neon Cyan").tag("cyan")
                }
                .pickerStyle(.segmented)
                .onChange(of: subtitleColor) { _, val in
                    Config.subtitleColorPreference = val
                }

                Text("Yellow subtitles prevent eye strain and excessive peak brightness in HDR and Dolby Vision titles.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Binge Autoplay & Caching Toggles
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Auto-Play Next Episode (TV Series)", isOn: $autoPlayNext)
                    .onChange(of: autoPlayNext) { _, val in
                        Config.autoPlayNextEpisode = val
                    }

                Divider().background(Color.white.opacity(0.1))

                Toggle("Show Only Cached Results", isOn: $showOnlyCached)
                    .onChange(of: showOnlyCached) { _, newValue in
                        Config.showOnlyCachedResults = newValue
                    }

                Text("When enabled, uncached torrents requiring background debrid downloads are hidden.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Real-Debrid API Key
            VStack(alignment: .leading, spacing: 12) {
                Text("RealDebrid API Key")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                SecureField("Paste RealDebrid API Key...", text: $inputKey)
                    .textFieldStyle(.roundedBorder)

                Button("Save API Key") {
                    Config.realDebridAPIKey = inputKey
                    statusMessage = "API Key saved successfully."
                    viewModel.fetchContent()
                }
                .buttonStyle(.borderedProminent)

                if let msg = statusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
    }
}
