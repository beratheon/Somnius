import SwiftUI

struct DiscoverTabView: View {
    @ObservedObject var viewModel: ContentViewModel
    @ObservedObject private var watchlistManager = WatchlistManager.shared
    var onMediaSelected: (MediaItem) -> Void
    var onPlayMedia: ((MediaItem) -> Void)? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // 1. Curated 10-Movie Hero Banner
                let heroItems = viewModel.discoverHeroItems
                if !heroItems.isEmpty {
                    HeroView(
                        items: heroItems,
                        onPlayTap: { item in
                            onPlayMedia?(item)
                        },
                        onDetailsTap: { item in
                            onMediaSelected(item)
                        }
                    )
                }

                // 2. Discover Sections (Curated, Based on History, Critics' Choice, Hidden Gems)
                VStack(alignment: .leading, spacing: 36) {
                    // Section 1: "Curated For Your Taste"
                    let tasteItems = viewModel.curatedCollections.first?.items ?? viewModel.topRatedMovies
                    if !tasteItems.isEmpty {
                        discoverSection(
                            title: "Curated For Your Taste",
                            subtitle: "Handpicked selections matching your viewing habits and history",
                            items: tasteItems
                        )
                    }

                    // Section 2: "Because You Watched..."
                    if let lastWatched = watchlistManager.history.first {
                        let pool = viewModel.trendingMovies.filter { $0.id != lastWatched.mediaItem.id }
                        if !pool.isEmpty {
                            discoverSection(
                                title: "Because You Watched \(lastWatched.mediaItem.title)",
                                subtitle: "Titles sharing similar genres, tone, and director style",
                                items: pool
                            )
                        }
                    }

                    // Section 3: "Critics' Choice & Masterpieces"
                    if !viewModel.topRatedMovies.isEmpty {
                        discoverSection(
                            title: "Critics' Choice & Masterpieces",
                            subtitle: "Acclaimed films and series celebrated worldwide",
                            items: viewModel.topRatedMovies
                        )
                    }

                    // Section 4: "Hidden Gems & Cult Hits"
                    if !viewModel.actionMovies.isEmpty {
                        discoverSection(
                            title: "Hidden Gems & Cult Hits",
                            subtitle: "Captivating stories outside the mainstream radar",
                            items: viewModel.actionMovies
                        )
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 60)
            }
        }
    }

    private func discoverSection(title: String, subtitle: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.55))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(items) { item in
                        MoviePosterCard(item: item, posterWidth: 200, posterHeight: 300) {
                            onMediaSelected(item)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}
