import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - App Configuration & Persistent Settings
struct Config {
    private static let apiKeyKey = "RealDebrid_API_Key"
    private static let subtitleLangKey = "Preferred_Subtitle_Language"
    private static let showOnlyCachedKey = "Show_Only_Cached_Results"
    private static let defaultPlayerKey = "Default_Player_Selection"
    private static let autoPlayNextKey = "Auto_Play_Next_Episode"
    private static let bufferSecondsKey = "Buffer_Ahead_Duration_Seconds"

    private static let preferredQualityKey = "Preferred_Stream_Quality"
    private static let playbackEngineKey = "Playback_Engine_Mode"
    private static let subtitleColorKey = "Subtitle_Color_Preference"
    private static let subtitleSizeKey = "Subtitle_Size_Preference"

    static var realDebridApiKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: apiKeyKey) }
    }

    static var realDebridAPIKey: String {
        get { realDebridApiKey }
        set { realDebridApiKey = newValue }
    }

    static var preferredSubtitleLanguage: String {
        get { UserDefaults.standard.string(forKey: subtitleLangKey) ?? "en" }
        set { UserDefaults.standard.set(newValue, forKey: subtitleLangKey) }
    }

    static var preferredStreamQuality: String {
        get { UserDefaults.standard.string(forKey: preferredQualityKey) ?? "4k" }
        set { UserDefaults.standard.set(newValue, forKey: preferredQualityKey) }
    }

    static var playbackEngineMode: String {
        get { UserDefaults.standard.string(forKey: playbackEngineKey) ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: playbackEngineKey) }
    }

    static var subtitleColorPreference: String {
        get { UserDefaults.standard.string(forKey: subtitleColorKey) ?? "yellow" }
        set { UserDefaults.standard.set(newValue, forKey: subtitleColorKey) }
    }

    static var subtitleFontSizePreference: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: subtitleSizeKey)
            return v > 10 ? CGFloat(v) : 22.0
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: subtitleSizeKey) }
    }

    static var showOnlyCachedResults: Bool {
        get { UserDefaults.standard.bool(forKey: showOnlyCachedKey) }
        set { UserDefaults.standard.set(newValue, forKey: showOnlyCachedKey) }
    }

    static var defaultPlayerSelection: String {
        get { UserDefaults.standard.string(forKey: defaultPlayerKey) ?? "native" }
        set { UserDefaults.standard.set(newValue, forKey: defaultPlayerKey) }
    }

    static var useIINAByDefault: Bool {
        get { defaultPlayerSelection == "iina" }
        set { defaultPlayerSelection = newValue ? "iina" : "native" }
    }

    static var autoPlayNextEpisode: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoPlayNextKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: autoPlayNextKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoPlayNextKey) }
    }

    static var bufferAheadSeconds: Double {
        get {
            let v = UserDefaults.standard.double(forKey: bufferSecondsKey)
            return v > 0 ? v : 60.0
        }
        set { UserDefaults.standard.set(newValue, forKey: bufferSecondsKey) }
    }

    static let cometUrl = "http://localhost:8000"
    static let zileanUrl = "http://localhost:8181"
    static let torrentioUrl = "https://torrentio.strem.fun"
    static let prowlarrUrl = "http://localhost:9696"
    static var prowlarrApiKey: String = ""
    static let stremthruUrl = "http://localhost:8080"
    static let tmdbApiKey = "a07e22bc18f5cb106bfe4cc1f83ad8ed"
    static let tmdbApiKeyFallback = "e9e9d8da18ae29fc430845952232787c"
}

// MARK: - Multi-Player Launcher Support (IINA, VLC, Infuse, MPV)
enum ExternalPlayer: String, CaseIterable, Identifiable {
    case iina = "IINA"
    case vlc = "VLC"
    case infuse = "Infuse"
    case mpv = "mpv"

    var id: String { rawValue }

    var appPath: String {
        switch self {
        case .iina: return "/Applications/IINA.app"
        case .vlc: return "/Applications/VLC.app"
        case .infuse: return "/Applications/Infuse.app"
        case .mpv: return "/Applications/mpv.app"
        }
    }

    var isInstalled: Bool {
        #if os(macOS)
        return FileManager.default.fileExists(atPath: appPath)
        #else
        return false
        #endif
    }

