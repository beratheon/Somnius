import SwiftUI

struct ContentDiscoveryView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var watchlistManager = WatchlistManager.shared
    @ObservedObject private var liveCatalogService = LiveCatalogService.shared
    var onMediaSelected: (MediaItem) -> Void
    var onOpenProfile: () -> Void

    @State private var selectedCatalogCategory: String = "All"
    @State private var expandedCatalog: (title: String, items: [MediaItem])? = nil

    private let categories = [
        "All",
        "Movies",
        "TV Shows",
        "Trending & Latest",
        "Top Rated & IMDb",
        "Networks & Studios",
        "Curated & Cult",
        "Cinema Decades",
        "My Watchlist"
    ]

    var body: some View {
        Group {
            if let expanded = expandedCatalog {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedCatalog = nil
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Back to Discovery")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Text(expanded.title)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)

                        Text("\(expanded.items.count) titles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())

                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 216, maximum: 245), spacing: 22)], spacing: 26) {
                            ForEach(expanded.items) { item in
                                MoviePosterCard(item: item)
                                    .onTapGesture {
                                        onMediaSelected(item)
                                    }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 32) {

                // 1. Search Results Mode
                if viewModel.isSearching || !viewModel.searchQuery.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Search Results for \"\(viewModel.searchQuery)\"")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button("Clear") {
                                viewModel.clearSearch()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 28)

                        if viewModel.isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.1)
                                Spacer()
                            }
                            .padding(.vertical, 40)
                        } else if viewModel.searchResults.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No movies or TV shows found matching \"\(viewModel.searchQuery)\"")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            if let topMatch = viewModel.searchResults.first {
                                BestMatchSpotlightCard(item: topMatch) {
                                    onMediaSelected(topMatch)
                                }
                                .padding(.horizontal, 28)
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 216, maximum: 245), spacing: 22)], spacing: 26) {
                                ForEach(viewModel.searchResults) { item in
                                    MoviePosterCard(item: item)
                                        .onTapGesture {
                                            onMediaSelected(item)
                                        }
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                } else {
                    // 2. Main Catalog Sections Mode
                    let heroItems = !viewModel.featuredHeroItems.isEmpty ? viewModel.featuredHeroItems : Array(viewModel.trendingMovies.prefix(6))
                    if !heroItems.isEmpty {
                        HeroView(items: heroItems) { selectedMedia in
                            onMediaSelected(selectedMedia)
                        }
                    }

                    // Quiet sync indicator
                    HStack(spacing: 8) {
                        if liveCatalogService.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white.opacity(0.6))
                        }
                        Spacer()
                        Button(action: { viewModel.fetchContent() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.55))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Refresh catalogs")
                        .disabled(liveCatalogService.isSyncing)
                    }
                    .padding(.horizontal, 28)

                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                let isSelected = selectedCatalogCategory == cat
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCatalogCategory = cat
                                    }
                                }) {
                                    Text(cat)
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? Color.white : Color.white.opacity(0.08))
                                        .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.8)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 28)
                    }

                    if let user = viewModel.realDebridUser {
                        RealDebridUserBanner(user: user, onProfileTap: onOpenProfile)
                            .padding(.horizontal, 28)
                    }

                    // Continue Watching Section (Always visible if history exists)
                    if !watchlistManager.history.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Continue Watching")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button("View All") {
                                    onOpenProfile()
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 28)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(watchlistManager.history.prefix(10)) { hist in
                                        ContinueWatchingCard(item: hist) {
                                            onMediaSelected(hist.mediaItem)
                                        }
                                    }
                                }
                                .padding(.horizontal, 28)
                            }
                        }
                    }

                    // Category-Filtered Content Rows
                    if selectedCatalogCategory == "My Watchlist" {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("My Watchlist (\(watchlistManager.watchlist.count))")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)

                            if watchlistManager.watchlist.isEmpty {
                                Text("Your watchlist is empty. Bookmark any title to add it here.")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 24)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 216, maximum: 245), spacing: 22)], spacing: 26) {
                                    ForEach(watchlistManager.watchlist) { item in
                                        MoviePosterCard(item: item)
                                            .onTapGesture {
                                                onMediaSelected(item)
                                            }
                                    }
                                }
                                .padding(.horizontal, 28)
                            }
                        }
                    } else {
                        // Regular / Filtered sections using live catalogs
                        let filteredCatalogs = viewModel.liveCatalogs.filter { cat in
                            cat.isEnabled && !cat.items.isEmpty && matchesCategoryFilter(catalog: cat, filter: selectedCatalogCategory)
                        }

                        if !filteredCatalogs.isEmpty {
                            ForEach(filteredCatalogs) { catalog in
                                ContentSection(
                                    title: catalogDisplayName(catalog),
                                    items: catalog.items,
                                    onSeeAll: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedCatalog = (title: catalogDisplayName(catalog), items: catalog.items)
                                        }
                                    },
                                    onSelect: onMediaSelected
                                )
                            }
                        } else {
                            // Fallback if live sync is in progress on fresh run
                            if (selectedCatalogCategory == "All" || selectedCatalogCategory == "Movies") && !viewModel.trendingMovies.isEmpty {
                                ContentSection(
                                    title: "Trending Movies",
                                    items: viewModel.trendingMovies,
                                    onSeeAll: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedCatalog = (title: "Trending Movies", items: viewModel.trendingMovies)
                                        }
                                    },
                                    onSelect: onMediaSelected
                                )
                            }
                            if (selectedCatalogCategory == "All" || selectedCatalogCategory == "TV Shows") && !viewModel.popularSeries.isEmpty {
                                ContentSection(
                                    title: "Popular TV Series",
                                    items: viewModel.popularSeries,
                                    onSeeAll: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedCatalog = (title: "Popular TV Series", items: viewModel.popularSeries)
                                        }
                                    },
                                    onSelect: onMediaSelected
                                )
                            }
                            if (selectedCatalogCategory == "All" || selectedCatalogCategory == "Top Rated & IMDb") && !viewModel.topRatedMovies.isEmpty {
                                ContentSection(
                                    title: "Top Rated Masterpieces",
                                    items: viewModel.topRatedMovies,
                                    onSeeAll: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedCatalog = (title: "Top Rated Masterpieces", items: viewModel.topRatedMovies)
                                        }
                                    },
                                    onSelect: onMediaSelected
                                )
                            }
                            }
                        }
                    }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.1)
                        Text("Loading catalog...")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 8)
                        Spacer()
                    }
                    .padding(.vertical, 40)
                }

                // MARK: - Main Page Aesthetic Footer (Somnus & TMDB Attribution)
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.bottom, 6)

                    // Somnus community tagline (No © icon)
                    Text("2026 Somnus — built by the community, for the community.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.42))
                        .tracking(0.2)

                    // TMDB Badge and Attribution
                    HStack(spacing: 12) {
                        // Official TMDB Logo Badge
                        HStack(spacing: 2) {
                            Text("TM")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.05, green: 0.71, blue: 0.83))
                            Text("DB")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.56, green: 0.81, blue: 0.54))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color(red: 0.03, green: 0.15, blue: 0.22).opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color(red: 0.05, green: 0.71, blue: 0.83).opacity(0.35), lineWidth: 0.8)
                        )

                        Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundColor(.white.opacity(0.38))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
    }
    .background(Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea())
}

    private func matchesCategoryFilter(catalog: LiveCatalog, filter: String) -> Bool {
        switch filter {
        case "All":
            return true
        case "Movies":
            return catalog.type == "movie"
        case "TV Shows":
            return catalog.type == "series"
        case "Trending & Latest", "Top Rated & IMDb", "Networks & Studios", "Curated & Cult", "Cinema Decades":
            return catalog.category == filter
        default:
            return true
        }
    }

    private func catalogDisplayName(_ catalog: LiveCatalog) -> String {
        return catalog.name
    }
}

