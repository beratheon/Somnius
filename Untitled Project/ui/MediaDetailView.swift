import SwiftUI

struct MediaDetailView: View {
    let item: MediaItem
    var onPlay: (MediaItem, Int?, Int?) -> Void // (item, seasonNum, episodeNum)
    var onDismiss: () -> Void

    @State private var totalSeasons: Int = 1
    @State private var selectedSeason: Int = 1
    @State private var episodes: [TVEpisodeItem] = []
    @State private var isLoadingEpisodes: Bool = false

    @StateObject private var watchlistManager = WatchlistManager.shared
    private let tmdbService = TMDBService()

    var body: some View {
        ZStack(alignment: .center) {
            // Dark Backdrop with Tap-to-Dismiss
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Centered Large Modal Card
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Hero Backdrop Header
                        ZStack(alignment: .bottomLeading) {
                            if let backdrop = item.backdropUrl ?? item.posterUrl {
                                AsyncImage(url: backdrop) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(height: 400)
                                .clipped()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(height: 400)
                            }

                            // Dark Gradient Overlay
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.95)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            // Title & Quick Actions
                            VStack(alignment: .leading, spacing: 14) {
                                Text(item.title)
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                // Metadata Badges
                                HStack(spacing: 12) {
                                    if let date = item.releaseDate {
                                        Text(Calendar.current.component(.year, from: date).description)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white.opacity(0.8))
                                    }

                                    if item.type == .series {
                                        Text("\(totalSeasons) Season\(totalSeasons > 1 ? "s" : "")")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white.opacity(0.8))
                                    }

                                    Text("4K Ultra HD • DV")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.yellow.opacity(0.3))
                                        .foregroundColor(.yellow)
                                        .clipShape(Capsule())

                                    if let rating = item.rating, rating > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.caption)
                                                .foregroundColor(.yellow)
                                            Text(String(format: "%.1f", rating))
                                                .font(.subheadline.bold())
                                                .foregroundColor(.white)
                                        }
                                    }
                                }

                                // Action Buttons: Play 4K, Watchlist, Favorite
                                HStack(spacing: 14) {
                                    Button(action: {
                                        onPlay(item, item.type == .series ? selectedSeason : nil, item.type == .series ? 1 : nil)
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "play.fill")
                                                .font(.title3)
                                            Text("Play Stream")
                                                .font(.headline.weight(.semibold))
                                        }
                                        .padding(.horizontal, 28)
                                        .padding(.vertical, 14)
                                        .background(.white)
                                        .foregroundColor(.black)
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    // Bookmark Watchlist Button
                                    Button(action: {
                                        watchlistManager.toggleWatchlist(item)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: watchlistManager.isWatchlisted(id: item.id) ? "bookmark.fill" : "bookmark")
                                                .font(.headline)
                                            Text(watchlistManager.isWatchlisted(id: item.id) ? "Saved" : "Watchlist")
                                                .font(.subheadline.bold())
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 14)
                                        .background(Color.white.opacity(0.15))
                                        .foregroundColor(watchlistManager.isWatchlisted(id: item.id) ? .yellow : .white)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    // Favorite Button
                                    Button(action: {
                                        watchlistManager.toggleFavorite(item)
                                    }) {
                                        Image(systemName: watchlistManager.isFavorite(id: item.id) ? "heart.fill" : "heart")
                                            .font(.title3)
                                            .foregroundColor(watchlistManager.isFavorite(id: item.id) ? .red : .white)
                                            .padding(14)
                                            .background(Circle().fill(Color.white.opacity(0.15)))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(28)

                            // Close Button (Top-Right)
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: onDismiss) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.white.opacity(0.8))
                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(20)
                                }
                                Spacer()
                            }
                        }

                        // 2. Overview / Plot Description
                        VStack(alignment: .leading, spacing: 14) {
                            if let overview = item.description, !overview.isEmpty {
                                Text("Overview")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)

                                Text(overview)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(6)
                            }

                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.vertical, 10)
                        }
                        .padding(28)

                        // 3. TV Show Seasons & Episodes Picker (Only for Series)
                        if item.type == .series {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack {
                                    Text("Seasons & Episodes")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)

                                    Spacer()

                                    // Season Picker Dropdown
                                    Picker("Season", selection: $selectedSeason) {
                                        ForEach(1...totalSeasons, id: \.self) { sNum in
                                            Text("Season \(sNum)").tag(sNum)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(.yellow)
                                    .onChange(of: selectedSeason) { _, newSeason in
                                        loadEpisodes(seasonNumber: newSeason)
                                    }
                                }

                                if isLoadingEpisodes {
                                    HStack {
                                        Spacer()
                                        ProgressView("Loading episodes...")
                                            .tint(.white)
                                        Spacer()
                                    }
                                    .padding(.vertical, 30)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(episodes) { ep in
                                            Button(action: {
                                                onPlay(item, selectedSeason, ep.episodeNumber)
                                            }) {
                                                HStack(spacing: 16) {
                                                    Text("\(ep.episodeNumber)")
                                                        .font(.title2.monospacedDigit().bold())
                                                        .foregroundColor(.gray)
                                                        .frame(width: 30)

                                                    if let stillURL = ep.stillURL {
                                                        AsyncImage(url: stillURL) { image in
                                                            image
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                        } placeholder: {
                                                            Rectangle().fill(Color.gray.opacity(0.3))
                                                        }
                                                        .frame(width: 120, height: 70)
                                                        .cornerRadius(8)
                                                        .clipped()
                                                    }

                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(ep.name)
                                                            .font(.headline.weight(.semibold))
                                                            .foregroundColor(.white)

                                                        if let plot = ep.overview, !plot.isEmpty {
                                                            Text(plot)
                                                                .font(.caption)
                                                                .foregroundColor(.white.opacity(0.7))
                                                                .lineLimit(2)
                                                        }
                                                    }

                                                    Spacer()

                                                    Image(systemName: "play.circle.fill")
                                                        .font(.title2)
                                                        .foregroundColor(.white.opacity(0.8))
                                                }
                                                .padding(12)
                                                .background(Color.white.opacity(0.06))
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.bottom, 28)
                        }
                    }
                }
            }
            .frame(maxWidth: 850, maxHeight: 680)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.8), radius: 30, x: 0, y: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .onAppear {
            if item.type == .series {
                fetchSeriesSeasons()
            }
        }
    }

    private func fetchSeriesSeasons() {
        Task {
            let count = await tmdbService.fetchTVSeasonsCount(tvID: item.id)
            await MainActor.run {
                self.totalSeasons = count
                self.selectedSeason = 1
                self.loadEpisodes(seasonNumber: 1)
            }
        }
    }

    private func loadEpisodes(seasonNumber: Int) {
        isLoadingEpisodes = true
        Task {
            let eps = await tmdbService.fetchSeasonEpisodes(tvID: item.id, seasonNumber: seasonNumber)
            await MainActor.run {
                self.episodes = eps
                self.isLoadingEpisodes = false
            }
        }
    }
}
