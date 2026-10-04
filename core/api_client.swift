import Foundation

struct Config {
    static var realDebridApiKey: String {
        get {
            let key = UserDefaults.standard.string(forKey: "RealDebridAPIKey") ?? ""
            return key.isEmpty ? "35YSSAUYGV6RXRAXGSRV56YLJA7VH5FLPC76L24ZGNNPSJXPAXEA" : key
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "RealDebridAPIKey")
        }
    }

    static var preferredSubtitleLanguage: String {
        get {
            return UserDefaults.standard.string(forKey: "PreferredSubtitleLanguage") ?? "fr"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "PreferredSubtitleLanguage")
        }
    }

    static let tmdbApiKey = "8f36dbd8eea12eefae2aeef2f1cac20c"

    // Multi-Indexer Local Scraper Endpoints
    static var cometUrl: String = "http://localhost:8000"
    static var zileanUrl: String = "http://localhost:8181"
    static var prowlarrUrl: String = "http://localhost:9696"
    static var stremthruUrl: String = "http://localhost:8080"
    static var prowlarrApiKey: String = ""
}

// MARK: - Subtitle Service
struct SubtitleTrack: Identifiable, Codable {
    let id: String
    let lang: String // e.g. "fr", "en"
    let label: String // e.g. "French", "English"
    let url: URL
}

class SubtitleService {
    /// Fetches subtitles from Stremio OpenSubtitles v3 API for the given IMDb ID and preferred language
    func fetchSubtitles(imdbID: String, type: MediaItem.MediaType, preferredLang: String = Config.preferredSubtitleLanguage) async -> [SubtitleTrack] {
        let mediaType = (type == .series) ? "series" : "movie"
        let targetID = (type == .series && !imdbID.contains(":")) ? "\(imdbID):1:1" : imdbID
        let urlString = "https://opensubtitles-v3.strem.io/subtitles/\(mediaType)/\(targetID).json"

        guard let url = URL(string: urlString) else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return [] }

            struct SubItem: Decodable {
                let id: String?
                let lang: String?
                let url: String?
            }
            struct SubResponse: Decodable {
                let subtitles: [SubItem]?
            }

            let decoded = try JSONDecoder().decode(SubResponse.self, from: data)
            guard let subs = decoded.subtitles else { return [] }

            let filtered = subs.compactMap { sub -> SubtitleTrack? in
                guard let subURLStr = sub.url, let subURL = URL(string: subURLStr), let lang = sub.lang else { return nil }
                let label = SubtitleService.languageName(for: lang)
                return SubtitleTrack(id: sub.id ?? UUID().uuidString, lang: lang, label: label, url: subURL)
            }

            return filtered.sorted { sub1, sub2 in
                if sub1.lang == preferredLang { return true }
                if sub2.lang == preferredLang { return false }
                if sub1.lang == "en" || sub1.lang == "eng" { return true }
                return false
            }
        } catch {
            return []
        }
    }

    static func languageName(for code: String) -> String {
        switch code.lowercased() {
        case "fr", "fre", "fra": return "French (Français)"
        case "en", "eng": return "English"
        case "es", "spa": return "Spanish (Español)"
        case "de", "ger", "deu": return "German (Deutsch)"
        case "it", "ita": return "Italian (Italiano)"
        case "tr", "tur": return "Turkish (Türkçe)"
        case "pt", "por": return "Portuguese (Português)"
        case "ru", "rus": return "Russian (Русский)"
        case "ja", "jpn": return "Japanese (日本語)"
        case "zh", "zho", "chi": return "Chinese (中文)"
        default: return code.uppercased()
        }
    }
}

// MARK: - Real-Debrid API Client
class RealDebridService {
    private let baseURL = "https://api.realdebrid.com/v1"
    private var apiKey: String {
        return Config.realDebridApiKey
    }

    /// Fetches RealDebrid user account details using specific user key or default key
    func fetchUser(customKey: String? = nil) async throws -> RealDebridUser {
        let activeKey = (customKey?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? apiKey
        guard let url = URL(string: "\(baseURL)/user") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(activeKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "No network response from RealDebrid."])
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NSError(domain: "RealDebrid", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid or unauthorized RealDebrid API Key. Check key in settings."])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "RealDebrid", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "RealDebrid API error (HTTP \(httpResponse.statusCode))."])
        }

        return try JSONDecoder().decode(RealDebridUser.self, from: data)
    }

