import SwiftUI

struct UserProfileView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var watchlistManager = WatchlistManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ProfileTab = .history
    @State private var inputKey: String = Config.realDebridAPIKey
    @State private var showOnlyCached: Bool = Config.showOnlyCachedResults
    @State private var statusMessage: String?

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
        .frame(minWidth: 720, idealWidth: 850, minHeight: 520, idealHeight: 640)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .preferredColorScheme(.dark)
        .onAppear {
            inputKey = Config.realDebridAPIKey
            showOnlyCached = Config.showOnlyCachedResults
            viewModel.fetchRealDebridTorrents()
        }
    }

    // Continue Watching Section
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)], spacing: 16) {
                    ForEach(watchlistManager.history) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .bottom) {
                                if let backdrop = item.mediaItem.backdropUrl ?? item.mediaItem.posterUrl {
                                    AsyncImage(url: backdrop) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Color.white.opacity(0.1))
                                    }
                                    .frame(height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                // Play Overlay Button
                                Button(action: {
                                    dismiss()
                                    onSelectMediaItem(item.mediaItem)
                                }) {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 36, height: 36)
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

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.mediaItem.title)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                if let s = item.seasonNumber, let e = item.episodeNumber {
                                    Text("Season \(s) • Episode \(e)")
                                        .font(.caption)
                                        .foregroundColor(.cyan)
                                } else {
                                    Text("Movie")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Media Item Grid (Watchlist / Favorites)
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

    // Debrid Cloud Section
    private var debridCloudSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Active RealDebrid Cloud Downloads")
                .font(.headline.bold())
                .foregroundColor(.white)

            if viewModel.realDebridTorrents.isEmpty {
                Text("No active debrid cloud torrents found.")
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.realDebridTorrents) { torrent in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(torrent.filename)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text("Status: \(torrent.status.capitalized)")
                                .font(.caption)
                                .foregroundColor(.gray)
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

    // Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Player & Scraper Settings")
                .font(.headline.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show Only Cached Results", isOn: $showOnlyCached)
                    .onChange(of: showOnlyCached) { _, newValue in
                        Config.showOnlyCachedResults = newValue
                        statusMessage = newValue ? "Filtering enabled: Showing only cached streams." : "Showing all stream results."
                    }

                Text("When enabled, uncached torrents requiring background debrid processing are hidden.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

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
