import SwiftUI
import Combine

struct ContentView: View {
    @StateObject var theme = sharedTheme
    @StateObject var viewModel = ContentViewModel()

    @State private var selectedMediaItem: MediaItem?
    @State private var scrapedLinks: [AggregatedLink] = []
    @State private var isFetchingStreams: Bool = false
    @State private var showStreamPicker: Bool = false
    @State private var showAccountSettings: Bool = false
    @State private var selectedStreamURL: URL?
    @State private var showPlayer: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            theme.baseColor.ignoresSafeArea()

            NavigationStack {
                ContentDiscoveryView(
                    viewModel: viewModel,
                    onMediaSelected: { item in
                        Task {
                            await selectMediaAndScrape(item)
                        }
                    },
                    onOpenProfile: {
                        showAccountSettings = true
                    }
                )
                .navigationTitle("Debrid Streamer")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 15) {
                            Button(action: {
                                theme.currentTheme = theme.currentTheme == .miniLEDBlack ? .liquidGlass : .miniLEDBlack
                            }) {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(.white)
                            }

                            Button(action: {
                                showAccountSettings = true
                            }) {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
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
                        }
                    )
                    .frame(minWidth: 700, idealWidth: 850, minHeight: 500, idealHeight: 650)
                }
                .sheet(isPresented: $showAccountSettings) {
                    RealDebridAccountSettingsSheet(
                        viewModel: viewModel,
                        onSelectTorrentLink: { linkString in
                            showAccountSettings = false
                            Task {
                                await playDirectLink(linkString)
                            }
                        }
                    )
                    .frame(minWidth: 650, idealWidth: 750, minHeight: 550, idealHeight: 650)
                }
                .sheet(isPresented: $showPlayer) {
                    if let url = selectedStreamURL {
                        PlayerView(streamURL: url, mediaItem: selectedMediaItem)
                    } else {
                        Color.black
                    }
                }
                .alert("Playback Error", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("OK") { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "Unknown error")
                }
            }

            if isFetchingStreams {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Scraping RealDebrid streams…")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.fetchContent()
        }
    }

    @MainActor
    private func selectMediaAndScrape(_ item: MediaItem) async {
        selectedMediaItem = item
        isFetchingStreams = true
        scrapedLinks = []

        do {
            let links = try await AggregatorService().getBestLinks(tmdbID: item.id, type: item.type)
            scrapedLinks = links
            isFetchingStreams = false
            showStreamPicker = true
        } catch {
            isFetchingStreams = false
            errorMessage = "Scraper error: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func playStream(link: AggregatedLink) async {
        isFetchingStreams = true
        defer { isFetchingStreams = false }

        do {
            let url = try await AggregatorService().resolveStreamURL(for: link)
            selectedStreamURL = url
            showPlayer = true
        } catch {
            errorMessage = "Failed to resolve RealDebrid stream: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func playDirectLink(_ linkString: String) async {
        isFetchingStreams = true
        defer { isFetchingStreams = false }

        do {
            let url = try await RealDebridService().unrestrict(urlString: linkString)
            selectedStreamURL = url
            showPlayer = true
        } catch {
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.3)
                        Text("Searching RealDebrid, Torrentio, Zilean & Bitmagnet...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else if links.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("No RealDebrid streams found")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Try searching for another movie or check your RealDebrid API key.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Available RealDebrid Streams (\(links.count))")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        List {
                            ForEach(links) { link in
                                Button(action: { onSelect(link) }) {
                                    HStack(spacing: 14) {
                                        VStack(spacing: 4) {
                                            Text(link.quality)
                                                .font(.caption.bold())
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(qualityColor(link.quality))
                                                .foregroundColor(.white)
                                                .cornerRadius(6)

                                            if link.isBestInCategory {
                                                Text("Optimal")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.yellow)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                if link.isBestInCategory {
                                                    Text("🏆 Best \(link.quality)")
                                                        .font(.caption2.bold())
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.yellow.opacity(0.2))
                                                        .foregroundColor(.yellow)
                                                        .cornerRadius(4)
                                                }

                                                Text(link.source)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }

                                            Text(link.title)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.white)
                                                .lineLimit(2)
                                        }

                                        Spacer()

                                        HStack(spacing: 6) {
                                            Image(systemName: "play.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.green)
                                            Text("Play")
                                                .font(.headline)
                                                .foregroundColor(.green)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(8)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Color.white.opacity(0.06))
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(mediaItem?.title ?? "Streams")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, idealWidth: 850, minHeight: 500, idealHeight: 650)
    }

    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "4K": return Color.purple
        case "FHD": return Color.blue
        case "HD": return Color.teal
        default: return Color.gray
        }
    }
}

// MARK: - RealDebrid Account Settings & Subtitles Sheet
struct RealDebridAccountSettingsSheet: View {
    @ObservedObject var viewModel: ContentViewModel
    var onSelectTorrentLink: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var inputKey: String = Config.realDebridApiKey
    @State private var selectedLanguage: String = Config.preferredSubtitleLanguage
    @State private var statusMessage: String?
    @State private var isVerifying: Bool = false

