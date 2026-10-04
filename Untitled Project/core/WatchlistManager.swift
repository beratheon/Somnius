import Foundation
import Combine

struct WatchHistoryItem: Identifiable, Codable, Hashable {
    var id: String { mediaItem.id }
    let mediaItem: MediaItem
    let seasonNumber: Int?
    let episodeNumber: Int?
    let timestamp: Date
    var progressSeconds: Double
    var totalDurationSeconds: Double

    var progressFraction: Double {
        guard totalDurationSeconds > 0 else { return 0 }
        return min(1.0, max(0, progressSeconds / totalDurationSeconds))
    }
}

class WatchlistManager: ObservableObject {
    static let shared = WatchlistManager()

    @Published private(set) var watchlist: [MediaItem] = []
    @Published private(set) var favorites: [MediaItem] = []
    @Published private(set) var history: [WatchHistoryItem] = []

    private let watchlistKey = "User_Watchlist_Items_V2"
    private let favoritesKey = "User_Favorites_Items_V2"
    private let historyKey = "User_WatchHistory_Items_V2"

    init() {
        loadData()
    }

    private func loadData() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: watchlistKey),
           let items = try? decoder.decode([MediaItem].self, from: data) {
            self.watchlist = items
        }

        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let items = try? decoder.decode([MediaItem].self, from: data) {
            self.favorites = items
        }

        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? decoder.decode([WatchHistoryItem].self, from: data) {
            self.history = items.map { item in
                if item.mediaItem.type == .movie {
                    return WatchHistoryItem(
                        mediaItem: item.mediaItem,
                        seasonNumber: nil,
                        episodeNumber: nil,
                        timestamp: item.timestamp,
                        progressSeconds: item.progressSeconds,
                        totalDurationSeconds: item.totalDurationSeconds
                    )
                }
                return item
            }
        }
    }

    private func saveData() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(watchlist) {
            UserDefaults.standard.set(data, forKey: watchlistKey)
        }
        if let data = try? encoder.encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
        if let data = try? encoder.encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func isWatchlisted(id: String) -> Bool {
        watchlist.contains(where: { $0.id == id })
    }

    func toggleWatchlist(_ item: MediaItem) {
        if isWatchlisted(id: item.id) {
            watchlist.removeAll(where: { $0.id == item.id })
        } else {
            watchlist.insert(item, at: 0)
        }
        saveData()
    }

    func isFavorite(id: String) -> Bool {
        favorites.contains(where: { $0.id == id })
    }

    func toggleFavorite(_ item: MediaItem) {
        if isFavorite(id: item.id) {
            favorites.removeAll(where: { $0.id == item.id })
        } else {
            favorites.insert(item, at: 0)
        }
        saveData()
    }

    func recordHistory(item: MediaItem, season: Int? = nil, episode: Int? = nil, progress: Double, duration: Double) {
        let s = (item.type == .series) ? season : nil
        let e = (item.type == .series) ? episode : nil
        history.removeAll(where: { $0.mediaItem.id == item.id })
        let record = WatchHistoryItem(
            mediaItem: item,
            seasonNumber: s,
            episodeNumber: e,
            timestamp: Date(),
            progressSeconds: progress,
            totalDurationSeconds: duration
        )
        history.insert(record, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        saveData()
    }

    func clearHistory() {
        history.removeAll()
        saveData()
    }
}
