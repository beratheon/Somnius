import SwiftUI

struct MediaDetailView: View {
    @State private var currentItem: MediaItem
    @State private var navigationStack: [MediaItem] = []
    var onPlay: (MediaItem, Int?, Int?) -> Void // (item, seasonNum, episodeNum)
    var onDismiss: () -> Void

    @State private var totalSeasons: Int = 1
    @State private var selectedSeason: Int = 1
    @State private var seasonsInfo: [TMDBService.TVSeasonInfo] = []
    @State private var episodes: [TVEpisodeItem] = []
    @State private var isLoadingEpisodes: Bool = false
    @State private var hoveredEpisodeID: Int? = nil

    @State private var collectionResult: TMDBService.MovieCollectionResult? = nil
    @State private var isLoadingCollection: Bool = false

    @State private var similarItems: [MediaItem] = []
    @State private var isLoadingSimilar: Bool = false

    @State private var credits: MediaCredits? = nil
    @State private var isLoadingCredits: Bool = false

    @State private var logoURL: URL? = nil
    @State private var isLoadingLogo: Bool = true
    @State private var runtimeMinutes: Int? = nil

    // State for viewing an Actor's / Director's filmography
    @State private var selectedPerson: (id: Int, name: String, role: String, photoURL: URL?, isDirectorSource: Bool)? = nil
    @State private var personCategorizedWorks: TMDBService.PersonCategorizedWorks = TMDBService.PersonCategorizedWorks()
    @State private var isLoadingPersonWorks: Bool = false

    // Tabs & Extras (Trailers, Behind the Scenes, Recaps, Featurettes)
    enum ContentTab {
        case cast
        case extras
    }
    @State private var movieDetailTab: ContentTab = .cast
    @State private var tvDetailTab: ContentTab = .cast
    @State private var extras: [TMDBService.MediaExtra] = []
    @State private var isLoadingExtras: Bool = false

    @ObservedObject private var watchlistManager = WatchlistManager.shared
    @State private var showDownloadSourcesModal: Bool = false
    @State private var downloadSources: [AggregatedLink] = []
    @State private var isLoadingDownloadSources: Bool = false
    private let aggregatorService = AggregatorService()

    private let tmdbService = TMDBService()

    init(item: MediaItem, onPlay: @escaping (MediaItem, Int?, Int?) -> Void, onDismiss: @escaping () -> Void) {
        self._currentItem = State(initialValue: item)
        self.onPlay = onPlay
        self.onDismiss = onDismiss
        let initialLogo = item.initialLogoURL
        self._logoURL = State(initialValue: initialLogo)
        self._isLoadingLogo = State(initialValue: initialLogo == nil)
    }