// MARK: - Content Section Row
struct ContentSection: View {
    let title: String
    let items: [MediaItem]
    var onSeeAll: (() -> Void)? = nil
    var onSelect: (MediaItem) -> Void

    @State private var scrollIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button(action: {
                    onSeeAll?()
                }) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if let onSeeAll = onSeeAll {
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text("See All (\(items.count))")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }

                // Left (≤) and Right (≥) Navigation Buttons
                if items.count > 4 {
                    HStack(spacing: 6) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollIndex = max(0, scrollIndex - 4)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(scrollIndex > 0 ? .white : .white.opacity(0.25))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(scrollIndex > 0 ? 0.08 : 0.03))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(scrollIndex > 0 ? 0.14 : 0.05), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .disabled(scrollIndex <= 0)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollIndex = min(max(0, items.count - 1), scrollIndex + 4)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(scrollIndex < items.count - 4 ? .white : .white.opacity(0.25))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(scrollIndex < items.count - 4 ? 0.08 : 0.03))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(scrollIndex < items.count - 4 ? 0.14 : 0.05), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .disabled(scrollIndex >= items.count - 4)
                    }
                }
            }
            .padding(.horizontal, 28)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            MoviePosterCard(item: item)
                                .id(index)
                                .onTapGesture {
                                    onSelect(item)
                                }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .onChange(of: scrollIndex) { _, newIdx in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIdx, anchor: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Movie Poster Card (Apple TV+ / macOS Native Style - 75% Larger)
struct MoviePosterCard: View {
    let item: MediaItem
    var posterWidth: CGFloat = 216
    var posterHeight: CGFloat = 324
    @State private var isHovered: Bool = false
    @ObservedObject private var watchlistManager = WatchlistManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CachedImage(url: item.posterUrl, maxPixel: 700)
                    .frame(width: posterWidth, height: posterHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .grayscale(isHovered ? 0.0 : 0.45)
                    .contrast(isHovered ? 1.0 : 1.08)
                    .saturation(isHovered ? 1.0 : 0.88)
                    .brightness(isHovered ? 0.0 : -0.02)
                    .scaleEffect(isHovered ? 1.025 : 1.0)

                // Sleek Monochromatic Rating Badge
                if let rating = item.rating, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(SoftTone.sand.color)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(isHovered ? 0.75 : 0.55))
                    .clipShape(Capsule())
                    .padding(10)
                }

                // Watchlist Bookmark Badge
                if watchlistManager.isWatchlisted(id: item.id) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.black.opacity(isHovered ? 0.75 : 0.55))
                        .clipShape(Circle())
                        .padding(10)
                }

                // Series Episode Watched Progress Badge
                if item.type == .series {
                    let watchedCount = watchlistManager.watchedCount(showID: item.id)
                    if watchedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color.green)
                            Text("\(watchedCount) watched")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.black.opacity(0.82))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                } else if watchlistManager.isMovieWatched(id: item.id) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.green)
                        Text("Watched")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.black.opacity(0.82))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovered ? Color.white.opacity(0.38) : Color.white.opacity(0.09), lineWidth: 1)
            )
            .help(item.title)
        }
        .animation(.easeInOut(duration: 0.35), value: isHovered)
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
                    .font(.system(size: 22))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Debrid Cloud: \(user.username)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Status: \(user.type.capitalized) • Points: \(user.points)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            Button(action: onProfileTap) {
                Text("Manage Cloud")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
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
                    CachedImage(url: item.mediaItem.backdropUrl ?? item.mediaItem.posterUrl, maxPixel: 520)
                        .frame(width: 230, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Play Overlay Badge
                    Circle()
                        .fill(Color.black.opacity(isHovered ? 0.7 : 0.45))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: 1)
                        )
                        .padding(10)

                    // Minimalist Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.black.opacity(0.6))
                                .frame(height: 3)
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geo.size.width * CGFloat(item.progressFraction), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHovered ? 0.25 : 0.08), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.mediaItem.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if item.mediaItem.type == .series, let s = item.seasonNumber, let e = item.episodeNumber {
                        let wCount = WatchlistManager.shared.watchedCount(showID: item.mediaItem.id)
                        Text(wCount > 0 ? "S\(s) E\(e) • \(wCount) watched" : "S\(s) E\(e)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text("Movie")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
            .frame(width: 230)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
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
            CachedImage(url: item.posterUrl, maxPixel: 400)
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("TOP MATCH")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.18))
                        .foregroundColor(.white)
                        .cornerRadius(4)

                    Text(item.type == .series ? "Series" : "Movie")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                if let desc = item.description {
                    Text(desc)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(3)
                        .lineLimit(3)
                }

                Button(action: onPlayTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Watch Now")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