    /// Fetches user's active torrents list from RealDebrid cloud storage
    func fetchTorrents() async throws -> [RealDebridTorrentItem] {
        guard let url = URL(string: "\(baseURL)/torrents") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

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

    /// Unrestricts a debrid link or hoster link to return a direct high-speed downloadable/streamable URL
    func unrestrict(link: URL) async throws -> URL {
        return try await unrestrict(urlString: link.absoluteString)
    }

    func unrestrict(urlString: String) async throws -> URL {
        guard let url = URL(string: "\(baseURL)/unrestrict/link") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = "link=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)"
        request.httpBody = bodyString.data(using: .utf8)

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

    /// Legacy completion-handler based method for backward compatibility
    func fetchStream(itemID: String, completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                let url = try await unrestrict(urlString: itemID)
                completion(.success(url))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Adds a magnet link by infoHash to RealDebrid, selects files, and unrestricts the resulting stream URL
    func addMagnetAndGetLink(infoHash: String) async throws -> URL {
        let magnetURI = "magnet:?xt=urn:btih:\(infoHash)"
        guard let addURL = URL(string: "\(baseURL)/torrents/addMagnet") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        var addRequest = URLRequest(url: addURL)
        addRequest.httpMethod = "POST"
        addRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        addRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        addRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        addRequest.httpBody = "magnet=\(magnetURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? magnetURI)".data(using: .utf8)

        let (addData, addResponse) = try await URLSession.shared.data(for: addRequest)
        guard let addHTTP = addResponse as? HTTPURLResponse, (200...299).contains(addHTTP.statusCode) else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to add magnet to RealDebrid."])
        }

        struct AddMagnetResult: Decodable {
            let id: String
        }

        let torrentResult = try JSONDecoder().decode(AddMagnetResult.self, from: addData)
        let torrentID = torrentResult.id

        // Select all files
        guard let selectURL = URL(string: "\(baseURL)/torrents/selectFiles/\(torrentID)") else {
            throw NSError(domain: "RealDebrid", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid select files URL"])
        }
        var selectRequest = URLRequest(url: selectURL)
        selectRequest.httpMethod = "POST"
        selectRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        selectRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        selectRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        selectRequest.httpBody = "files=all".data(using: .utf8)

        _ = try await URLSession.shared.data(for: selectRequest)

        // Poll torrent info for download link
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            guard let infoURL = URL(string: "\(baseURL)/torrents/info/\(torrentID)") else { continue }
            var infoRequest = URLRequest(url: infoURL)
            infoRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            infoRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

            let (infoData, infoResp) = try await URLSession.shared.data(for: infoRequest)
            guard let infoHTTP = infoResp as? HTTPURLResponse, (200...299).contains(infoHTTP.statusCode) else { continue }

            struct TorrentInfo: Decodable {
                let status: String
                let links: [String]?
            }

            let info = try JSONDecoder().decode(TorrentInfo.self, from: infoData)
            if let firstLink = info.links?.first, !firstLink.isEmpty {
                return try await unrestrict(urlString: firstLink)
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
        self.value = try? container.decode(T.self)
    }
}

private struct FlexibleID: Decodable {
    let stringValue: String
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self.stringValue = String(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self.stringValue = strVal
        } else {
            self.stringValue = ""
        }
    }
}

private struct FlexibleDouble: Decodable {
    let doubleValue: Double?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            self.doubleValue = d
        } else if let i = try? container.decode(Int.self) {
            self.doubleValue = Double(i)
        } else if let s = try? container.decode(String.self), let d = Double(s) {
            self.doubleValue = d
        } else {
            self.doubleValue = nil
        }
    }
}

// MARK: - TMDB Service API Client
class TMDBService {
    private let baseURL = "https://api.themoviedb.org/3"
    private var apiKey: String {
        return Config.tmdbApiKey
    }

    private struct TMDBMovie: Decodable {
        let id: FlexibleID
        let title: String?
        let name: String? // TV Shows
        let overview: String?
        let poster_path: String?
        let backdrop_path: String?
        let release_date: String?
        let first_air_date: String?
        let vote_average: FlexibleDouble?
        let media_type: String?
    }

    private struct TMDBListResponse: Decodable {
        let results: [FailableDecodable<TMDBMovie>]?
    }

