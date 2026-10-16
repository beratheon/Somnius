import SwiftUI

struct WatchlistView: View {
    @ObservedObject private var watchlistManager = WatchlistManager.shared
    var onMediaSelected: (MediaItem) -> Void
    var onPlayContinueWatching: ((WatchHistoryItem) -> Void)? = nil

    @State private var selectedTab: WatchlistSubTab = .all
    @State private var showClearConfirm: Bool = false

    enum WatchlistSubTab: String, CaseIterable {
        case all = "All Saved"
        case movies = "Movies"
        case series = "TV Shows"
        case history = "Continue Watching"
    }

    private var filteredWatchlist: [MediaItem] {
        switch selectedTab {
        case .all:
            return watchlistManager.watchlist
        case .movies:
            return watchlistManager.watchlist.filter { $0.type == .movie }
        case .series:
            return watchlistManager.watchlist.filter { $0.type == .series }
        case .history:
            return []
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Top Header & Sub-Tabs
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("My List & Watch History")
                                .font(.custom("Baskerville", size: 30))
                                .foregroundColor(.white)
                            Text("\(watchlistManager.watchlist.count) saved titles • \(watchlistManager.history.count) recently watched")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.55))
                        }

                        Spacer()

                        // Action Buttons: Clear
                        HStack(spacing: 12) {
                            if !watchlistManager.history.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        watchlistManager.clearHistory()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.circlepath")
                                        Text("Clear History")
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            if !watchlistManager.watchlist.isEmpty {
                                Button(action: {
                                    showClearConfirm = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                        Text("Clear All List")
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.red.opacity(0.85))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 0.8))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Filter Tabs
                    HStack(spacing: 12) {
                        ForEach(WatchlistSubTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }) {
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? Color.white.opacity(0.16) : Color.white.opacity(0.04))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 28)

                // Continue Watching Section (if on All or History)
                if (selectedTab == .all || selectedTab == .history) && !watchlistManager.history.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Continue Watching")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 36)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(watchlistManager.history) { historyItem in
                                    ContinueWatchingCard(item: historyItem) {
                                        if let playHandler = onPlayContinueWatching {
                                            playHandler(historyItem)
                                        } else {
                                            onMediaSelected(historyItem.mediaItem)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 36)
                        }
                    }
                }

                // Saved Titles Grid
                if selectedTab != .history {
                    VStack(alignment: .leading, spacing: 16) {
                        if selectedTab == .all && !watchlistManager.history.isEmpty {
                            Text("Saved to Watchlist")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 36)
                        }

                        if filteredWatchlist.isEmpty {
                            emptyStateView
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 180, maximum: 215), spacing: 22)],
                                spacing: 26
                            ) {
                                ForEach(filteredWatchlist) { item in
                                    MoviePosterCard(item: item, posterWidth: 185, posterHeight: 278) {
                                        onMediaSelected(item)
                                    }
                                }
                            }
                            .padding(.horizontal, 36)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
        }
        .confirmationDialog("Clear Watchlist", isPresented: $showClearConfirm, actions: {
            Button("Clear All Saved Titles", role: .destructive) {
                withAnimation {
                    watchlistManager.clearWatchlist()
                }
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Are you sure you want to remove all saved items from your watchlist?")
        })
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 46))
                .foregroundColor(.white.opacity(0.3))

            Text("Your List is Empty")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            Text("Browse Movies and Series on Home, then tap the Bookmark or Love button to add titles here.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
