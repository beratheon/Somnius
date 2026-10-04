import SwiftUI

struct ContentDiscoveryView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var watchlistManager = WatchlistManager.shared
    var onMediaSelected: (MediaItem) -> Void
    var onOpenProfile: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {

                // 1. Search Results Mode
                if viewModel.isSearching || !viewModel.searchQuery.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Search Results for \"\(viewModel.searchQuery)\"")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Button("Clear") {
                                viewModel.clearSearch()
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)

                        if viewModel.isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                                Spacer()
                            }
                            .padding(.vertical, 40)
                        } else if viewModel.searchResults.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No movies or TV shows found matching '\(viewModel.searchQuery)'")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            if let topMatch = viewModel.searchResults.first {
                                BestMatchSpotlightCard(item: topMatch) {
                                    onMediaSelected(topMatch)
                                }
                                .padding(.horizontal)
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)], spacing: 20) {
                                ForEach(viewModel.searchResults) { item in
                                    MoviePosterCard(item: item)
                                        .onTapGesture {
                                            onMediaSelected(item)
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // 2. Main Catalog Sections Mode
                    let featuredItems = Array(viewModel.trendingMovies.prefix(6))
                    if !featuredItems.isEmpty {
                        HeroView(items: featuredItems) { selectedMedia in
                            onMediaSelected(selectedMedia)
                        }
                    }

                    if let user = viewModel.realDebridUser {
                        RealDebridUserBanner(user: user, onProfileTap: onOpenProfile)
                            .padding(.horizontal)
                    }

                    // Continue Watching Section
                    if !watchlistManager.history.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("⏱️ Continue Watching")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Button("View All") {
                                    onOpenProfile()
                                }
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(watchlistManager.history.prefix(10)) { hist in
                                        ContinueWatchingCard(item: hist) {
                                            onMediaSelected(hist.mediaItem)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    if !viewModel.trendingMovies.isEmpty {
                        ContentSection(title: "🔥 Trending This Week", items: Array(viewModel.trendingMovies.dropFirst(6)), onSelect: onMediaSelected)
                    }

                    if !viewModel.popularSeries.isEmpty {
                        ContentSection(title: "📺 Popular TV Series", items: viewModel.popularSeries, onSelect: onMediaSelected)
                    }

                    if !viewModel.curatedCollections.isEmpty {
                        ForEach(viewModel.curatedCollections) { collection in
                            ContentSection(title: "\(collection.title)", items: collection.items, onSelect: onMediaSelected)
                        }
                    }

                    if !viewModel.topRatedMovies.isEmpty {
                        ContentSection(title: "⭐ Top Rated Masterpieces", items: viewModel.topRatedMovies, onSelect: onMediaSelected)
                    }

                    if !viewModel.actionMovies.isEmpty {
                        ContentSection(title: "💥 Action & Blockbusters", items: viewModel.actionMovies, onSelect: onMediaSelected)
                    }

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading catalog...")
                                .tint(.white)
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Content Section Row
struct ContentSection: View {
    let title: String
    let items: [MediaItem]
    var onSelect: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        MoviePosterCard(item: item)
                            .onTapGesture {
                                onSelect(item)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Movie Poster Card
struct MoviePosterCard: View {
    let item: MediaItem
    @State private var isHovered: Bool = false
    @StateObject private var watchlistManager = WatchlistManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let poster = item.posterUrl {
                    AsyncImage(url: poster) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 140, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let rating = item.rating, rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(6)
                }

                if watchlistManager.isWatchlisted(id: item.id) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption.bold())
                        .foregroundColor(.yellow)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                        .padding(6)
                }
            }

            Text(item.title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - RealDebrid User Banner
struct RealDebridUserBanner: View {
    let user: RealDebridUser
    var onProfileTap: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("RealDebrid Account: \(user.username)")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Status: \(user.type.capitalized) • Points: \(user.points)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Button(action: onProfileTap) {
                Text("Profile & Debrid Cloud")
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

// MARK: - Continue Watching Card
struct ContinueWatchingCard: View {
    let item: WatchHistoryItem
    var onTap: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    if let backdrop = item.mediaItem.backdropUrl ?? item.mediaItem.posterUrl {
                        AsyncImage(url: backdrop) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 220, height: 125)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 220, height: 125)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Play Overlay Badge
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                        )
                        .padding(10)

                    // Progress bar
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

                    if item.mediaItem.type == .series, let s = item.seasonNumber, let e = item.episodeNumber {
                        Text("S\(s) E\(e)")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                    } else {
                        Text("Movie")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: 220)
            .scaleEffect(isHovered ? 1.04 : 1.0)
            .shadow(color: isHovered ? Color.blue.opacity(0.4) : Color.clear, radius: 10)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Best Match Spotlight Card
struct BestMatchSpotlightCard: View {
    let item: MediaItem
    var onPlayTap: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            if let posterURL = item.posterUrl {
                AsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 120, height: 180)
                .cornerRadius(12)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Top Match")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())

                    Text(item.type == .series ? "TV Series" : "Movie")
                        .font(.caption2.bold())
                        .foregroundColor(.gray)
                }

                Text(item.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                if let desc = item.description {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }

                Button(action: onPlayTap) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Watch Now")
                    }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }
}