    @discardableResult
    func open(url: URL, startTime: Double? = nil) -> Bool {
        #if os(macOS)
        let appURL = URL(fileURLWithPath: appPath)
        if FileManager.default.fileExists(atPath: appPath) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            var args: [String] = []
            if let s = startTime, s > 2 {
                let sec = Int(s)
                switch self {
                case .iina:
                    args = ["--mpv-start=\(sec)"]
                case .vlc:
                    args = ["--start-time=\(sec)"]
                case .mpv:
                    args = ["--start=\(sec)"]
                case .infuse:
                    break
                }
            }
            configuration.arguments = args
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { app, error in
                if let error = error {
                    print("Failed to open \(rawValue): \(error.localizedDescription)")
                } else {
                    print("Successfully launched \(rawValue) player at \(Int(startTime ?? 0))s.")
                }
            }
            return true
        }
        return false
        #else
        return false
        #endif
    }
}

// MARK: - Legacy IINA Helper Compatibility
class IINAPlayerService {
    static var isIINAInstalled: Bool {
        return ExternalPlayer.iina.isInstalled
    }

    @discardableResult
    static func openInIINA(url: URL) -> Bool {
        return ExternalPlayer.iina.open(url: url)
    }
}

// MARK: - RealDebrid Service API Client
class RealDebridService {
    private let baseURL = "https://api.real-debrid.com/rest/1.0"

    private var apiKey: String {
        return Config.realDebridApiKey
    }