    private struct ExternalIDsResponse: Decodable {
        let imdb_id: String?
    }

    /// Fetches IMDb ID for a given TMDB movie or TV series ID
    func fetchIMDbID(tmdbID: String, type: MediaItem.MediaType) async throws -> String? {
        let endpoint = type == .movie ? "movie" : "tv"
        guard var components = URLComponents(string: "\(baseURL)/\(endpoint)/\(tmdbID)/external_ids") else { return nil }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else { return nil }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return nil }

        let externalIDs = try JSONDecoder().decode(ExternalIDsResponse.self, from: data)
        return externalIDs.imdb_id
    }

    func fetchPopularMovies() async throws -> [MediaItem] {
        guard var components = URLComponents(string: "\(baseURL)/movie/popular") else {
            throw NSError(domain: "TMDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else {
            throw NSError(domain: "TMDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        return try await fetchMediaItems(from: url, defaultType: .movie)
    }

    func fetchTrending() async throws -> [MediaItem] {
        guard var components = URLComponents(string: "\(baseURL)/trending/all/day") else {
            throw NSError(domain: "TMDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else {
            throw NSError(domain: "TMDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        return try await fetchMediaItems(from: url, defaultType: .movie)
    }

    func search(query: String) async throws -> [MediaItem] {
        guard var movieComponents = URLComponents(string: "\(baseURL)/search/movie"),
              var tvComponents = URLComponents(string: "\(baseURL)/search/tv") else {
            throw NSError(domain: "TMDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        movieComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query)
        ]
        tvComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query)
        ]

        guard let movieURL = movieComponents.url, let tvURL = tvComponents.url else {
            throw NSError(domain: "TMDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Search URL"])
        }

        async let movieResults = (try? fetchMediaItems(from: movieURL, defaultType: .movie)) ?? []
        async let tvResults = (try? fetchMediaItems(from: tvURL, defaultType: .series)) ?? []

        let movies = await movieResults
        let tvShows = await tvResults

        var combined: [MediaItem] = []
        let maxCount = max(movies.count, tvShows.count)
        for i in 0..<maxCount {
            if i < movies.count { combined.append(movies[i]) }
            if i < tvShows.count { combined.append(tvShows[i]) }
        }

        return combined
    }

    func fetchMetadata(tmdbID: String, completion: @escaping (Result<MediaItem, Error>) -> Void) {
        Task {
            do {
                guard var components = URLComponents(string: "\(baseURL)/movie/\(tmdbID)") else {
                    throw NSError(domain: "TMDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
                guard let url = components.url else {
                    throw NSError(domain: "TMDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }

                let (data, _) = try await URLSession.shared.data(from: url)
                let item = try JSONDecoder().decode(TMDBMovie.self, from: data)
                let imdbID = try await fetchIMDbID(tmdbID: tmdbID, type: .movie)

                let mediaItem = mapMovieToMediaItem(item, defaultType: .movie, imdbID: imdbID)
                completion(.success(mediaItem))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func fetchMediaItems(from url: URL, defaultType: MediaItem.MediaType) async throws -> [MediaItem] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "TMDB", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "TMDB request failed."])
        }

        let listResponse = try JSONDecoder().decode(TMDBListResponse.self, from: data)
        let movies = listResponse.results?.compactMap { $0.value } ?? []
        return movies.compactMap { mapMovieToMediaItem($0, defaultType: defaultType) }
    }

    private func mapMovieToMediaItem(_ movie: TMDBMovie, defaultType: MediaItem.MediaType, imdbID: String? = nil) -> MediaItem {
        let titleStr = movie.title ?? movie.name ?? "Untitled"
        let releaseStr = movie.release_date ?? movie.first_air_date
        let releaseDate = releaseStr.flatMap { DateFormatter.yyyyMMdd.date(from: $0) }
        let type: MediaItem.MediaType = (movie.media_type == "tv") ? .series : defaultType

        let posterURL = movie.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
        let backdropURL = movie.backdrop_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }

        return MediaItem(
            id: movie.id.stringValue,
            title: titleStr,
            description: movie.overview,
            posterUrl: posterURL,
            backdropUrl: backdropURL,
            releaseDate: releaseDate,
            rating: movie.vote_average?.doubleValue,
            type: type,
            imdbID: imdbID
        )
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