    var body: some View {
        ZStack(alignment: .center) {
            // Dark Frosted Backdrop with Tap-to-Dismiss
            Color.black.opacity(0.75)
                .background(.ultraThinMaterial.opacity(0.6))
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Centered Apple TV+ Style Modal Card - 75% Larger Window (1400x900)
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Hero Backdrop Header (High-Resolution Art & Poster Banner)
                        ZStack(alignment: .bottomLeading) {
                            CachedImage(url: currentItem.backdropUrl ?? currentItem.posterUrl, maxPixel: 2800)
                                .frame(maxWidth: .infinity)
                                .frame(height: 580)
                                .clipped()

                            // Cinematic Progressive Gradients (Bottom + Leading Vignette)
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.5),
                                    Color(red: 0.08, green: 0.08, blue: 0.09)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.92),
                                    Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.55),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 950)

                            // Header Content: Original Title Logo Art & Actions over Cinematic Banner
                            VStack(alignment: .leading, spacing: 14) {
                                // Original Title Logo Art (Never flash classic text title on poster click)
                                if let logo = logoURL {
                                    CachedImage(url: logo, maxPixel: 2000, contentMode: .fit, transparentBackground: true)
                                        .frame(maxWidth: 850, maxHeight: 220, alignment: .leading)
                                        .shadow(color: .black.opacity(0.85), radius: 14, x: 0, y: 6)
                                        .padding(.bottom, 2)
                                } else if !isLoadingLogo {
                                    // Fallback only if logo check completely finished and no logo art exists
                                    Text(currentItem.title)
                                        .font(.system(size: 56, weight: .heavy, design: .default))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.9), radius: 10, x: 0, y: 4)
                                        .lineLimit(2)
                                        .padding(.bottom, 2)
                                } else {
                                    // Clean transparent placeholder frame prevents classic title flashing and layout pop
                                    Color.clear
                                        .frame(maxWidth: 850, maxHeight: 110, alignment: .leading)
                                        .padding(.bottom, 2)
                                }

                                // Streamlined Metadata Row (e.g. "1h 49min   2026   7.8 [IMDb]")
                                HStack(spacing: 16) {
                                    if let runtime = runtimeMinutes, runtime > 0 {
                                        let hours = runtime / 60
                                        let mins = runtime % 60
                                        Text(hours > 0 ? "\(hours)h \(mins)min" : "\(mins)min")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.88))
                                    } else if currentItem.type == .series {
                                        Text("\(totalSeasons) Season\(totalSeasons > 1 ? "s" : "")")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.88))
                                    }

                                    if let date = currentItem.releaseDate {
                                        Text(Calendar.current.component(.year, from: date).description)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.88))
                                    }

                                    if let rating = currentItem.rating, rating > 0 {
                                        HStack(spacing: 5) {
                                            Text(String(format: "%.1f", rating))
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)

                                            // Yellow IMDb Badge
                                            Text("IMDb")
                                                .font(.system(size: 10, weight: .black, design: .rounded))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 4.5)
                                                .padding(.vertical, 2)
                                                .background(Color(red: 0.96, green: 0.77, blue: 0.19))
                                                .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                                        }
                                    }
                                }

                                // Director Badge / Link (Clickable to see Director's Filmography)
                                if let directors = credits?.directors, !directors.isEmpty {
                                    HStack(spacing: 6) {
                                        Text(directors.count > 1 ? "Directed by" : "Director")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.55))

                                        ForEach(directors.prefix(2)) { dir in
                                            Button(action: {
                                                openPersonWorks(id: dir.id, name: dir.name, role: dir.job ?? "Director", photoURL: dir.profileURL, isDirectorSource: true)
                                            }) {
                                                Text(dir.name)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .underline()
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.top, 2)
                                }

                                    // Action Buttons
                                    HStack(spacing: 12) {
                                        // Play / Continue Button
                                        let inWatchlist = watchlistManager.isWatchlisted(id: currentItem.id)
                                        let historyItem = watchlistManager.history.first(where: { $0.mediaItem.id == currentItem.id })
                                        let hasWatchedProgress = (historyItem != nil && historyItem!.progressSeconds > 10)
                                        let shouldShowContinue = inWatchlist && hasWatchedProgress

                                        Button(action: {
                                            if shouldShowContinue, let hist = historyItem {
                                                onPlay(currentItem, hist.seasonNumber ?? (currentItem.type == .series ? selectedSeason : nil), hist.episodeNumber ?? (currentItem.type == .series ? 1 : nil))
                                            } else {
                                                onPlay(currentItem, currentItem.type == .series ? selectedSeason : nil, currentItem.type == .series ? 1 : nil)
                                            }
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: shouldShowContinue ? "arrow.clockwise.circle.fill" : "play.fill")
                                                    .font(.system(size: 14, weight: .bold))
                                                Text(shouldShowContinue ? "Continue" : "Play")
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 28)
                                            .padding(.vertical, 12)
                                            .background(Color.white)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        // Watchlist Button
                                        let isSaved = watchlistManager.isWatchlisted(id: currentItem.id)
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                watchlistManager.toggleWatchlist(currentItem)
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: isSaved ? "checkmark" : "plus")
                                                    .font(.system(size: 13, weight: .bold))
                                                Text(isSaved ? "In Watchlist" : "Watchlist")
                                                    .font(.system(size: 13, weight: .semibold))
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 12)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                        // Download Button (Subtle Default, Shines on Click)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showDownloadSourcesModal = true
                            }
                            loadDownloadSources()
                        }) {
                            HStack(spacing: 7) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Download")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(ShiningDownloadButtonStyle())


                                        // Favorite Button
                                        let isFav = watchlistManager.isFavorite(id: currentItem.id)
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                watchlistManager.toggleFavorite(currentItem)
                                            }
                                        }) {
                                            Image(systemName: isFav ? "heart.fill" : "heart")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(isFav ? .red : .white)
                                                .frame(width: 40, height: 40)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        // Mark as Watched Button (movies)
                                        if currentItem.type == .movie {
                                            let isMovieWatched = watchlistManager.isMovieWatched(id: currentItem.id)
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    watchlistManager.toggleMovieWatched(id: currentItem.id)
                                                }
                                            }) {
                                                Image(systemName: isMovieWatched ? "checkmark.circle.fill" : "checkmark")
                                                    .font(.system(size: isMovieWatched ? 18 : 14, weight: .semibold))
                                                    .foregroundColor(isMovieWatched ? Color.green : .white)
                                                    .frame(width: 40, height: 40)
                                                    .background(.ultraThinMaterial)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(isMovieWatched ? Color.green.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 1))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .help(isMovieWatched ? "Mark as unwatched" : "Mark as watched")
                                        }
                                    }
                                    .padding(.top, 4)

                                    // Plot Overview immediately under Play Button (No "About" header)
                                    if let overview = currentItem.description, !overview.isEmpty {
                                        Text(overview)
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.white.opacity(0.85))
                                            .lineSpacing(4.5)
                                            .lineLimit(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.top, 4)
                                            .frame(maxWidth: 880, alignment: .leading)
                                    }
                                }
                            .padding(32)
                        }

                        // Split Master-Detail Section: TV Seasons & Episodes OR Movie Cast & Extras
                        if currentItem.type == .series {
                            VStack(alignment: .leading, spacing: 20) {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.bottom, 4)

                                // Side-by-side: Season List on Left, Episodes on Right
                                HStack(alignment: .top, spacing: 32) {
                                    // LEFT COLUMN: Seasons list (matches height of episode section, scrolls if many seasons)
                                    ScrollView(.vertical, showsIndicators: false) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            let displaySeasons = seasonsInfo.isEmpty ? (1...max(1, totalSeasons)).map { TMDBService.TVSeasonInfo(seasonNumber: $0, name: "Season \($0)", episodeCount: nil) } : seasonsInfo

                                            ForEach(displaySeasons) { sInfo in
                                                let isSelected = selectedSeason == sInfo.seasonNumber

                                                Button(action: {
                                                    withAnimation(.easeInOut(duration: 0.18)) {
                                                        selectedSeason = sInfo.seasonNumber
                                                    }
                                                    loadEpisodes(seasonNumber: sInfo.seasonNumber)
                                                }) {
                                                    HStack(alignment: .center) {
                                                        Text(sInfo.name)
                                                            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                                                            .foregroundColor(isSelected ? .white : .white.opacity(0.55))

                                                        Spacer(minLength: 8)

                                                        if isSelected, let count = sInfo.episodeCount, count > 0 {
                                                            Text("\(count) episodes")
                                                                .font(.system(size: 12, weight: .regular))
                                                                .foregroundColor(.white.opacity(0.75))
                                                        }
                                                    }
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .stroke(isSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 1.5)
                                                    )
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                    .frame(width: 220, height: 500)

                                    // Vertical Separator
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 1, height: 500)

                                    // RIGHT COLUMN: Season Header & 3-Episode Scrollable Window with Vignette
                                    VStack(alignment: .leading, spacing: 14) {
                                        // Season Header
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Text(seasonsInfo.first(where: { $0.seasonNumber == selectedSeason })?.name ?? "Season \(selectedSeason)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)

                                            // Rating / Classification pill
                                            Text("TV-14")
                                                .font(.system(size: 11, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.12))
                                                .foregroundColor(.white.opacity(0.85))
                                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                                                )

                                            // Mark Entire Season as Watched Button
                                            if !episodes.isEmpty {
                                                let epNums = episodes.map { $0.episodeNumber }
                                                let allSeasonWatched = watchlistManager.isSeasonFullyWatched(showID: currentItem.id, season: selectedSeason, episodeNumbers: epNums)

                                                Button(action: {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        watchlistManager.markSeasonWatched(showID: currentItem.id, season: selectedSeason, episodeNumbers: epNums, watched: !allSeasonWatched)
                                                    }
                                                }) {
                                                    HStack(spacing: 5) {
                                                        Image(systemName: allSeasonWatched ? "checkmark.circle.fill" : "checkmark.circle")
                                                            .font(.system(size: 11, weight: .bold))
                                                        Text(allSeasonWatched ? "Season Watched" : "Mark Season Watched")
                                                            .font(.system(size: 11, weight: .semibold))
                                                    }
                                                    .foregroundColor(allSeasonWatched ? Color.green : Color.white.opacity(0.8))
                                                    .padding(.horizontal, 9)
                                                    .padding(.vertical, 3.5)
                                                    .background(Color.white.opacity(allSeasonWatched ? 0.12 : 0.08))
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(allSeasonWatched ? Color.green.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 0.8))
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .help(allSeasonWatched ? "Mark season as unwatched" : "Mark all episodes in season as watched")
                                            }

                                            Spacer()
                                        }

                                        // Episodes Content: 3-Episode Viewport with Internal Scrolling & Bottom Vignette
                                        if isLoadingEpisodes {
                                            HStack {
                                                Spacer()
                                                ProgressView()
                                                    .tint(.white)
                                                    .scaleEffect(1.0)
                                                Text("Loading episodes...")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundColor(.gray)
                                                    .padding(.leading, 8)
                                                Spacer()
                                            }
                                            .frame(height: 450)
                                        } else if episodes.isEmpty {
                                            HStack {
                                                Spacer()
                                                Text("No episode data available for Season \(selectedSeason).")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                Spacer()
                                            }
                                            .frame(height: 450)
                                        } else {
                                            ZStack(alignment: .bottom) {
                                                ScrollView(.vertical, showsIndicators: true) {
                                                    VStack(spacing: 12) {
                                                        ForEach(episodes) { ep in
                                                            let isHovered = hoveredEpisodeID == ep.id
                                                            let isWatched = watchlistManager.isEpisodeWatched(showID: currentItem.id, season: selectedSeason, episode: ep.episodeNumber)

                                                            Button(action: {
                                                                onPlay(currentItem, selectedSeason, ep.episodeNumber)
                                                            }) {
                                                                HStack(alignment: .top, spacing: 18) {
                                                                    // Compact 16:9 Thumbnail with S:E Badge Overlay
                                                                    ZStack(alignment: .bottomLeading) {
                                                                        CachedImage(url: ep.stillURL, maxPixel: 600)
                                                                            .aspectRatio(16/9, contentMode: .fill)
                                                                            .frame(width: 240, height: 135)
                                                                            .clipped()
                                                                            .background(Color.white.opacity(0.04))
                                                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                                            .overlay(
                                                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                                    .stroke(isHovered ? Color.white.opacity(0.7) : Color.white.opacity(0.1), lineWidth: isHovered ? 1.5 : 1)
                                                                            )

                                                                        // S:E Badge Overlay on bottom-left of picture
                                                                        Text("S\(selectedSeason): E\(ep.episodeNumber)")
                                                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                                            .foregroundColor(.white)
                                                                            .padding(.horizontal, 7)
                                                                            .padding(.vertical, 3.5)
                                                                            .background(Color.black.opacity(0.78))
                                                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                                                            .padding(8)

                                                                        // Watched indicator badge on top-right of thumbnail
                                                                        if isWatched {
                                                                            HStack(spacing: 3) {
                                                                                Image(systemName: "checkmark")
                                                                                    .font(.system(size: 8.5, weight: .black))
                                                                                Text("WATCHED")
                                                                                    .font(.system(size: 8.5, weight: .heavy))
                                                                            }
                                                                            .foregroundColor(.white)
                                                                            .padding(.horizontal, 6)
                                                                            .padding(.vertical, 3)
                                                                            .background(Color.green.opacity(0.92))
                                                                            .clipShape(Capsule())
                                                                            .padding(7)
                                                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                                                        }

                                                                        // Play Icon on Hover
                                                                        if isHovered {
                                                                            Circle()
                                                                                .fill(Color.black.opacity(0.65))
                                                                                .frame(width: 38, height: 38)
                                                                                .overlay(
                                                                                    Image(systemName: "play.fill")
                                                                                        .font(.system(size: 15, weight: .bold))
                                                                                        .foregroundColor(.white)
                                                                                        .offset(x: 1.5)
                                                                                )
                                                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                                                        }
                                                                    }
                                                                    .frame(width: 240, height: 135)

                                                                    // Title, Overview & Duration
                                                                    VStack(alignment: .leading, spacing: 6) {
                                                                        Text(ep.name)
                                                                            .font(.system(size: 15, weight: .bold))
                                                                            .foregroundColor(isHovered ? .white : .white.opacity(0.95))
                                                                            .lineLimit(1)

                                                                        if let plot = ep.overview, !plot.isEmpty {
                                                                            Text(plot)
                                                                                .font(.system(size: 13, weight: .regular))
                                                                                .foregroundColor(.white.opacity(0.65))
                                                                                .lineSpacing(3)
                                                                                .lineLimit(3)
                                                                                .fixedSize(horizontal: false, vertical: true)
                                                                        }

                                                                        if let runtime = ep.runtime, runtime > 0 {
                                                                            Text("(\(runtime)m)")
                                                                                .font(.system(size: 12, weight: .medium))
                                                                                .foregroundColor(.white.opacity(0.5))
                                                                                .padding(.top, 2)
                                                                        }

                                                                        Spacer(minLength: 0)
                                                                    }

                                                                    Spacer(minLength: 0)

                                                                    // Single Episode Mark Watched Button
                                                                    Button(action: {
                                                                        withAnimation(.easeInOut(duration: 0.18)) {
                                                                            watchlistManager.toggleEpisodeWatched(showID: currentItem.id, season: selectedSeason, episode: ep.episodeNumber)
                                                                        }
                                                                    }) {
                                                                        Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                                                                            .font(.system(size: 18, weight: .semibold))
                                                                            .foregroundColor(isWatched ? Color.green : Color.white.opacity(0.3))
                                                                            .padding(6)
                                                                            .background(Color.white.opacity(isWatched ? 0.12 : 0.04))
                                                                            .clipShape(Circle())
                                                                    }
                                                                    .buttonStyle(PlainButtonStyle())
                                                                    .help(isWatched ? "Mark episode as unwatched" : "Mark episode as watched")
                                                                }
                                                                .padding(8)
                                                                .background(
                                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                        .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
                                                                )
                                                                .contentShape(Rectangle())
                                                            }
                                                            .buttonStyle(PlainButtonStyle())
                                                            .onHover { h in
                                                                hoveredEpisodeID = h ? ep.id : nil
                                                            }
                                                        }
                                                    }
                                                    .padding(.trailing, 8)
                                                    .padding(.bottom, 50)
                                                }

                                                // Bottom vignette so episodes scroll smoothly under a soft fade
                                                LinearGradient(
                                                    colors: [
                                                        Color.clear,
                                                        Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.85),
                                                        Color(red: 0.08, green: 0.08, blue: 0.09)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                                .frame(height: 55)
                                                .allowsHitTesting(false)
                                            }
                                            .frame(height: 450)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 32)
                        } else {
                            // Split Master-Detail Section for Movies: Cast & Extras (matches TV seasons & episodes layout)
                            VStack(alignment: .leading, spacing: 20) {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.bottom, 4)

                                // Side-by-side: Cast / Extras tabs on Left, Content on Right
                                HStack(alignment: .top, spacing: 32) {
                                    // LEFT COLUMN: "Cast & Crew" and "Extras & Recaps" tabs
                                    ScrollView(.vertical, showsIndicators: false) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Cast Tab Button
                                            let isCastSelected = movieDetailTab == .cast
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.18)) {
                                                    movieDetailTab = .cast
                                                }
                                            }) {
                                                HStack(alignment: .center) {
                                                    Text("Cast & Crew")
                                                        .font(.system(size: 15, weight: isCastSelected ? .bold : .medium))
                                                        .foregroundColor(isCastSelected ? .white : .white.opacity(0.55))

                                                    Spacer(minLength: 8)

                                                    if let castCount = credits?.cast.count, castCount > 0 {
                                                        Text("\(castCount) actors")
                                                            .font(.system(size: 12, weight: .regular))
                                                            .foregroundColor(.white.opacity(0.75))
                                                    }
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(isCastSelected ? Color.white.opacity(0.08) : Color.clear)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .stroke(isCastSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 1.5)
                                                )
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(PlainButtonStyle())

                                            // Extras & Recaps Tab Button
                                            let isExtrasSelected = movieDetailTab == .extras
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.18)) {
                                                    movieDetailTab = .extras
                                                }
                                            }) {
                                                HStack(alignment: .center) {
                                                    Text("Extras & Recaps")
                                                        .font(.system(size: 15, weight: isExtrasSelected ? .bold : .medium))
                                                        .foregroundColor(isExtrasSelected ? .white : .white.opacity(0.55))

                                                    Spacer(minLength: 8)

                                                    if !extras.isEmpty {
                                                        Text("\(extras.count) videos")
                                                            .font(.system(size: 12, weight: .regular))
                                                            .foregroundColor(.white.opacity(0.75))
                                                    }
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(isExtrasSelected ? Color.white.opacity(0.08) : Color.clear)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .stroke(isExtrasSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 1.5)
                                                )
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .frame(width: 220, height: 500)

                                    // Vertical Separator
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 1, height: 500)

                                    // RIGHT COLUMN: Selected Movie Tab Content with 500pt height & Bottom Vignette
                                    VStack(alignment: .leading, spacing: 14) {
                                        if movieDetailTab == .cast {
                                            // Cast Header
                                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                                Text("Top Cast & Crew")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(.white)

                                                if let castCount = credits?.cast.count {
                                                    Text("\(castCount) actors")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.white.opacity(0.12))
                                                        .foregroundColor(.white.opacity(0.85))
                                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                                }

                                                Spacer()
                                            }

                                            if isLoadingCredits {
                                                HStack {
                                                    Spacer()
                                                    ProgressView()
                                                        .tint(.white)
                                                    Text("Loading cast & crew...")
                                                        .font(.caption.weight(.medium))
                                                        .foregroundColor(.gray)
                                                        .padding(.leading, 8)
                                                    Spacer()
                                                }
                                                .frame(height: 450)
                                            } else if let castList = credits?.cast, !castList.isEmpty {
                                                ZStack(alignment: .bottom) {
                                                    ScrollView(.vertical, showsIndicators: true) {
                                                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 12) {
                                                            ForEach(castList) { actor in
                                                                Button(action: {
                                                                    openPersonWorks(id: actor.id, name: actor.name, role: actor.character ?? "Actor", photoURL: actor.profileURL, isDirectorSource: false)
                                                                }) {
                                                                    MovieCastRowCard(actor: actor)
                                                                }
                                                                .buttonStyle(PlainButtonStyle())
                                                            }
                                                        }
                                                        .padding(.trailing, 8)
                                                        .padding(.bottom, 50)
                                                    }

                                                    // Vignette
                                                    LinearGradient(
                                                        colors: [
                                                            Color.clear,
                                                            Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.85),
                                                            Color(red: 0.08, green: 0.08, blue: 0.09)
                                                        ],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                    .frame(height: 55)
                                                    .allowsHitTesting(false)
                                                }
                                                .frame(height: 450)
                                            } else {
                                                HStack {
                                                    Spacer()
                                                    Text("No cast details available.")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                    Spacer()
                                                }
                                                .frame(height: 450)
                                            }
                                        } else {
                                            // Extras Header
                                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                                Text("Trailers, Behind the Scenes & Extras")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(.white)

                                                if !extras.isEmpty {
                                                    Text("\(extras.count) videos")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.white.opacity(0.12))
                                                        .foregroundColor(.white.opacity(0.85))
                                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                                }

                                                Spacer()
                                            }

                                            if isLoadingExtras {
                                                HStack {
                                                    Spacer()
                                                    ProgressView()
                                                        .tint(.white)
                                                    Text("Loading extras & videos...")
                                                        .font(.caption.weight(.medium))
                                                        .foregroundColor(.gray)
                                                        .padding(.leading, 8)
                                                    Spacer()
                                                }
                                                .frame(height: 450)
                                            } else if extras.isEmpty {
                                                HStack {
                                                    Spacer()
                                                    Text("No trailers or extras available for this movie.")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                    Spacer()
                                                }
                                                .frame(height: 450)
                                            } else {
                                                ZStack(alignment: .bottom) {
                                                    ScrollView(.vertical, showsIndicators: true) {
                                                        VStack(spacing: 12) {
                                                            ForEach(extras) { extra in
                                                                ExtraRowCard(extra: extra)
                                                            }
                                                        }
                                                        .padding(.trailing, 8)
                                                        .padding(.bottom, 50)
                                                    }

                                                    // Vignette
                                                    LinearGradient(
                                                        colors: [
                                                            Color.clear,
                                                            Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.85),
                                                            Color(red: 0.08, green: 0.08, blue: 0.09)
                                                        ],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                    .frame(height: 55)
                                                    .allowsHitTesting(false)
                                                }
                                                .frame(height: 450)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 32)
                        }

                        // 4. TV Cast & Extras Toggle Section (Only for TV Series, as Movies have Cast & Extras right above)
                        if currentItem.type == .series {
                            VStack(alignment: .leading, spacing: 12) {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.bottom, 2)

                                // Section buttons on top of cast row: [Cast] | [Extras & Recaps]
                                HStack(spacing: 10) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            tvDetailTab = .cast
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Text("Cast")
                                                .font(.system(size: 13, weight: tvDetailTab == .cast ? .bold : .medium))
                                            if let c = credits?.cast.count, c > 0 {
                                                Text("\(c)")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1.5)
                                                    .background(tvDetailTab == .cast ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .foregroundColor(tvDetailTab == .cast ? .black : .white.opacity(0.75))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(tvDetailTab == .cast ? Color.white : Color.white.opacity(0.06))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(tvDetailTab == .cast ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.8))
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            tvDetailTab = .extras
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Text("Extras & Recaps")
                                                .font(.system(size: 13, weight: tvDetailTab == .extras ? .bold : .medium))
                                            if !extras.isEmpty {
                                                Text("\(extras.count)")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1.5)
                                                    .background(tvDetailTab == .extras ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .foregroundColor(tvDetailTab == .extras ? .black : .white.opacity(0.75))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(tvDetailTab == .extras ? Color.white : Color.white.opacity(0.06))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(tvDetailTab == .extras ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.8))
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Spacer()
                                }

                                if tvDetailTab == .cast {
                                    if let castList = credits?.cast, !castList.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            LazyHStack(spacing: 14) {
                                                ForEach(castList) { actor in
                                                    Button(action: {
                                                        openPersonWorks(id: actor.id, name: actor.name, role: actor.character ?? "Actor", photoURL: actor.profileURL, isDirectorSource: false)
                                                    }) {
                                                        ActorCircleCard(actor: actor)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    } else if isLoadingCredits {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Loading Cast...")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .padding(.vertical, 6)
                                    } else {
                                        Text("No cast details available")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.4))
                                            .padding(.vertical, 4)
                                    }
                                } else {
                                    if !extras.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            LazyHStack(spacing: 16) {
                                                ForEach(extras) { extra in
                                                    ExtraHorizontalCard(extra: extra)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    } else if isLoadingExtras {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Loading Extras & Recaps...")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .padding(.vertical, 6)
                                    } else {
                                        Text("No extras or recaps available for this show")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.4))
                                            .padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 20)
                        }

                        // 5. Sequel / Prequel / Franchise Collection Section (Optional - only when movie has collections)
                        if let collection = collectionResult, !collection.items.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.bottom, 6)

                                HStack {
                                    Text(collection.name)
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(collection.items.count) films")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 20) {
                                        ForEach(collection.items) { colItem in
                                            MoviePosterCard(item: colItem)
                                                .onTapGesture {
                                                    switchMedia(to: colItem)
                                                }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 28)
                            .transition(.opacity)
                        } else if isLoadingCollection {
                            VStack(alignment: .leading, spacing: 14) {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.bottom, 6)

                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Checking for Collection & Sequels...")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 16)
                        }

                        // 5. Similar Titles / Recommendations Section (Accurate TMDB / Cinemeta Metadata)
                        if !similarItems.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.bottom, 6)

                                Text("More Like This")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.white)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 20) {
                                        ForEach(similarItems) { simItem in
                                            MoviePosterCard(item: simItem)
                                                .onTapGesture {
                                                    switchMedia(to: simItem)
                                                }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .frame(maxWidth: 1400, maxHeight: 900)
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.85), radius: 36, x: 0, y: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                // Floating Back / Previous Navigation Button
                Button(action: handleBackAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text(navigationStack.isEmpty ? "Back" : "Previous")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(22)
            }
            .overlay {
                if showDownloadSourcesModal {
                    downloadSourcesModal
                        .zIndex(250)
                        .transition(.opacity)
                }
            }
            .overlay {
                // Filmography Modal Overlay when Director or Actor is clicked
                if let person = selectedPerson {
                    PersonWorksOverlay(
                        personName: person.name,
                        role: person.role,
                        photoURL: person.photoURL,
                        isDirectorSource: person.isDirectorSource,
                        categorizedWorks: personCategorizedWorks,
                        isLoading: isLoadingPersonWorks,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPerson = nil
                                personCategorizedWorks = TMDBService.PersonCategorizedWorks()
                            }
                        },
                        onSelectWork: { work in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPerson = nil
                                personCategorizedWorks = TMDBService.PersonCategorizedWorks()
                            }
                            switchMedia(to: work)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(200)
                }
            }
        }
        .onAppear {
            loadMetadata()
        }
    }

    private func loadMetadata() {
        if currentItem.type == .series {
            fetchSeriesSeasons()
        } else {
            fetchCollection()
        }
        fetchLogoAndDetails()
        fetchCredits()
        fetchExtras()
        fetchSimilar()
    }

    private func handleBackAction() {
        if let previous = navigationStack.popLast() {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.currentItem = previous
                self.totalSeasons = 1
                self.selectedSeason = 1
                self.seasonsInfo = []
                self.episodes = []
                self.collectionResult = nil
                self.credits = nil
                self.extras = []
                self.movieDetailTab = .cast
                self.tvDetailTab = .cast
                let prevLogo = previous.initialLogoURL
                self.logoURL = prevLogo
                self.isLoadingLogo = (prevLogo == nil)
                self.runtimeMinutes = nil
                self.similarItems = []
            }
            loadMetadata()
        } else {
            onDismiss()
        }
    }

    private func switchMedia(to newItem: MediaItem) {
        navigationStack.append(currentItem)
        withAnimation(.easeInOut(duration: 0.25)) {
            self.currentItem = newItem
            self.totalSeasons = 1
            self.selectedSeason = 1
            self.seasonsInfo = []
            self.episodes = []
            self.collectionResult = nil
            self.credits = nil
            self.extras = []
            self.movieDetailTab = .cast
            self.tvDetailTab = .cast
            let newLogo = newItem.initialLogoURL
            self.logoURL = newLogo
            self.isLoadingLogo = (newLogo == nil)
            self.runtimeMinutes = nil
            self.similarItems = []
        }
        loadMetadata()
    }

    private func fetchExtras() {
        isLoadingExtras = true
        Task {
            let res = await tmdbService.fetchMediaExtras(id: currentItem.id, imdbID: currentItem.imdbID, type: currentItem.type)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.extras = res
                    self.isLoadingExtras = false
                }
            }
        }
    }

    private func fetchLogoAndDetails() {
        Task {
            let details = await tmdbService.fetchMediaLogoAndDetails(id: currentItem.id, imdbID: currentItem.imdbID, type: currentItem.type, title: currentItem.title)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if let foundLogo = details.logoURL {
                        self.logoURL = foundLogo
                    }
                    self.isLoadingLogo = false
                    self.runtimeMinutes = details.runtimeMinutes
                }
            }
        }
    }

    private func fetchCredits() {
        isLoadingCredits = true
        Task {
            let res = await tmdbService.fetchMediaCredits(id: currentItem.id, imdbID: currentItem.imdbID, type: currentItem.type, title: currentItem.title)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.credits = res
                    self.isLoadingCredits = false
                }
            }
        }
    }

    private func openPersonWorks(id: Int, name: String, role: String, photoURL: URL?, isDirectorSource: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.selectedPerson = (id: id, name: name, role: role, photoURL: photoURL, isDirectorSource: isDirectorSource)
            self.personCategorizedWorks = TMDBService.PersonCategorizedWorks()
            self.isLoadingPersonWorks = true
        }

        Task {
            let catWorks = await tmdbService.fetchPersonCategorizedWorks(personID: id)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.personCategorizedWorks = catWorks
                    self.isLoadingPersonWorks = false
                }
            }
        }
    }

    private func fetchSeriesSeasons() {
        Task {
            let seasons = await tmdbService.fetchTVSeasons(tvID: currentItem.id, imdbID: currentItem.imdbID, title: currentItem.title)
            await MainActor.run {
                self.seasonsInfo = seasons
                self.totalSeasons = seasons.map { $0.seasonNumber }.max() ?? 1
                let initialSeason = seasons.first?.seasonNumber ?? 1
                self.selectedSeason = initialSeason
                self.loadEpisodes(seasonNumber: initialSeason)
            }
        }
    }

    private func loadEpisodes(seasonNumber: Int) {
        isLoadingEpisodes = true
        Task {
            let eps = await tmdbService.fetchSeasonEpisodes(tvID: currentItem.id, imdbID: currentItem.imdbID, seasonNumber: seasonNumber, title: currentItem.title)
            await MainActor.run {
                self.episodes = eps
                self.isLoadingEpisodes = false
            }
        }
    }

    private func fetchCollection() {
        isLoadingCollection = true
        Task {
            let col = await tmdbService.fetchMovieCollection(movieID: currentItem.id, imdbID: currentItem.imdbID)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.collectionResult = col
                    self.isLoadingCollection = false
                }
            }
        }
    }

    private func fetchSimilar() {
        isLoadingSimilar = true
        Task {
            let sim = await tmdbService.fetchSimilarMedia(id: currentItem.id, imdbID: currentItem.imdbID, type: currentItem.type)
            await MainActor.run {
                self.similarItems = sim
                self.isLoadingSimilar = false
            }
        }
    }

    private func autoDownloadBestSource() {
        guard !downloadSources.isEmpty else { return }
        let maxSize = Config.autoPlayMaxGbSize
        let prefQuality = Config.autoPlayPreferredQuality.lowercased()
        let cachedOnly = Config.autoPlayCachedOnly

        var candidates = downloadSources.filter { link in
            if cachedOnly && !link.isCached { return false }
            if maxSize > 0, let gb = link.sizeInGigabytes, gb > maxSize { return false }
            return true
        }
        if candidates.isEmpty { candidates = downloadSources }

        candidates.sort { a, b in
            let aQuality = a.quality.lowercased()
            let bQuality = b.quality.lowercased()
            let aMatch = (aQuality == prefQuality || (prefQuality == "4k" && a.quality == "4K") || (prefQuality == "1080p" && a.quality == "FHD"))
            let bMatch = (bQuality == prefQuality || (prefQuality == "4k" && b.quality == "4K") || (prefQuality == "1080p" && b.quality == "FHD"))
            if aMatch != bMatch { return aMatch && !bMatch }
            if a.isCached != b.isCached { return a.isCached && !b.isCached }
            return a.score > b.score
        }

        if let best = candidates.first {
            DownloadManager.shared.startDownloadWithSource(item: currentItem, link: best)
            withAnimation(.easeInOut(duration: 0.2)) {
                showDownloadSourcesModal = false
            }
        }
    }

    private func loadDownloadSources() {
        isLoadingDownloadSources = true
        Task {
            do {
                let links = try await aggregatorService.fetchBestLinks(
                    tmdbID: currentItem.id,
                    imdbID: currentItem.imdbID,
                    type: currentItem.type,
                    season: currentItem.type == .series ? selectedSeason : nil,
                    episode: currentItem.type == .series ? 1 : nil
                )
                await MainActor.run {
                    self.downloadSources = links
                    self.isLoadingDownloadSources = false
                }
            } catch {
                await MainActor.run {
                    self.downloadSources = []
                    self.isLoadingDownloadSources = false
                }
            }
        }
    }

    private var downloadSourcesModal: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDownloadSourcesModal = false
                    }
                }

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                            Text("Download Source Selection")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(downloadSources.isEmpty ? "Retrieving source streams..." : "\(downloadSources.count) sources available for download")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    if !downloadSources.isEmpty {
                        // Universal Auto Play Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDownloadSourcesModal = false
                            }
                            onPlay(currentItem, currentItem.type == .series ? selectedSeason : nil, currentItem.type == .series ? 1 : nil)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "bolt.fill")
                                Text("Auto Play")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        // Auto Download Button
                        Button(action: {
                            autoDownloadBestSource()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Auto Download")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Color(red: 1.0, green: 0.35, blue: 0.35))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDownloadSourcesModal = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.5))

                // Content
                if isLoadingDownloadSources {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView().tint(.white).scaleEffect(1.2)
                        Text("Finding high-speed download sources…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else if downloadSources.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "slash.circle")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No download sources found")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(downloadSources) { link in
                                HStack(alignment: .center, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(link.resolutionBadge)
                                                .font(.system(size: 11, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .foregroundColor(.white)
                                            
                                            if let sz = link.sizeString {
                                                Text(sz)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                                            }
                                            
                                            Text(link.source)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white.opacity(0.5))
                                        }

                                        Text(link.fileName)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.7))
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    // Big download button in row
                                    Button(action: {
                                        DownloadManager.shared.startDownloadWithSource(item: currentItem, link: link)
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showDownloadSourcesModal = false
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 13, weight: .bold))
                                            Text("Download")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 1.0, green: 0.35, blue: 0.35))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                            }
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: 380)
                }
            }
            .frame(minWidth: 540, maxWidth: 620)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.8), radius: 25, x: 0, y: 10)
        }
    }
}