    func fetchUser() async throws -> RealDebridUser {
        guard let url = URL(string: "\(baseURL)/user") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "No network response from RealDebrid."])
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NSError(domain: "RealDebrid", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid or unauthorized RealDebrid API Key."])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "RealDebrid", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user profile."])
        }

        return try JSONDecoder().decode(RealDebridUser.self, from: data)
    }

    func fetchTorrents() async throws -> [RealDebridTorrentItem] {
        guard let url = URL(string: "\(baseURL)/torrents") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "No network response from RealDebrid."])
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NSError(domain: "RealDebrid", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unauthorized RealDebrid API Key."])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "RealDebrid", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch RealDebrid torrents."])
        }

        return try JSONDecoder().decode([RealDebridTorrentItem].self, from: data)
    }

    func checkInstantAvailability(hashes: [String]) async throws -> Set<String> {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !hashes.isEmpty else { return [] }

        let cleanHashes = Array(Set(hashes.compactMap { h -> String? in
            let trimmed = h.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed.count == 40 ? trimmed : nil
        }))
        guard !cleanHashes.isEmpty else { return [] }

        var cachedHashes = Set<String>()
        let chunkSize = 40
        let chunks = stride(from: 0, to: cleanHashes.count, by: chunkSize).map {
            Array(cleanHashes[$0..<min($0 + chunkSize, cleanHashes.count)])
        }

        await withTaskGroup(of: Set<String>.self) { group in
            for chunk in chunks {
                let hashPath = chunk.joined(separator: "/")
                guard let url = URL(string: "\(baseURL)/torrents/instantAvailability/\(hashPath)") else { continue }

                group.addTask {
                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    request.timeoutInterval = 4.0

                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }

                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            var set = Set<String>()
                            for (hashKey, val) in json {
                                if let dict = val as? [String: Any], !dict.isEmpty {
                                    set.insert(hashKey.lowercased())
                                }
                            }
                            return set
                        }
                    } catch {}
                    return []
                }
            }

            for await result in group {
                cachedHashes.formUnion(result)
            }
        }

        return cachedHashes
    }

    func unrestrict(link: URL) async throws -> URL {
        return try await unrestrict(urlString: link.absoluteString)
    }

    func unrestrict(urlString: String) async throws -> URL {
        guard let url = URL(string: "\(baseURL)/unrestrict/link") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
        let encodedLink = urlString.addingPercentEncoding(withAllowedCharacters: allowed) ?? urlString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "link=\(encodedLink)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "No HTTP response from RealDebrid."])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let status = httpResponse.statusCode
            if status == 401 || status == 403 {
                throw NSError(domain: "RealDebrid", code: status, userInfo: [NSLocalizedDescriptionKey: "RealDebrid authorization failed. Check your API key."])
            }
            throw NSError(domain: "RealDebrid", code: status, userInfo: [NSLocalizedDescriptionKey: "RealDebrid unrestrict failed with HTTP \(status)"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let downloadString = json["download"] as? String,
           let downloadURL = URL(string: downloadString) {
            return downloadURL
        }

        throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse download URL from RealDebrid response."])
    }

    func addMagnetAndGetLink(infoHash: String) async throws -> URL {
        let magnetURI = "magnet:?xt=urn:btih:\(infoHash)"
        guard let addURL = URL(string: "\(baseURL)/torrents/addMagnet") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        let allowedFormChars = CharacterSet.alphanumerics
        let encodedMagnet = magnetURI.addingPercentEncoding(withAllowedCharacters: allowedFormChars) ?? magnetURI

        var addRequest = URLRequest(url: addURL)
        addRequest.httpMethod = "POST"
        addRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        addRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        addRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        addRequest.httpBody = "magnet=\(encodedMagnet)".data(using: .utf8)

        let (addData, addResponse) = try await URLSession.shared.data(for: addRequest)
        guard let addHTTP = addResponse as? HTTPURLResponse, (200...299).contains(addHTTP.statusCode) else {
            let addStatus = (addResponse as? HTTPURLResponse)?.statusCode ?? 0
            if addStatus == 401 || addStatus == 403 {
                throw NSError(domain: "RealDebrid", code: addStatus, userInfo: [NSLocalizedDescriptionKey: "RealDebrid API Key is invalid or expired. Check Settings."])
            }
            if addStatus == 451 {
                throw NSError(domain: "RealDebrid", code: 451, userInfo: [NSLocalizedDescriptionKey: "Torrent is DMCA blocked on RealDebrid (HTTP 451)."])
            }
            throw NSError(domain: "RealDebrid", code: addStatus, userInfo: [NSLocalizedDescriptionKey: "Failed to add magnet to RealDebrid (HTTP \(addStatus))."])
        }

        struct AddMagnetResponse: Decodable {
            let id: String
        }

        let addResult = try JSONDecoder().decode(AddMagnetResponse.self, from: addData)
        let torrentID = addResult.id

        // Select all files
        guard let selectURL = URL(string: "\(baseURL)/torrents/selectFiles/\(torrentID)") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid select files URL"])
        }

        var selectRequest = URLRequest(url: selectURL)
        selectRequest.httpMethod = "POST"
        selectRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        selectRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        selectRequest.httpBody = "files=all".data(using: .utf8)

        _ = try await URLSession.shared.data(for: selectRequest)

        // Poll torrent status for links with video file matching
        struct TorrentFileItem: Decodable {
            let id: Int
            let path: String
            let bytes: Int64
            let selected: Int
        }
        struct TorrentInfoResponse: Decodable {
            let status: String
            let files: [TorrentFileItem]?
            let links: [String]?
        }

        guard let infoURL = URL(string: "\(baseURL)/torrents/info/\(torrentID)") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid info URL"])
        }

        let videoExtensions = [".mkv", ".mp4", ".m4v", ".avi", ".mov", ".ts", ".m2ts", ".webm", ".flv"]

        for _ in 0..<12 {
            try await Task.sleep(nanoseconds: 1_000_000_000)

            var infoRequest = URLRequest(url: infoURL)
            infoRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            if let (infoData, infoResp) = try? await URLSession.shared.data(for: infoRequest),
               let infoHTTP = infoResp as? HTTPURLResponse, (200...299).contains(infoHTTP.statusCode),
               let info = try? JSONDecoder().decode(TorrentInfoResponse.self, from: infoData),
               let links = info.links, !links.isEmpty {
                
                var targetLink = links.first!
                if let files = info.files {
                    let selectedFiles = files.filter { $0.selected == 1 }
                    let videoFiles = selectedFiles.filter { file in
                        let lowerPath = file.path.lowercased()
                        return videoExtensions.contains(where: { lowerPath.hasSuffix($0) })
                    }
                    
                    let bestFile = videoFiles.max(by: { $0.bytes < $1.bytes }) ?? selectedFiles.max(by: { $0.bytes < $1.bytes })
                    
                    if let best = bestFile, let index = selectedFiles.firstIndex(where: { $0.id == best.id }), index < links.count {
                        targetLink = links[index]
                    }
                }
                
                return try await unrestrict(urlString: targetLink)
            }
        }

        throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for RealDebrid torrent processing"])
    }
}

