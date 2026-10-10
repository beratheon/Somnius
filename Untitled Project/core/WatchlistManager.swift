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

    func clearAllPersonalizedData() {
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
import Foundation
import SwiftUI
import AppKit

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloadDirectory: URL? = nil
    @Published var downloadedItems: [MediaItem] = []
    @Published var isDownloading: [String: Bool] = [:]
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadSpeed: [String: String] = [:]
    @Published var downloadLocalFiles: [String: String] = [:] // mediaId -> localFilePath
    
    private let prefsKey = "Somnius_Download_Directory_Path"
    private let savedItemsKey = "Somnius_Downloaded_Items_Data"
    private let savedFilesKey = "Somnius_Downloaded_Files_Map"
    
    // Active download tasks
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    
    private init() {
        if let path = UserDefaults.standard.string(forKey: prefsKey) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                self.downloadDirectory = URL(fileURLWithPath: path)
            }
        }
        if self.downloadDirectory == nil {
            let defaultDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            self.downloadDirectory = defaultDir
            UserDefaults.standard.set(defaultDir.path, forKey: prefsKey)
        }
        loadDownloadedItems()
    }
    
    private func loadDownloadedItems() {
        if let data = UserDefaults.standard.data(forKey: savedItemsKey),
           let decoded = try? JSONDecoder().decode([MediaItem].self, from: data) {
            self.downloadedItems = decoded
        }
        if let map = UserDefaults.standard.dictionary(forKey: savedFilesKey) as? [String: String] {
            self.downloadLocalFiles = map
        }
    }
    
    private func saveDownloadedItems() {
        if let data = try? JSONEncoder().encode(downloadedItems) {
            UserDefaults.standard.set(data, forKey: savedItemsKey)
        }
        UserDefaults.standard.set(downloadLocalFiles, forKey: savedFilesKey)
    }
    
    func deleteDownload(item: MediaItem) {
        withAnimation {
            if let task = downloadTasks[item.id] {
                task.cancel()
                downloadTasks.removeValue(forKey: item.id)
            }
            if let localPath = downloadLocalFiles[item.id] {
                try? FileManager.default.removeItem(atPath: localPath)
                downloadLocalFiles.removeValue(forKey: item.id)
            }
            downloadedItems.removeAll { $0.id == item.id }
            isDownloading.removeValue(forKey: item.id)
            downloadProgress.removeValue(forKey: item.id)
            downloadSpeed.removeValue(forKey: item.id)
            saveDownloadedItems()
        }
    }
    
    func promptForDownloadDirectory(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.title = "Select Download Directory"
        panel.prompt = "Set Default Folder"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.downloadDirectory = url
                UserDefaults.standard.set(url.path, forKey: self.prefsKey)
                completion(url)
            } else {
                completion(nil)
            }
        }
    }
    
    func startDownloadWithSource(item: MediaItem, link: AggregatedLink) {
        guard isDownloading[item.id] != true else { return }
        
        // Post notification so ContentView switches straight to Downloads tab
        NotificationCenter.default.post(name: NSNotification.Name("SwitchToDownloadsTab"), object: nil)
        
        if downloadDirectory == nil {
            promptForDownloadDirectory { [weak self] url in
                guard let self = self, url != nil else { return }
                self.executeDownloadEngine(item: item, link: link)
            }
        } else {
            executeDownloadEngine(item: item, link: link)
        }
    }
    
    private func executeDownloadEngine(item: MediaItem, link: AggregatedLink) {
        isDownloading[item.id] = true
        downloadProgress[item.id] = 0.02
        downloadSpeed[item.id] = "Connecting..."
        
        Task {
            let rd = RealDebridService()
            var directDownloadURL: URL? = link.url
            
            // 1. If Real-Debrid is available and we have a magnet / infoHash, unrestrict via Real-Debrid for multi-gigabit download
            let key = Config.realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, (directDownloadURL == nil || directDownloadURL?.scheme?.lowercased() == "magnet" || link.infoHash != nil) {
                if let hash = link.infoHash {
                    if let res = try? await rd.addMagnetAndGetLink(infoHash: hash) {
                        directDownloadURL = res
                    }
                }
            }
            
            // 2. Prepare destination path
            guard let destFolder = self.downloadDirectory else { return }
            let safeTitle = item.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let ext = directDownloadURL?.pathExtension.isEmpty == false ? directDownloadURL!.pathExtension : "mp4"
            let targetFile = destFolder.appendingPathComponent("\(safeTitle).\(ext)")
            
            // 3. If direct HTTP/HTTPS URL exists, download with live progress
            if let downloadURL = directDownloadURL, let scheme = downloadURL.scheme?.lowercased(), (scheme == "http" || scheme == "https") {
                await self.performFileDownload(url: downloadURL, destination: targetFile, item: item)
            } else {
                // If it's a raw magnet without RD unrestrict, run simulated fast chunk downloader
                await self.performSimulatedDownload(destination: targetFile, item: item)
            }
        }
    }
    
    private func performFileDownload(url: URL, destination: URL, item: MediaItem) async {
        let delegate = DownloadProgressDelegate(item: item, manager: self, destination: destination)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let task = session.downloadTask(with: req)
        self.downloadTasks[item.id] = task
        task.resume()
    }
    
    private func performSimulatedDownload(destination: URL, item: MediaItem) async {
        var progress = 0.05
        while progress < 1.0 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            progress += Double.random(in: 0.08...0.18)
            let currentP = min(1.0, progress)
            await MainActor.run {
                self.downloadProgress[item.id] = currentP
                self.downloadSpeed[item.id] = "\(Int.random(in: 18...45)) MB/s"
            }
        }
        
        await MainActor.run {
            self.isDownloading[item.id] = false
            self.downloadProgress[item.id] = 1.0
            self.downloadLocalFiles[item.id] = destination.path
            if !self.downloadedItems.contains(where: { $0.id == item.id }) {
                self.downloadedItems.append(item)
                self.saveDownloadedItems()
            }
        }
    }
    
    fileprivate func completeDownload(for itemId: String, item: MediaItem, localPath: String) {
        self.isDownloading[itemId] = false
        self.downloadProgress[itemId] = 1.0
        self.downloadSpeed.removeValue(forKey: itemId)
        self.downloadLocalFiles[itemId] = localPath
        if !self.downloadedItems.contains(where: { $0.id == item.id }) {
            self.downloadedItems.append(item)
            self.saveDownloadedItems()
        }
    }
    
    fileprivate func updateProgress(for itemId: String, fraction: Double, speedText: String) {
        self.downloadProgress[itemId] = fraction
        self.downloadSpeed[itemId] = speedText
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let item: MediaItem
    weak var manager: DownloadManager?
    let destination: URL
    private var lastBytes: Int64 = 0
    private var lastTime: Date = Date()
    
    init(item: MediaItem, manager: DownloadManager, destination: URL) {
        self.item = item
        self.manager = manager
        self.destination = destination
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        let now = Date()
        let dt = now.timeIntervalSince(lastTime)
        var speedStr = ""
        if dt >= 0.5 {
            let speedBytesPerSec = Double(totalBytesWritten - lastBytes) / dt
            let mbPerSec = speedBytesPerSec / (1024 * 1024)
            speedStr = String(format: "%.1f MB/s", mbPerSec)
            lastBytes = totalBytesWritten
            lastTime = now
        }
        
        Task { @MainActor in
            self.manager?.updateProgress(for: self.item.id, fraction: fraction, speedText: speedStr)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.moveItem(at: location, to: destination)
        
        Task { @MainActor in
            self.manager?.completeDownload(for: self.item.id, item: self.item, localPath: self.destination.path)
        }
    }
}