// MARK: - Actor Circle Card Component
struct ActorCircleCard: View {
    let actor: CastMember
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if let url = actor.profileURL {
                    CachedImage(url: url, maxPixel: 150)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .saturation(isHovered ? 1.0 : 0.88)
                        .contrast(isHovered ? 1.0 : 1.06)
                        .scaleEffect(isHovered ? 1.06 : 1.0)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.35))
                        )
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(isHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isHovered ? 0.5 : 0.2), radius: 4, x: 0, y: 2)

            Text(actor.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovered ? .white : .white.opacity(0.85))
                .lineLimit(1)
                .frame(width: 68)
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { h in
            isHovered = h
        }
    }
}

// MARK: - Person Filmography Overlay
struct PersonWorksOverlay: View {
    let personName: String
    let role: String
    let photoURL: URL?
    let isDirectorSource: Bool
    let categorizedWorks: TMDBService.PersonCategorizedWorks
    let isLoading: Bool
    var onClose: () -> Void
    var onSelectWork: (MediaItem) -> Void

    enum WorkFilter: String, CaseIterable, Identifiable {
        case directed = "Directed"
        case acted = "Acted"
        case produced = "Produced"
        case all = "All Works"

        var id: String { rawValue }
    }

    @State private var selectedFilter: WorkFilter = .directed

