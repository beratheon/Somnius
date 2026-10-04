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
    @State private var showStreamPicker: Bool = false
    @State private var showProfileModal: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            // Dark Minimal Background
            Color(red: 0.07, green: 0.07, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "play.tv.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text("Debrid Streamer")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Search Bar Widget in Header
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search movies, TV series...", text: $viewModel.searchQuery)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .onSubmit {
                                viewModel.performSearch()
                            }
                        if !viewModel.searchQuery.isEmpty {
                            Button(action: { viewModel.clearSearch() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(18)
                    .frame(width: 280)

                    Spacer()

                    Button(action: {
                        showProfileModal = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text(viewModel.realDebridUser != nil ? viewModel.realDebridUser!.username : "My Profile")
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.6))

                // Discovery View
                ContentDiscoveryView(
                    viewModel: viewModel,
                    onMediaSelected: { item in
                        withAnimation {
                            detailMediaItem = item
                        }
                    },
                    onOpenProfile: {
                        showProfileModal = true
                    }
                )
            }

            // Internal Player View Fullscreen Sheet / Overlay
            if showPlayer, let url = selectedStreamURL {
                PlayerView(
                    streamURL: url,
                    mediaItem: selectedMediaItem,
                    currentSeason: playingSeason,
                    currentEpisode: playingEpisode,
                    onDismiss: {
                        showPlayer = false
                        selectedStreamURL = nil
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .preferredColorScheme(.dark)
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
            if let item = detailMediaItem {
                MediaDetailView(
                    item: item,
                    onPlay: { itemToPlay, season, episode in
                        withAnimation {
                            detailMediaItem = nil
                        }
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
            let links = try await AggregatorService().fetchBestLinks(tmdbID: item.id, type: item.type, season: season, episode: episode)
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
            self.selectedStreamURL = url
            self.showPlayer = true
        } catch {
            isFetchingStreams = false
            errorMessage = "Failed to resolve stream: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func playDirectLink(_ linkString: String) async {
        isFetchingStreams = true
        do {
            let rd = RealDebridService()
            let resolved = try await rd.unrestrict(urlString: linkString)
            isFetchingStreams = false
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
        case "Zilean & Bitmagnet": return base.filter { $0.source.contains("Zilean") || $0.source.contains("Bitmagnet") }
        case "Torrentio": return base.filter { $0.source.contains("Torrentio") }
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
                            .scaleEffect(1.4)
                            .tint(.purple)
                        Text("Scraping Zilean, Bitmagnet, PirateBay & Torrentio Indexers...")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Searching 4K UHD, Dolby Vision, REMUX, and cached Debrid sources...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else if links.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)
                        Text("No Streams Found")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Verify your RealDebrid API key in settings or try another item.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        // Quick Action Header Bar
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(filteredLinks.count) Streams Found")
                                    .font(.headline.bold())
                                    .foregroundColor(.white)

                                if Config.showOnlyCachedResults {
                                    Text("⚡ Filtered: Showing Only Cached Streams")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                }
                            }

                            Spacer()

                            Button(action: onAutoPlayBest) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                    Text("Auto-Play Best Source")
                                }
                                .font(.subheadline.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(20)
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
                                FilterChip(title: "Zilean & Bitmagnet (\(links.filter { $0.source.contains("Zilean") || $0.source.contains("Bitmagnet") }.count))", isSelected: selectedFilter == "Zilean & Bitmagnet") {
                                    selectedFilter = "Zilean & Bitmagnet"
                                }
                                FilterChip(title: "Torrentio (\(links.filter { $0.source.contains("Torrentio") }.count))", isSelected: selectedFilter == "Torrentio") {
                                    selectedFilter = "Torrentio"
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        List {
                            ForEach(filteredLinks) { link in
                                Button(action: { onSelect(link) }) {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 6) {
                                                Text(link.resolutionBadge)
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(qualityColor(link.quality))
                                                    .foregroundColor(.white)
                                                    .clipShape(Capsule())

                                                if link.isCached {
                                                    Text("⚡ RD+ Cached")
                                                        .font(.caption.bold())
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.green.opacity(0.25))
                                                        .foregroundColor(.green)
                                                        .cornerRadius(6)
                                                }

                                                if let hdr = link.hdrTag {
                                                    Text(hdr)
                                                        .font(.caption.bold())
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.purple.opacity(0.3))
                                                        .foregroundColor(.purple)
                                                        .cornerRadius(6)
                                                }

                                                if let audio = link.audioTag {
                                                    Text(audio)
                                                        .font(.caption.bold())
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.blue.opacity(0.3))
                                                        .foregroundColor(.cyan)
                                                        .cornerRadius(6)
                                                }

                                                if let codec = link.codecTag {
                                                    Text(codec)
                                                        .font(.caption.bold())
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.white.opacity(0.12))
                                                        .foregroundColor(.white.opacity(0.7))
                                                        .cornerRadius(6)
                                                }

                                                if link.isBestInCategory {
                                                    Text("✨ Top Pick")
                                                        .font(.caption.bold())
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.yellow.opacity(0.25))
                                                        .foregroundColor(.yellow)
                                                        .cornerRadius(6)
                                                }

                                                Spacer()

                                                Text(link.source)
                                                    .font(.caption.bold())
                                                    .foregroundColor(.gray)
                                            }

                                            Text(link.title)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.white)
                                                .lineLimit(1)

                                            Text(link.rawTitle)
                                                .font(.caption)
                                                .foregroundColor(.gray.opacity(0.8))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        HStack(spacing: 4) {
                                            Image(systemName: "play.circle.fill")
                                                .font(.title3)
                                            Text("Play")
                                                .font(.subheadline.bold())
                                        }
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.green.opacity(0.15))
                                        .clipShape(Capsule())
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Color.white.opacity(0.05))
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

    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "4K": return .purple
        case "FHD": return .blue
        case "HD": return .teal
        default: return .gray
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple : Color.white.opacity(0.1))
                .foregroundColor(isSelected ? .white : .gray)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Content View Model
@MainActor
class ContentViewModel: ObservableObject {
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

    private let tmdbService = TMDBService()
    private let realDebridService = RealDebridService()
    private let letterboxdService = LetterboxdService()

    func fetchContent() {
        isLoading = true
        errorMessage = nil

        Task {
            async let trendingTask = (try? tmdbService.fetchTrending()) ?? []
            async let popularTask = (try? tmdbService.fetchPopularMovies()) ?? []
            async let seriesTask = (try? tmdbService.fetchPopularSeries()) ?? []
            async let topRatedTask = (try? tmdbService.fetchTopRatedMovies()) ?? []
            async let actionTask = (try? tmdbService.fetchActionMovies()) ?? []
            async let userTask = try? realDebridService.fetchUser()
            async let curatedTask = letterboxdService.fetchCuratedCollections()

            let trending = await trendingTask
            let popular = await popularTask
            let series = await seriesTask
            let topRated = await topRatedTask
            let action = await actionTask
            let user = await userTask
            let curated = await curatedTask

            self.trendingMovies = trending
            self.popularMovies = popular
            self.popularSeries = series
            self.topRatedMovies = topRated
            self.actionMovies = action
            self.realDebridUser = user
            self.curatedCollections = curated
            self.isLoading = false
        }
    }

    func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        Task {
            do {
                let results = try await tmdbService.search(query: trimmed)
                self.searchResults = results
                self.isSearching = false
            } catch {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.isSearching = false
            }
        }
    }

    func clearSearch() {
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