// MARK: - Safe Failable Decodable Wrappers for TMDB
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(T.self)
    }
}

// MARK: - TMDB API Service
class TMDBService {
    private let primaryKey = Config.tmdbApiKey
    private let fallbackKey = Config.tmdbApiKeyFallback
    private let baseURL = "https://api.themoviedb.org/3"

    private func executeRequest(endpoint: String, queryItems: [URLQueryItem] = []) async throws -> (Data, HTTPURLResponse) {
        let keys = [primaryKey, fallbackKey]
        var lastError: Error?

        for key in keys {
            var items = queryItems
            items.append(URLQueryItem(name: "api_key", value: key))

            var components = URLComponents(string: "\(baseURL)\(endpoint)")
            components?.queryItems = items

            guard let url = components?.url else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                    return (data, httpResp)
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? NSError(domain: "TMDBService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to TMDB services."])
    }

    func fetchTitle(tmdbID: String, type: MediaItem.MediaType) async throws -> String {
        let endpoint = (type == .series) ? "/tv/\(tmdbID)" : "/movie/\(tmdbID)"
        let (data, _) = try await executeRequest(endpoint: endpoint)

        struct TitleDetails: Decodable {
            let title: String?
            let name: String?
        }
        let details = try JSONDecoder().decode(TitleDetails.self, from: data)
        return details.title ?? details.name ?? "Movie"
    }