    init(
        personName: String,
        role: String,
        photoURL: URL?,
        isDirectorSource: Bool,
        categorizedWorks: TMDBService.PersonCategorizedWorks,
        isLoading: Bool,
        onClose: @escaping () -> Void,
        onSelectWork: @escaping (MediaItem) -> Void
    ) {
        self.personName = personName
        self.role = role
        self.photoURL = photoURL
        self.isDirectorSource = isDirectorSource
        self.categorizedWorks = categorizedWorks
        self.isLoading = isLoading
        self.onClose = onClose
        self.onSelectWork = onSelectWork
        // Prioritize: If clicked from director link, show directed first.
        // If clicked from actor circle, show actor works first.
        self._selectedFilter = State(initialValue: isDirectorSource ? .directed : .acted)
    }

    // List of available filters based on content
    private var availableFilters: [WorkFilter] {
        var filters: [WorkFilter] = []
        if isDirectorSource {
            if !categorizedWorks.directed.isEmpty { filters.append(.directed) }
            if !categorizedWorks.acted.isEmpty { filters.append(.acted) }
            if !categorizedWorks.produced.isEmpty { filters.append(.produced) }
        } else {
            if !categorizedWorks.acted.isEmpty { filters.append(.acted) }
            if !categorizedWorks.directed.isEmpty { filters.append(.directed) }
            if !categorizedWorks.produced.isEmpty { filters.append(.produced) }
        }
        filters.append(.all)
        return filters
    }