    let availableLanguages = [
        ("fr", "French (Français)"),
        ("en", "English"),
        ("es", "Spanish (Español)"),
        ("de", "German (Deutsch)"),
        ("it", "Italian (Italiano)"),
        ("tr", "Turkish (Türkçe)"),
        ("pt", "Portuguese (Português)"),
        ("ru", "Russian (Русский)"),
        ("ja", "Japanese (日本語)"),
        ("zh", "Chinese (中文)")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Subtitle Language Preference Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preferred Subtitle Language")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Select your primary subtitle language. The player will automatically load subtitles in this language and English/Original.")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Picker("Language", selection: $selectedLanguage) {
                                ForEach(availableLanguages, id: \.0) { code, name in
                                    Text(name).tag(code)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .onChange(of: selectedLanguage) { newLang in
                                Config.preferredSubtitleLanguage = newLang
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // API Key Configuration Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RealDebrid API Key Account Input")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Enter your secret RealDebrid API key below. The key will be saved automatically for future sessions.")
                                .font(.caption)
                                .foregroundColor(.gray)

                            HStack {
                                SecureField("Paste RealDebrid API Key...", text: $inputKey)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)

                                Button(action: saveKeyAndVerify) {
                                    if isVerifying {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Save & Connect")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                                .disabled(isVerifying || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            if let msg = statusMessage {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(msg.contains("Success") ? .green : .red)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Connected User Info Banner
                        if let user = viewModel.rdUser {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Connected Account")
                                    .font(.headline)
                                    .foregroundColor(.gray)

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.username)
                                            .font(.title2.bold())
                                            .foregroundColor(.white)
                                        Text(user.email ?? "No email")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(user.type.uppercased())
                                            .font(.caption.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(user.type == "premium" ? Color.green : Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                        if let exp = user.expiration {
                                            Text("Expires: \(exp.prefix(10))")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }

                        // Torrents Cloud List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Debrid Cloud Torrents (\(viewModel.rdTorrents.count))")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)

                            if viewModel.rdTorrents.isEmpty {
                                Text("No active cloud torrents found.")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(viewModel.rdTorrents) { torrent in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(torrent.filename)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)

                                        HStack {
                                            Text("Status: \(torrent.status)")
                                                .font(.caption)
                                                .foregroundColor(torrent.status == "downloaded" ? .green : .orange)

                                            Spacer()

                                            if let links = torrent.links, let first = links.first {
                                                Button(action: { onSelectTorrentLink(first) }) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "play.fill")
                                                        Text("Stream")
                                                    }
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(6)
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("RealDebrid & Subtitle Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 650, idealWidth: 750, minHeight: 550, idealHeight: 650)
        .onAppear {
            inputKey = Config.realDebridApiKey
            selectedLanguage = Config.preferredSubtitleLanguage
        }
    }

    private func saveKeyAndVerify() {
        isVerifying = true
        statusMessage = nil

        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let user = try await RealDebridService().fetchUser(customKey: trimmed)
                Config.realDebridApiKey = trimmed
                await MainActor.run {
                    viewModel.rdUser = user
                    viewModel.fetchContent()
                    statusMessage = "Successfully connected as \(user.username)!"
                    isVerifying = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Connection failed: \(error.localizedDescription)"
                    isVerifying = false
                }
            }
        }
    }
}

// MARK: - View Model
@MainActor
class ContentViewModel: ObservableObject {
    @Published var popularMovies: [MediaItem] = []
    @Published var trendingMovies: [MediaItem] = []
    @Published var searchResults: [MediaItem] = []
    @Published var rdUser: RealDebridUser?
    @Published var rdTorrents: [RealDebridTorrentItem] = []

    @Published var searchQuery: String = "" {
        didSet {
            if oldValue != searchQuery {
                handleSearchQueryChange(searchQuery)
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?

    private let tmdbService = TMDBService()
    private let rdService = RealDebridService()
    private var searchTask: Task<Void, Never>?

    func fetchContent() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            async let trendingTask = (try? tmdbService.fetchTrending()) ?? []
            async let popularTask = (try? tmdbService.fetchPopularMovies()) ?? []
            async let userTask = try? rdService.fetchUser()
            async let torrentsTask = try? rdService.fetchTorrents()

            let (trending, popular, user, torrents) = await (trendingTask, popularTask, userTask, torrentsTask)

            self.trendingMovies = trending
            self.popularMovies = popular
            self.rdUser = user
            self.rdTorrents = torrents ?? []
            self.isLoading = false
        }
    }

    func performSearch() {
        handleSearchQueryChange(searchQuery)
    }

    private func handleSearchQueryChange(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if Task.isCancelled { return }

            do {
                let results = try await tmdbService.search(query: trimmed)
                if !Task.isCancelled {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        if !searchQuery.isEmpty {
            searchQuery = ""
        }
        searchResults = []
        isSearching = false
    }
}