    func fetchIMDbID(tmdbID: String, type: MediaItem.MediaType) async throws -> String {
        let endpoint = (type == .series) ? "/tv/\(tmdbID)/external_ids" : "/movie/\(tmdbID)/external_ids"
        let (data, _) = try await executeRequest(endpoint: endpoint)

        struct ExternalIDs: Decodable {
            let imdb_id: String?
        }
        let ext = try JSONDecoder().decode(ExternalIDs.self, from: data)
        guard let imdb = ext.imdb_id, !imdb.isEmpty else {
            throw NSError(domain: "TMDBService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No IMDb ID found for \(tmdbID)"])
        }
        return imdb
    }

    func fetchTrending() async -> [MediaItem] {
        return await fetchTrendingMovies()
    }

    func fetchTrendingMovies() async -> [MediaItem] {
        do {
            let (data, _) = try await executeRequest(endpoint: "/trending/movie/week")
            return parseMediaItems(data: data, type: .movie)
        } catch {
            return []
        }
    }

    func fetchPopularMovies() async -> [MediaItem] {
        do {
            let (data, _) = try await executeRequest(endpoint: "/movie/popular")
            return parseMediaItems(data: data, type: .movie)
        } catch {
            return []
        }
    }

    func fetchTopRatedMovies() async -> [MediaItem] {
        return await fetchTopRatedCatalog(page: 1)
    }

    func fetchActionMovies() async -> [MediaItem] {
        return await fetchActionCatalog(page: 1)
    }

    func fetchTopRatedCatalog(page: Int = 1) async -> [MediaItem] {
        do {
            let items = [URLQueryItem(name: "page", value: "\(page)")]
            let (data, _) = try await executeRequest(endpoint: "/movie/top_rated", queryItems: items)
            return parseMediaItems(data: data, type: .movie)
        } catch {
            return []
        }
    }

    func fetchActionCatalog(page: Int = 1) async -> [MediaItem] {
        do {
            let items = [
                URLQueryItem(name: "with_genres", value: "28"),
                URLQueryItem(name: "page", value: "\(page)")
            ]
            let (data, _) = try await executeRequest(endpoint: "/discover/movie", queryItems: items)
            return parseMediaItems(data: data, type: .movie)
        } catch {
            return []
        }
    }

    func fetchSciFiCatalog(page: Int = 1) async -> [MediaItem] {
        do {
            let items = [
                URLQueryItem(name: "with_genres", value: "878"),
                URLQueryItem(name: "page", value: "\(page)")
            ]
            let (data, _) = try await executeRequest(endpoint: "/discover/movie", queryItems: items)
            return parseMediaItems(data: data, type: .movie)
        } catch {
            return []
        }
    }

    func fetchAnimationCatalog(page: Int = 1) async -> [MediaItem] {
        do {
            let items = [
                URLQueryItem(name: "with_genres", value: "16"),
                URLQueryItem(name: "page", value: "\(page)")
            ]
            let (data, _) = try await executeRequest(endpoint: "/discover/movie", queryItems: items)
            return parseMediaItems(data: data, type: .movie)
        } catch {
            return []
        }
    }

    func fetchPopularSeries() async -> [MediaItem] {
        do {
            let (data, _) = try await executeRequest(endpoint: "/tv/popular")
            return parseMediaItems(data: data, type: .series)
        } catch {
            return []
        }
    }

    func search(query: String) async -> [MediaItem] {
        return await searchMedia(query: query)
    }

    func searchMedia(query: String) async -> [MediaItem] {
        do {
            let items = [URLQueryItem(name: "query", value: query)]
            let (data, _) = try await executeRequest(endpoint: "/search/multi", queryItems: items)

            struct TMDBMultiResponse: Decodable {
                let results: [TMDBMultiItem]?
            }
            struct TMDBMultiItem: Decodable {
                let id: Int
                let title: String?
                let name: String?
                let overview: String?
                let poster_path: String?
                let backdrop_path: String?
                let media_type: String?
                let vote_average: Double?
            }

            let decoded = try JSONDecoder().decode(TMDBMultiResponse.self, from: data)
            guard let raw = decoded.results else { return [] }

            return raw.compactMap { res -> MediaItem? in
                guard let mediaType = res.media_type, (mediaType == "movie" || mediaType == "tv") else { return nil }
                let title = res.title ?? res.name ?? "Untitled"
                let pURL = res.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\( $0 )") }
                let bURL = res.backdrop_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\( $0 )") }
                let type: MediaItem.MediaType = (mediaType == "tv") ? .series : .movie

                return MediaItem(
                    id: "\(res.id)",
                    title: title,
                    description: res.overview,
                    posterUrl: pURL,
                    backdropUrl: bURL,
                    releaseDate: nil,
                    rating: res.vote_average,
                    type: type
                )
            }
        } catch {
            return []
        }
    }

    func fetchTVSeasonsCount(tvID: String) async -> Int {
        do {
            let (data, _) = try await executeRequest(endpoint: "/tv/\(tvID)")
            struct TVDetails: Decodable {
                let number_of_seasons: Int?
            }
            let details = try JSONDecoder().decode(TVDetails.self, from: data)
            return details.number_of_seasons ?? 1
        } catch {
            return 1
        }
    }

    func fetchSeasonEpisodes(tvID: String, seasonNumber: Int) async -> [TVEpisodeItem] {
        do {
            let (data, _) = try await executeRequest(endpoint: "/tv/\(tvID)/season/\(seasonNumber)")
            struct SeasonDetails: Decodable {
                let episodes: [EpisodeRaw]?
            }
            struct EpisodeRaw: Decodable {
                let id: Int
                let episode_number: Int
                let name: String
                let overview: String?
                let still_path: String?
                let vote_average: Double?
                let runtime: Int?
            }

            let details = try JSONDecoder().decode(SeasonDetails.self, from: data)
            guard let rawEps = details.episodes else { return [] }

            return rawEps.map { ep in
                TVEpisodeItem(
                    id: ep.id,
                    episodeNumber: ep.episode_number,
                    name: ep.name,
                    overview: ep.overview,
                    stillPath: ep.still_path,
                    voteAverage: ep.vote_average,
                    runtime: ep.runtime
                )
            }
        } catch {
            return []
        }
    }

    private func parseMediaItems(data: Data, type: MediaItem.MediaType) -> [MediaItem] {
        struct TMDBPageResponse: Decodable {
            let results: [TMDBItemRaw]?
        }
        struct TMDBItemRaw: Decodable {
            let id: Int
            let title: String?
            let name: String?
            let overview: String?
            let poster_path: String?
            let backdrop_path: String?
            let vote_average: Double?
        }

        guard let decoded = try? JSONDecoder().decode(TMDBPageResponse.self, from: data),
              let raw = decoded.results else { return [] }

        return raw.compactMap { res in
            let title = res.title ?? res.name ?? "Untitled"
            let pURL = res.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\( $0 )") }
            let bURL = res.backdrop_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\( $0 )") }

            return MediaItem(
                id: "\(res.id)",
                title: title,
                description: res.overview,
                posterUrl: pURL,
                backdropUrl: bURL,
                releaseDate: nil,
                rating: res.vote_average,
                type: type
            )
        }
    }
}