    private var activeWorks: [MediaItem] {
        switch selectedFilter {
        case .directed:
            if !categorizedWorks.directed.isEmpty {
                return categorizedWorks.directed
            }
            return isDirectorSource ? categorizedWorks.all : (categorizedWorks.acted.isEmpty ? categorizedWorks.all : categorizedWorks.acted)
        case .acted:
            if !categorizedWorks.acted.isEmpty {
                return categorizedWorks.acted
            }
            return !isDirectorSource ? categorizedWorks.all : (categorizedWorks.directed.isEmpty ? categorizedWorks.all : categorizedWorks.directed)
        case .produced:
            return categorizedWorks.produced
        case .all:
            return categorizedWorks.all
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .background(.ultraThinMaterial.opacity(0.75))
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(alignment: .leading, spacing: 0) {
                // Header Bar
                HStack(spacing: 16) {
                    if let url = photoURL {
                        CachedImage(url: url, maxPixel: 300)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.4))
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(personName)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)

                        Text(role.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Spacer()

                    Button(action: onClose) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Back to Movie")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 14)

                // Category Filter Tabs
                HStack(spacing: 10) {
                    ForEach(availableFilters) { filter in
                        let isSelected = selectedFilter == filter
                        let count: Int = {
                            switch filter {
                            case .directed: return categorizedWorks.directed.count
                            case .acted: return categorizedWorks.acted.count
                            case .produced: return categorizedWorks.produced.count
                            case .all: return categorizedWorks.all.count
                            }
                        }()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                            }
                            .foregroundColor(isSelected ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.white : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Works Grid (10% smaller media: 194 x 291 pt)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(selectedFilter == .all ? "All Filmography" : "\(selectedFilter.rawValue) Titles")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
                            Spacer()
                            if !activeWorks.isEmpty {
                                Text("\(activeWorks.count) titles")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                        .padding(.top, 18)
                        .padding(.horizontal, 28)

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.regular)
                                Spacer()
                            }
                            .padding(.vertical, 60)
                        } else if activeWorks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "film")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.25))
                                Text("No \(selectedFilter.rawValue.lowercased()) titles recorded")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                        } else {
                            // 10% smaller grid columns: 194 width instead of 216
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 162, maximum: 194), spacing: 18)], spacing: 22) {
                                ForEach(activeWorks) { work in
                                    MoviePosterCard(item: work, posterWidth: 194, posterHeight: 291)
                                        .onTapGesture {
                                            onSelectWork(work)
                                        }
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.bottom, 28)
                        }
                    }
                }
            }
            .frame(maxWidth: 1080, maxHeight: 730)
            .background(Color(red: 0.09, green: 0.09, blue: 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.8), radius: 30, x: 0, y: 15)
        }
        .onAppear {
            // Automatically select the active primary filter on appear
            if isDirectorSource {
                if !categorizedWorks.directed.isEmpty {
                    selectedFilter = .directed
                } else if !categorizedWorks.all.isEmpty {
                    selectedFilter = .all
                }
            } else {
                if !categorizedWorks.acted.isEmpty {
                    selectedFilter = .acted
                } else if !categorizedWorks.all.isEmpty {
                    selectedFilter = .all
                }
            }
        }
    }
}

