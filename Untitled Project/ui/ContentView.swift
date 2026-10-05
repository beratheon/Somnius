import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var selectedMediaItem: MediaItem?
    @State private var detailMediaItem: MediaItem?
    @State private var playingSeason: Int? = nil
    @State private var playingEpisode: Int? = nil

    @State private var scrapedLinks: [AggregatedLink] = []
    @State private var selectedStreamURL: URL? = nil
    @State private var showPlayer: Bool = false
    @State private var isFetchingStreams: Bool = false
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var showStreamPicker: Bool = false
    @State private var showProfileModal: Bool = false
    @State private var errorMessage: String? = nil
    @State private var hasCompletedOnboarding: Bool = Config.hasCompletedOnboarding

    enum MainNavigationTab: String, CaseIterable {
        case home = "Home"
        case movies = "Movies"
        case series = "Series"
        case watchlist = "Watchlist"
        case settings = "Settings"
    }

    @State private var currentTab: MainNavigationTab = .home

    var body: some View {
        ZStack {
            if accountManager.activeAccount == nil || !hasCompletedOnboarding {
                AccountSetupView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        hasCompletedOnboarding = true
                    }
                    viewModel.fetchContent()
                }
                .transition(.opacity)
                .zIndex(300)
            } else {
                // Dark Minimal Background
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Bar (Apple TV+ / macOS Native Aesthetic)
                    HStack(spacing: 16) {
                        // Somnius Branding & Top Nav Tabs
                        HStack(spacing: 12) {
                            // Claude-like minimalist full moon icon (no emoji) - 25% larger
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [Color.white, Color(white: 0.85)]),
                                            center: .center,
                                            startRadius: 2,
                                            endRadius: 11
                                        )
                                    )
                                    .frame(width: 21, height: 21)
                                    .shadow(color: Color.white.opacity(0.45), radius: 6, x: 0, y: 0)
                            }

                            Text("Somnius")
                                .font(.custom("Baskerville", size: 26))
                                .foregroundColor(.white)
                                .tracking(0.6)
                        }

                        // Top Navigation Links (Home, Movies, Series, Watchlist, Settings)
                        HStack(spacing: 22) {
                            ForEach(MainNavigationTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentTab = tab
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Text(tab.rawValue)
                                            .font(.system(size: 13, weight: currentTab == tab ? .bold : .medium))
                                            .foregroundColor(currentTab == tab ? .white : .white.opacity(0.55))

                                        if currentTab == tab {
                                            Capsule()
                                                .fill(Color.white)
                                                .frame(width: 18, height: 2)
                                        } else {
                                            Capsule()
                                                .fill(Color.clear)
                                                .frame(width: 18, height: 2)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.leading, 10)

                        Spacer()

                        // Search Bar Widget in Header
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                            TextField("Search movies, TV series...", text: $viewModel.searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .onSubmit {
                                    viewModel.performSearch()
                                }
                            if !viewModel.searchQuery.isEmpty {
                                Button(action: { viewModel.clearSearch() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.45))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                        .frame(width: 300)

                        Spacer()

                        // Profile Switcher Pill
                        Button(action: {
                            accountManager.showAccountModal = true
                        }) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(AccountManager.colorForName(accountManager.activeAccount?.avatarColor ?? "purple").opacity(0.35))
                                        .frame(width: 22, height: 22)
                                    Image(systemName: accountManager.activeAccount?.avatarIcon ?? "person.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AccountManager.colorForName(accountManager.activeAccount?.avatarColor ?? "purple"))
                                }
                                Text(accountManager.activeAccount?.username ?? "Profile")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.leading, 28)
                    .padding(.trailing, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 14)
                    .background(.ultraThinMaterial)
                    .overlay(
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                        }
                    )

                    // Main Content based on Tab (Home, Movies, Series, Watchlist, Settings)
                    if currentTab == .watchlist {
                        WatchlistView(onMediaSelected: { item in
                            withAnimation {
                                detailMediaItem = item
                            }
                        })
                    } else if currentTab == .settings {
                        UserProfileView(
                            viewModel: viewModel,
                            isEmbeddedPage: true,
                            onSelectMediaItem: { item in
                                withAnimation {
                                    detailMediaItem = item
                                }
                            },
                            onSelectTorrentLink: { linkString in
                                Task {
                                    await playDirectLink(linkString)
                                }
                            }
                        )
                    } else {
                        ContentDiscoveryView(
                            viewModel: viewModel,
                            filterCategory: currentTab == .movies ? "Movies" : (currentTab == .series ? "TV Shows" : "All"),
                            onMediaSelected: { item in
                                withAnimation {
                                    detailMediaItem = item
                                }
                            },
                            onOpenProfile: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentTab = .settings
                                }
                            }
                        )
                    }
                }
            }

            // Internal Player View Fullscreen Sheet / Overlay
            if showPlayer, let url = selectedStreamURL {
                PlayerView(
                    streamURL: url,
                    mediaItem: selectedMediaItem,
                    currentSeason: playingSeason,
                    currentEpisode: playingEpisode,
                    initialLinks: scrapedLinks,
                    onDismiss: {
                        showPlayer = false
                        selectedStreamURL = nil
                        if let sel = selectedMediaItem {
                            detailMediaItem = sel
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(200)
            }

            // 1-Second Profile Switch Loading Screen (Takes over entire screen)
            if accountManager.isSwitchingProfile {
                let target = accountManager.switchingProfileTarget ?? accountManager.activeAccount
                ZStack {
                    Color.black.opacity(0.96)
                        .ignoresSafeArea()

                    // Ambient glow of profile color
                    RadialGradient(
                        colors: [
                            AccountManager.colorForName(target?.avatarColor ?? "purple").opacity(0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 360
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(AccountManager.colorForName(target?.avatarColor ?? "purple").opacity(0.2))
                                .frame(width: 110, height: 110)
                                .overlay(
                                    Circle()
                                        .stroke(AccountManager.colorForName(target?.avatarColor ?? "purple").opacity(0.8), lineWidth: 3)
                                )
                                .shadow(color: AccountManager.colorForName(target?.avatarColor ?? "purple").opacity(0.5), radius: 20, x: 0, y: 8)

                            Image(systemName: target?.avatarIcon ?? "person.fill")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundColor(AccountManager.colorForName(target?.avatarColor ?? "purple"))
                        }

                        VStack(spacing: 8) {
                            Text("Switching to \(target?.username ?? "Profile")...")
                                .font(.custom("Baskerville", size: 26))
                                .foregroundColor(.white)

                            Text("Loading personal watchlist, history & settings")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                            .padding(.top, 10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(500)
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .sheet(isPresented: $showStreamPicker) {
            StreamSelectionSheet(
                mediaItem: selectedMediaItem,
                links: scrapedLinks,
                isLoading: isFetchingStreams,
                onSelect: { link in
                    showStreamPicker = false
                    Task {
                        await playStream(link: link)
                    }
                },
                onAutoPlayBest: {
                    showStreamPicker = false
                    Task {
                        await autoPlayTopLink()
                    }
                }
            )
            .frame(minWidth: 750, idealWidth: 880, minHeight: 520, idealHeight: 640)
        }
        .sheet(isPresented: $showProfileModal) {
            UserProfileView(
                viewModel: viewModel,
                onSelectMediaItem: { media in
                    withAnimation {
                        detailMediaItem = media
                    }
                },
                onSelectTorrentLink: { linkString in
                    showProfileModal = false
                    Task {
                        await playDirectLink(linkString)
                    }
                }
            )
        }
        .sheet(isPresented: $accountManager.showAccountModal) {
            AccountSetupView {
                accountManager.showAccountModal = false
                WatchlistManager.shared.reloadForCurrentProfile()
                viewModel.fetchContent()
            }
            .frame(minWidth: 880, idealWidth: 940, minHeight: 650, idealHeight: 720)
        }
        .onChange(of: accountManager.activeAccount?.id) { _, newId in
            if newId != nil {
                WatchlistManager.shared.reloadForCurrentProfile()
                viewModel.fetchContent()
            }
        }
        .alert("Playback Notice", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
            Button("Choose Alternative Source") {
                errorMessage = nil
                showStreamPicker = true
            }
        } message: {
            Text(errorMessage ?? "Unable to start stream")
        }
        .overlay {
            // Mid-Screen Detail Modal Overlay
            if let item = detailMediaItem, !showPlayer {
                MediaDetailView(
                    item: item,
                    onPlay: { itemToPlay, season, episode in
                        Task {
                            await selectMediaAndScrape(itemToPlay, season: season, episode: episode)
                        }
                    },
                    onDismiss: {
                        withAnimation {
                            detailMediaItem = nil
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(150)
            }
        }
        .onAppear {
            viewModel.fetchContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenProfileSettings"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentTab = .settings
            }
        }
    }

    @MainActor
    private func selectMediaAndScrape(_ item: MediaItem, season: Int? = nil, episode: Int? = nil) async {
        selectedMediaItem = item
        playingSeason = season
        playingEpisode = episode
        isFetchingStreams = true
        scrapedLinks = []
        showStreamPicker = true

        do {
            let links = try await AggregatorService().fetchBestLinks(tmdbID: item.id, imdbID: item.imdbID, type: item.type, season: season, episode: episode)
            scrapedLinks = links
            isFetchingStreams = false
        } catch {
            isFetchingStreams = false
            errorMessage = "Scraper error: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func autoPlayTopLink() async {
        guard !scrapedLinks.isEmpty else { return }
        isFetchingStreams = true

        do {
            let (url, resolvedLink) = try await AggregatorService().resolveStreamURLWithFallback(startingLink: scrapedLinks[0], allLinks: scrapedLinks)
            isFetchingStreams = false
            print("Successfully resolved stream via fallback: \(resolvedLink.title)")

            if Config.defaultPlayerSelection != "native",
               let ext = ExternalPlayer(rawValue: Config.defaultPlayerSelection.uppercased()) ?? ExternalPlayer.allCases.first(where: { $0.rawValue.lowercased() == Config.defaultPlayerSelection.lowercased() }),
               ext.isInstalled {
                let resumeTime = selectedMediaItem.flatMap { WatchlistManager.shared.getResumeTime(id: $0.id, season: playingSeason, episode: playingEpisode) }
                ext.open(url: url, startTime: resumeTime)
                if let media = selectedMediaItem {
                    WatchlistManager.shared.recordHistory(item: media, season: playingSeason, episode: playingEpisode, progress: resumeTime ?? 0, duration: 0)
                }
                return
            }

            self.selectedStreamURL = url
            self.showPlayer = true
        } catch {
            isFetchingStreams = false
            self.errorMessage = "Failed to resolve stream: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func playStream(link: AggregatedLink) async {
        isFetchingStreams = true
        do {
            let (url, _) = try await AggregatorService().resolveStreamURLWithFallback(startingLink: link, allLinks: scrapedLinks)
            isFetchingStreams = false

            if Config.defaultPlayerSelection != "native",
               let ext = ExternalPlayer(rawValue: Config.defaultPlayerSelection.uppercased()) ?? ExternalPlayer.allCases.first(where: { $0.rawValue.lowercased() == Config.defaultPlayerSelection.lowercased() }),
               ext.isInstalled {
                let resumeTime = selectedMediaItem.flatMap { WatchlistManager.shared.getResumeTime(id: $0.id, season: playingSeason, episode: playingEpisode) }
                ext.open(url: url, startTime: resumeTime)
                if let media = selectedMediaItem {
                    WatchlistManager.shared.recordHistory(item: media, season: playingSeason, episode: playingEpisode, progress: resumeTime ?? 0, duration: 0)
                }
                return
            }

            self.selectedStreamURL = url
            self.showPlayer = true
        } catch {
            isFetchingStreams = false
            errorMessage = "Failed to resolve stream: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func playDirectLink(_ linkString: String) async {
        guard let directCandidate = URL(string: linkString), directCandidate.scheme == "http" || directCandidate.scheme == "https" else {
            errorMessage = "Invalid video stream URL: \(linkString)"
            return
        }

        // Direct media links (e.g. MP4, MKV, M3U8, demo streams) can be played directly
        let ext = directCandidate.pathExtension.lowercased()
        if ["mp4", "mkv", "m3u8", "mov", "webm", "ts"].contains(ext) || linkString.contains("commondatastorage.googleapis.com") || linkString.contains("googlevideo.com") {
            if Config.defaultPlayerSelection != "native",
               let ext = ExternalPlayer(rawValue: Config.defaultPlayerSelection.uppercased()) ?? ExternalPlayer.allCases.first(where: { $0.rawValue.lowercased() == Config.defaultPlayerSelection.lowercased() }),
               ext.isInstalled {
                ext.open(url: directCandidate)
                return
            }

            self.selectedStreamURL = directCandidate
            self.showPlayer = true
            return
        }

        isFetchingStreams = true
        do {
            let rd = RealDebridService()
            let resolved = try await rd.unrestrict(urlString: linkString)
            isFetchingStreams = false

            if Config.defaultPlayerSelection != "native",
               let ext = ExternalPlayer(rawValue: Config.defaultPlayerSelection.uppercased()) ?? ExternalPlayer.allCases.first(where: { $0.rawValue.lowercased() == Config.defaultPlayerSelection.lowercased() }),
               ext.isInstalled {
                ext.open(url: resolved)
                return
            }

            self.selectedStreamURL = resolved
            self.showPlayer = true
        } catch {
            isFetchingStreams = false
            errorMessage = "Failed to unrestrict link: \(error.localizedDescription)"
        }
    }
}

// MARK: - Stream Selection Sheet
struct StreamSelectionSheet: View {
    let mediaItem: MediaItem?
    let links: [AggregatedLink]
    let isLoading: Bool
    var onSelect: (AggregatedLink) -> Void
    var onAutoPlayBest: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: String = "All"

    var filteredLinks: [AggregatedLink] {
        var base = links
        if Config.showOnlyCachedResults {
            base = base.filter { $0.isCached }
        }

        switch selectedFilter {
        case "4K": return base.filter { $0.quality == "4K" }
        case "FHD": return base.filter { $0.quality == "FHD" }
        case "Cached": return base.filter { $0.isCached }
        case "HDR/DV": return base.filter { $0.hdrTag != nil }
        default: return base
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                        Text("Finding streams…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                } else if links.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 46))
                            .foregroundColor(.white.opacity(0.4))
                        Text("No Streams Available")
                            .font(.custom("Baskerville", size: 24))
                            .foregroundColor(.white)
                        Text(StremioAddonManager.shared.installedAddons.isEmpty ? "No active stream add-ons installed. Install a community add-on in Settings > Add-ons to resolve streams." : "None of your installed add-ons returned playable streams for this title.")
                            .font(.custom("Helvetica", size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if StremioAddonManager.shared.installedAddons.isEmpty {
                            Button("Manage Add-ons in Settings") {
                                dismiss()
                                NotificationCenter.default.post(name: NSNotification.Name("OpenProfileSettings"), object: nil)
                            }
                            .font(.custom("Helvetica", size: 13).weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                        }
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {

                        // Quick Action Header Bar
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(filteredLinks.count) Streams Found")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)

                                if Config.showOnlyCachedResults {
                                    Text("Instant streams only")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(SoftTone.sage.color)
                                }
                            }

                            Spacer()

                            Button(action: onAutoPlayBest) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                    Text("Play Best")
                                }
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        // Filter Chips Bar
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                FilterChip(title: "All (\(links.count))", isSelected: selectedFilter == "All") {
                                    selectedFilter = "All"
                                }
                                FilterChip(title: "4K UHD (\(links.filter { $0.quality == "4K" }.count))", isSelected: selectedFilter == "4K") {
                                    selectedFilter = "4K"
                                }
                                FilterChip(title: "1080p FHD (\(links.filter { $0.quality == "FHD" }.count))", isSelected: selectedFilter == "FHD") {
                                    selectedFilter = "FHD"
                                }
                                FilterChip(title: "Instant (\(links.filter { $0.isCached }.count))", isSelected: selectedFilter == "Cached") {
                                    selectedFilter = "Cached"
                                }
                                FilterChip(title: "HDR & DV (\(links.filter { $0.hdrTag != nil }.count))", isSelected: selectedFilter == "HDR/DV") {
                                    selectedFilter = "HDR/DV"
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        List {
                            ForEach(filteredLinks) { link in
                                Button(action: { onSelect(link) }) {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack(spacing: 8) {
                                                Text(mediaItem?.title ?? "Media")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                StreamAttributeRow(link: link)
                                            }

                                            Text(link.fileName)
                                                .font(.system(size: 11, weight: .regular))
                                                .foregroundColor(.white.opacity(0.45))
                                                .lineLimit(2)
                                        }

                                        Spacer()

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.85))
                                            .frame(width: 30, height: 30)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(Circle())
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Color.white.opacity(0.03))
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(mediaItem != nil ? mediaItem!.title : "Available Streams")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Content View Model (Powered by Live Catalog Sync System)
@MainActor
class ContentViewModel: ObservableObject {
    @Published var liveCatalogs: [LiveCatalog] = []
    @Published var featuredHeroItems: [MediaItem] = []

    @Published var trendingMovies: [MediaItem] = []
    @Published var popularMovies: [MediaItem] = []
    @Published var popularSeries: [MediaItem] = []
    @Published var topRatedMovies: [MediaItem] = []
    @Published var actionMovies: [MediaItem] = []
    @Published var curatedCollections: [CuratedCollection] = []

    @Published var searchResults: [MediaItem] = []
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var isSearching: Bool = false
    @Published var errorMessage: String? = nil
    @Published var realDebridUser: RealDebridUser? = nil
    @Published var realDebridTorrents: [RealDebridTorrentItem] = []

    private let realDebridService = RealDebridService()
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>? = nil

    init() {
        // Observe LiveCatalogService updates
        LiveCatalogService.shared.$catalogs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cats in
                self?.syncFromLiveCatalogs(cats)
            }
            .store(in: &cancellables)

        LiveCatalogService.shared.$featuredHeroItems
            .receive(on: DispatchQueue.main)
            .assign(to: &$featuredHeroItems)

        // As-you-type search with 300ms debounce
        $searchQuery
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    private func syncFromLiveCatalogs(_ cats: [LiveCatalog]) {
        self.liveCatalogs = cats

        if let latest = cats.first(where: { $0.id.contains("tmdb_latest") && $0.type == "movie" && !$0.items.isEmpty }) {
            self.trendingMovies = latest.items
        } else if let firstNonEmpty = cats.first(where: { !$0.items.isEmpty && $0.type == "movie" }) {
            self.trendingMovies = firstNonEmpty.items
        }

        if let popular = cats.first(where: { $0.id.contains("trakt_popular") && $0.type == "movie" && !$0.items.isEmpty }) {
            self.popularMovies = popular.items
        }

        if let series = cats.first(where: { ($0.id.contains("tmdb_latest_shows") || $0.id.contains("trakt_trending")) && $0.type == "series" && !$0.items.isEmpty }) {
            self.popularSeries = series.items
        }

        if let top = cats.first(where: { ($0.id.contains("imdb_top_rated_movies") || $0.id.contains("tmdb_today")) && !$0.items.isEmpty }) {
            self.topRatedMovies = top.items
        }

        if let mindfuck = cats.first(where: { ($0.id.contains("best_mindfucks") || $0.id.contains("a24")) && !$0.items.isEmpty }) {
            self.actionMovies = mindfuck.items
        }
    }

    func fetchContent() {
        isLoading = true
        errorMessage = nil

        Task {
            // 1. Fetch Real-Debrid User Status for active profile
            if Config.realDebridApiKey.isEmpty {
                self.realDebridUser = nil
            } else if let user = try? await realDebridService.fetchUser() {
                self.realDebridUser = user
            } else {
                self.realDebridUser = nil
            }

            // 2. Sync all Live Catalogs in parallel from live endpoints
            await LiveCatalogService.shared.syncAllCatalogs()
            self.isLoading = false
        }
    }

    func performSearch(query: String? = nil) {
        let trimmed = (query ?? searchQuery).trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()

        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            do {
                let results = try await LiveCatalogService.shared.searchLive(query: trimmed)
                guard !Task.isCancelled else { return }
                self.searchResults = results
                self.isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.isSearching = false
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        searchQuery = ""
        searchResults = []
        isSearching = false
    }

    func fetchRealDebridTorrents() {
        Task {
            if let torrents = try? await realDebridService.fetchTorrents() {
                self.realDebridTorrents = torrents
            }
        }
    }
}
