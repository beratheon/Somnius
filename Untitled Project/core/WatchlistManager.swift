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
    @Published private(set) var watchedEpisodes: Set<String> = []
    private var episodeProgressMap: [String: Double] = [:]

    private var profileScopeId: String {
        if let id = UserDefaults.standard.string(forKey: "Somnius_Active_Account_ID_v2"), !id.isEmpty {
            return id
        }
        return "default"
    }

    private var watchlistKey: String { "User_Watchlist_Items_\(profileScopeId)" }
    private var favoritesKey: String { "User_Favorites_Items_\(profileScopeId)" }
    private var historyKey: String { "User_WatchHistory_Items_\(profileScopeId)" }
    private var episodeProgressKey: String { "User_EpisodeProgress_Map_\(profileScopeId)" }
    private var watchedEpisodesKey: String { "User_Watched_Episodes_\(profileScopeId)" }

    init() {
        loadData()
    }

    func reloadForCurrentProfile() {
        self.watchlist = []
        self.favorites = []
        self.history = []
        self.watchedEpisodes = []
        self.episodeProgressMap = [:]
        loadData()
    }

    private func loadData() {
        if let map = UserDefaults.standard.dictionary(forKey: episodeProgressKey) as? [String: Double] {
            self.episodeProgressMap = map
        } else {
            self.episodeProgressMap = [:]
        }

        if let saved = UserDefaults.standard.stringArray(forKey: watchedEpisodesKey) {
            self.watchedEpisodes = Set(saved)
        } else {
            self.watchedEpisodes = []
        }

        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: watchlistKey),
           let items = try? decoder.decode([MediaItem].self, from: data) {
            self.watchlist = items
        } else {
            self.watchlist = []
        }

        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let items = try? decoder.decode([MediaItem].self, from: data) {
            self.favorites = items
        } else {
            self.favorites = []
        }

        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? decoder.decode([WatchHistoryItem].self, from: data) {
            self.history = sanitizeHistory(items)
        } else {
            self.history = []
        }
    }

    public func clearAllPersonalizedData() {
        self.watchlist = []
        self.favorites = []
        self.history = []
        self.watchedEpisodes = []
        self.episodeProgressMap = [:]
        UserDefaults.standard.removeObject(forKey: watchlistKey)
        UserDefaults.standard.removeObject(forKey: favoritesKey)
        UserDefaults.standard.removeObject(forKey: historyKey)
        UserDefaults.standard.removeObject(forKey: episodeProgressKey)
        UserDefaults.standard.removeObject(forKey: watchedEpisodesKey)
        UserDefaults.standard.removeObject(forKey: "User_Watchlist_Items_V2")
        UserDefaults.standard.removeObject(forKey: "User_Favorites_Items_V2")
        UserDefaults.standard.removeObject(forKey: "User_WatchHistory_Items_V2")
    }

    private func sanitizeHistory(_ items: [WatchHistoryItem]) -> [WatchHistoryItem] {
        return items.map { item in
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
        UserDefaults.standard.set(episodeProgressMap, forKey: episodeProgressKey)
        UserDefaults.standard.set(Array(watchedEpisodes), forKey: watchedEpisodesKey)
    }

    // MARK: - Episode Watched Tracking
    func episodeKey(showID: String, season: Int, episode: Int) -> String {
        return "\(showID)_s\(season)_e\(episode)"
    }

    func isEpisodeWatched(showID: String, season: Int, episode: Int) -> Bool {
        watchedEpisodes.contains(episodeKey(showID: showID, season: season, episode: episode))
    }

    func toggleEpisodeWatched(showID: String, season: Int, episode: Int) {
        let key = episodeKey(showID: showID, season: season, episode: episode)
        if watchedEpisodes.contains(key) {
            watchedEpisodes.remove(key)
        } else {
            watchedEpisodes.insert(key)
        }
        saveData()
    }

    func markEpisodeWatched(showID: String, season: Int, episode: Int, watched: Bool) {
        let key = episodeKey(showID: showID, season: season, episode: episode)
        if watched {
            watchedEpisodes.insert(key)
        } else {
            watchedEpisodes.remove(key)
        }
        saveData()
    }

    func markSeasonWatched(showID: String, season: Int, episodeNumbers: [Int], watched: Bool = true) {
        for ep in episodeNumbers {
            let key = episodeKey(showID: showID, season: season, episode: ep)
            if watched {
                watchedEpisodes.insert(key)
            } else {
                watchedEpisodes.remove(key)
            }
        }
        saveData()
    }

    func isSeasonFullyWatched(showID: String, season: Int, episodeNumbers: [Int]) -> Bool {
        guard !episodeNumbers.isEmpty else { return false }
        return episodeNumbers.allSatisfy { isEpisodeWatched(showID: showID, season: season, episode: $0) }
    }

    func watchedCount(showID: String) -> Int {
        let prefix = "\(showID)_s"
        return watchedEpisodes.filter { $0.hasPrefix(prefix) }.count
    }

    // MARK: - Movie Watched Tracking
    private func movieWatchedKey(_ id: String) -> String { "\(id)_movie_watched" }

    func isMovieWatched(id: String) -> Bool {
        watchedEpisodes.contains(movieWatchedKey(id))
    }

    func toggleMovieWatched(id: String) {
        let key = movieWatchedKey(id)
        if watchedEpisodes.contains(key) {
            watchedEpisodes.remove(key)
        } else {
            watchedEpisodes.insert(key)
        }
        saveData()
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

        // Granular key tracking
        let granularKey: String
        if let sNum = s, let eNum = e {
            granularKey = "\(item.id)_s\(sNum)_e\(eNum)"
        } else {
            granularKey = "\(item.id)_movie"
        }

        if duration > 0 && (progress / duration) >= 0.90 {
            episodeProgressMap.removeValue(forKey: granularKey)
            if let sNum = s, let eNum = e {
                watchedEpisodes.insert(episodeKey(showID: item.id, season: sNum, episode: eNum))
            } else if item.type == .movie {
                watchedEpisodes.insert("\(item.id)_movie_watched")
            }
        } else if progress > 5 {
            episodeProgressMap[granularKey] = progress
        }

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

    func getResumeTime(id: String, season: Int? = nil, episode: Int? = nil) -> Double? {
        let granularKey: String
        if let s = season, let e = episode {
            granularKey = "\(id)_s\(s)_e\(e)"
        } else {
            granularKey = "\(id)_movie"
        }

        if let savedSec = episodeProgressMap[granularKey], savedSec > 10 {
            return savedSec
        }

        if let match = history.first(where: { item in
            guard item.mediaItem.id == id else { return false }
            if item.mediaItem.type == .series {
                return item.seasonNumber == season && item.episodeNumber == episode
            }
            return true
        }) {
            if match.progressSeconds > 10 && match.progressFraction < 0.92 {
                return match.progressSeconds
            }
        }
        return nil
    }

    func removeHistory(id: String) {
        history.removeAll(where: { $0.mediaItem.id == id })
        saveData()
    }

    func clearHistory() {
        history.removeAll()
        saveData()
    }

    func removeFromWatchlist(id: String) {
        watchlist.removeAll(where: { $0.id == id })
        saveData()
    }

    func clearWatchlist() {
        watchlist.removeAll()
        saveData()
    }

    func clearAllUserData() {
        watchlist.removeAll()
        favorites.removeAll()
        history.removeAll()
        watchedEpisodes.removeAll()
        episodeProgressMap.removeAll()
        saveData()
    }
}