// MARK: - Movie Cast Row Card (Used in Movie Split Master-Detail Grid)
struct MovieCastRowCard: View {
    let actor: CastMember
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let url = actor.profileURL {
                    CachedImage(url: url, maxPixel: 200)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.35))
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(actor.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.92))
                    .lineLimit(1)

                if let char = actor.character, !char.isEmpty {
                    Text(char)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isHovered ? .white.opacity(0.8) : .white.opacity(0.2))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHovered ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { h in isHovered = h }
    }
}

// MARK: - Extra Row Card (Used in Movie Split Right Column)
struct ExtraRowCard: View {
    let extra: TMDBService.MediaExtra
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: {
            if let url = extra.youtubeURL {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
        }) {
            HStack(alignment: .top, spacing: 18) {
                // 16:9 Thumbnail (240x135)
                ZStack(alignment: .bottomLeading) {
                    CachedImage(url: extra.thumbnailURL, maxPixel: 600)
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 240, height: 135)
                        .clipped()
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isHovered ? Color.white.opacity(0.7) : Color.white.opacity(0.1), lineWidth: isHovered ? 1.5 : 1)
                        )

                    // Type badge
                    Text(extra.type.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(8)

                    // Play Icon on Hover
                    if isHovered {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: 1.5)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(width: 240, height: 135)

                // Title & Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(extra.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isHovered ? .white : .white.opacity(0.95))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text(extra.type)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))

                        if extra.official == true {
                            Text("Official")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }

                        if extra.site.lowercased() == "youtube" {
                            HStack(spacing: 3) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                                Text("YouTube")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                // External open icon
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.3))
                    .padding(8)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in isHovered = h }
    }
}

// MARK: - Extra Horizontal Card (Used in TV Show Extras Row)
struct ExtraHorizontalCard: View {
    let extra: TMDBService.MediaExtra
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: {
            if let url = extra.youtubeURL {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    CachedImage(url: extra.thumbnailURL, maxPixel: 400)
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 220, height: 124)
                        .clipped()
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isHovered ? Color.white.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1)
                        )

                    Text(extra.type.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                        .padding(6)

                    if isHovered {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: 1)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(width: 220, height: 124)

                VStack(alignment: .leading, spacing: 3) {
                    Text(extra.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isHovered ? .white : .white.opacity(0.9))
                        .lineLimit(2)
                        .frame(width: 220, alignment: .leading)

                    Text(extra.type)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in isHovered = h }
    }
}



// MARK: - Shining Download Button Style (Shines when clicked)
struct ShiningDownloadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(
                color: configuration.isPressed ? Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.9) : Color.clear,
                radius: configuration.isPressed ? 14 : 0,
                x: 0,
                y: 0
            )
            .brightness(configuration.isPressed ? 0.25 : 0.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
