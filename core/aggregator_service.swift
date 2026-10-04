import Foundation

/// Represents a high-quality stream link from an aggregator
struct AggregatedLink: Identifiable, Codable {
    let id: UUID
    let title: String
    let url: URL?
    let infoHash: String?
    let quality: String // e.g., "4K", "FHD", "HD", "SD"
    let source: String  // e.g., "Torrentio", "Comet", "Zilean", "Bitmagnet", "Prowlarr", "StremThru"
    var isBestInCategory: Bool = false

    init(id: UUID = UUID(), title: String, url: URL? = nil, infoHash: String? = nil, quality: String, source: String, isBestInCategory: Bool = false) {
        self.id = id
        self.title = title
        self.url = url
        self.infoHash = infoHash
        self.quality = quality
        self.source = source
        self.isBestInCategory = isBestInCategory
    }

    static func cleanQuality(from rawText: String) -> String {
        let text = rawText.lowercased()
        if text.contains("4k") || text.contains("2160p") || text.contains("uhd") {
            return "4K"
        } else if text.contains("1080p") || text.contains("fhd") || text.contains("full hd") {
            return "FHD"
        } else if text.contains("720p") || text.contains("hd") {
            return "HD"
        } else {
            return "SD"
        }
    }
}

/// Protocol for real stream scrapers
protocol StreamProvider {
    var name: String { get }
    func fetchLinks(tmdbID: String, type: MediaItem.MediaType) async throws -> [AggregatedLink]
}

// MARK: - 1. Torrentio Scraper
class TorrentioScraper: StreamProvider {
    let name = "Torrentio (RealDebrid)"
    private let baseURLs = [
        "https://torrentio.strem.fun",
        "https://torrentio.strem.io"
    ]

    func fetchLinks(tmdbID: String, type: MediaItem.MediaType) async throws -> [AggregatedLink] {
        var idList: [String] = []

        if tmdbID.hasPrefix("tt") || tmdbID.hasPrefix("tmdb:") {
            idList.append(tmdbID)
        } else {
            if let imdb = try? await TMDBService().fetchIMDbID(tmdbID: tmdbID, type: type), !imdb.isEmpty {
                idList.append(imdb)
            }
            idList.append("tmdb:\(tmdbID)")
        }

        let mediaPath = (type == .series) ? "series" : "movie"
        let rdKey = Config.realDebridApiKey
        var allStreams: [AggregatedLink] = []

        for rawID in idList {
            let streamID: String
            if type == .series && !rawID.contains(":") {
                streamID = "\(rawID):1:1"
            } else {
                streamID = rawID
            }

            for baseURL in baseURLs {
                let urlString: String
                if !rdKey.isEmpty {
                    urlString = "\(baseURL)/realdebrid=\(rdKey)/stream/\(mediaPath)/\(streamID).json"
                } else {
                    urlString = "\(baseURL)/stream/\(mediaPath)/\(streamID).json"
                }

                guard let url = URL(string: urlString) else { continue }
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { continue }

                    struct StreamItem: Decodable {
                        let name: String?
                        let title: String?
                        let url: String?
                        let infoHash: String?
                    }
                    struct StreamResponse: Decodable {
                        let streams: [StreamItem]?
                    }

                    let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)
                    if let streams = decoded.streams, !streams.isEmpty {
                        let links = streams.compactMap { stream -> AggregatedLink? in
                            let titleText = stream.title ?? stream.name ?? "RealDebrid Stream"
                            let nameText = stream.name ?? ""
                            let combinedText = "\(nameText) \(titleText)"

                            let quality = AggregatedLink.cleanQuality(from: combinedText)
                            let streamURL = stream.url.flatMap { URL(string: $0) }

                            return AggregatedLink(
                                title: titleText,
                                url: streamURL,
                                infoHash: stream.infoHash,
                                quality: quality,
                                source: name
                            )
                        }
                        allStreams.append(contentsOf: links)
                        if !allStreams.isEmpty { break }
                    }
                } catch {
                    print("Torrentio scrape error (\(streamID)): \(error.localizedDescription)")
                }
            }
            if !allStreams.isEmpty { break }
        }

        return allStreams
    }
}

// MARK: - 2. Comet Scraper
class CometScraper: StreamProvider {
    let name = "Comet (Local)"

    func fetchLinks(tmdbID: String, type: MediaItem.MediaType) async throws -> [AggregatedLink] {
        let cometBase = Config.cometUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cometBase.isEmpty, let _ = URL(string: cometBase) else { return [] }

        var imdbID: String? = nil
        if tmdbID.hasPrefix("tt") {
            imdbID = tmdbID
        } else {
            imdbID = try? await TMDBService().fetchIMDbID(tmdbID: tmdbID, type: type)
        }

        guard var targetID = imdbID ?? (tmdbID.hasPrefix("tt") ? tmdbID : nil) else { return [] }
        if type == .series && !targetID.contains(":") {
            targetID = "\(targetID):1:1"
        }

        let mediaPath = (type == .series) ? "series" : "movie"
        let rdKey = Config.realDebridApiKey

        let urlString: String
        if !rdKey.isEmpty {
            urlString = "\(cometBase)/realdebrid=\(rdKey)/stream/\(mediaPath)/\(targetID).json"
        } else {
            urlString = "\(cometBase)/stream/\(mediaPath)/\(targetID).json"
        }

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return [] }

            struct StreamItem: Decodable {
                let name: String?
                let title: String?
                let url: String?
                let infoHash: String?
            }
            struct StreamResponse: Decodable {
                let streams: [StreamItem]?
            }

            let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)
            guard let streams = decoded.streams else { return [] }

            return streams.compactMap { stream in
                let titleText = stream.title ?? stream.name ?? "Comet Stream"
                let nameText = stream.name ?? ""
                let combinedText = "\(nameText) \(titleText)"

                let quality = AggregatedLink.cleanQuality(from: combinedText)
                let streamURL = stream.url.flatMap { URL(string: $0) }
                return AggregatedLink(
                    title: titleText,
                    url: streamURL,
                    infoHash: stream.infoHash,
                    quality: quality,
                    source: name
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - 3. Zilean Scraper
class ZileanScraper: StreamProvider {
    let name = "Zilean (DHT Cache)"

    func fetchLinks(tmdbID: String, type: MediaItem.MediaType) async throws -> [AggregatedLink] {
        let zileanBase = Config.zileanUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !zileanBase.isEmpty else { return [] }

        var imdbID: String? = nil
        if tmdbID.hasPrefix("tt") {
            imdbID = tmdbID
        } else {
            imdbID = try? await TMDBService().fetchIMDbID(tmdbID: tmdbID, type: type)
        }

        guard let searchURL = URL(string: "\(zileanBase)/api/v1/media/search") else { return [] }

        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 2.0

        struct ZileanQuery: Encodable {
            let query: String?
            let imdbId: String?
        }

        let queryBody = ZileanQuery(query: nil, imdbId: imdbID)
        request.httpBody = try? JSONEncoder().encode(queryBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return [] }

            struct ZileanResult: Decodable {
                let infoHash: String?
                let rawTitle: String?
                let size: Int64?
            }

            let results = try JSONDecoder().decode([ZileanResult].self, from: data)

            return results.compactMap { res -> AggregatedLink? in
                guard let hash = res.infoHash, !hash.isEmpty else { return nil }
                let rawTitle = res.rawTitle ?? "Zilean Torrent Stream"
                let quality = AggregatedLink.cleanQuality(from: rawTitle)

                return AggregatedLink(
                    title: rawTitle,
                    url: nil,
                    infoHash: hash,
                    quality: quality,
                    source: name
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - 4. Bitmagnet Scraper
class BitmagnetScraper: StreamProvider {
    let name = "Bitmagnet (Swarm)"

    func fetchLinks(tmdbID: String, type: MediaItem.MediaType) async throws -> [AggregatedLink] {
        let bitmagnetBase = "http://localhost:3333"
        guard let searchURL = URL(string: "\(bitmagnetBase)/api/v1/torrents") else { return [] }

        var imdbID: String? = nil
        if tmdbID.hasPrefix("tt") {
            imdbID = tmdbID
        } else {
            imdbID = try? await TMDBService().fetchIMDbID(tmdbID: tmdbID, type: type)
        }

        guard let targetQuery = imdbID ?? tmdbID as String? else { return [] }

        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "query", value: targetQuery)]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return [] }

            struct BitmagnetTorrent: Decodable {
                let infoHash: String?
                let name: String?
            }
            struct BitmagnetResponse: Decodable {
                let items: [BitmagnetTorrent]?
            }

            let decoded = try JSONDecoder().decode(BitmagnetResponse.self, from: data)
            guard let items = decoded.items else { return [] }

            return items.compactMap { torrent in
                guard let hash = torrent.infoHash, let title = torrent.name else { return nil }
                let quality = AggregatedLink.cleanQuality(from: title)

                return AggregatedLink(
                    title: title,
                    url: nil,
                    infoHash: hash,
                    quality: quality,
                    source: name
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - 5. Prowlarr Scraper
class ProwlarrScraper: StreamProvider {
    let name = "Prowlarr (Indexers)"

    func fetchLinks(tmdbID: String, type: MediaItem.MediaType) async throws -> [AggregatedLink] {
        let prowlarrBase = Config.prowlarrUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let apiKey = Config.prowlarrApiKey
        guard !prowlarrBase.isEmpty, !apiKey.isEmpty else { return [] }

        var imdbID: String? = nil
        if tmdbID.hasPrefix("tt") {
            imdbID = tmdbID
        } else {
            imdbID = try? await TMDBService().fetchIMDbID(tmdbID: tmdbID, type: type)
        }

        guard var components = URLComponents(string: "\(prowlarrBase)/api/v1/search") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "query", value: imdbID ?? tmdbID),
            URLQueryItem(name: "type", value: "search")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = 2.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return [] }

            struct ProwlarrRelease: Decodable {
                let title: String?
                let downloadUrl: String?
                let infoHash: String?
                let indexer: String?
            }

            let releases = try JSONDecoder().decode([ProwlarrRelease].self, from: data)

            return releases.compactMap { rel -> AggregatedLink? in
                guard let title = rel.title else { return nil }
                let quality = AggregatedLink.cleanQuality(from: title)

                let downloadURL = rel.downloadUrl.flatMap { URL(string: $0) }
                let sourceName = rel.indexer != nil ? "Prowlarr (\(rel.indexer!))" : name

                return AggregatedLink(
                    title: title,
                    url: downloadURL,
                    infoHash: rel.infoHash,
                    quality: quality,
                    source: sourceName
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - 6. StremThru Scraper
class StremThruScraper: StreamProvider {
    let name = "StremThru (Proxy)"

    func fetchLinks(tmdbID: String, type: MediaItem.MediaType) async throws -> [AggregatedLink] {
        let stremthruBase = Config.stremthruUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !stremthruBase.isEmpty, let _ = URL(string: stremthruBase) else { return [] }

        var imdbID: String? = nil
        if tmdbID.hasPrefix("tt") {
            imdbID = tmdbID
        } else {
            imdbID = try? await TMDBService().fetchIMDbID(tmdbID: tmdbID, type: type)
        }

        var targetID = imdbID ?? tmdbID
        if type == .series && !targetID.contains(":") {
            targetID = "\(targetID):1:1"
        }
        let mediaPath = (type == .series) ? "series" : "movie"

        guard let url = URL(string: "\(stremthruBase)/stream/\(mediaPath)/\(targetID).json") else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return [] }

            struct StreamItem: Decodable {
                let name: String?
                let title: String?
                let url: String?
            }
            struct StreamResponse: Decodable {
                let streams: [StreamItem]?
            }

            let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)
            guard let streams = decoded.streams else { return [] }

            return streams.compactMap { stream in
                let titleText = stream.title ?? stream.name ?? "StremThru Stream"
                let streamURL = stream.url.flatMap { URL(string: $0) }
                let quality = AggregatedLink.cleanQuality(from: titleText)

                return AggregatedLink(
                    title: titleText,
                    url: streamURL,
                    infoHash: nil,
                    quality: quality,
                    source: name
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - Master Multi-Indexer Aggregator Service
class AggregatorService {
    private let providers: [StreamProvider]
    private let rdService = RealDebridService()

    init() {
        self.providers = [
            TorrentioScraper(),
            CometScraper(),
            ZileanScraper(),
            BitmagnetScraper(),
            ProwlarrScraper(),
            StremThruScraper()
        ]
    }

    func getBestLinks(tmdbID: String, type: MediaItem.MediaType) async throws -> [AggregatedLink] {
        var allLinks: [AggregatedLink] = []

        await withTaskGroup(of: [AggregatedLink].self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return try await provider.fetchLinks(tmdbID: tmdbID, type: type)
                    } catch {
                        print("Provider \(provider.name) error: \(error.localizedDescription)")
                        return []
                    }
                }
            }

            for await links in group {
                allLinks.append(contentsOf: links)
            }
        }

        // Deduplicate links by infoHash or URL
        var seenHashes = Set<String>()
        var seenURLs = Set<String>()
        var uniqueLinks: [AggregatedLink] = []

        for link in allLinks {
            if let hash = link.infoHash, !hash.isEmpty {
                if seenHashes.contains(hash.lowercased()) { continue }
                seenHashes.insert(hash.lowercased())
            } else if let urlStr = link.url?.absoluteString {
                if seenURLs.contains(urlStr) { continue }
                seenURLs.insert(urlStr)
            }
            uniqueLinks.append(link)
        }

        // Quality Order Priority: 4K -> FHD -> HD -> SD
        let qualityPriority: [String: Int] = ["4K": 4, "FHD": 3, "HD": 2, "SD": 1]
        let sorted = uniqueLinks.sorted {
            let p1 = qualityPriority[$0.quality] ?? 0
            let p2 = qualityPriority[$1.quality] ?? 0
            return p1 > p2
        }

        // Mark top result in each quality category as "Best in Category"
        var seenQualities = Set<String>()
        var processedLinks: [AggregatedLink] = []

        for var link in sorted {
            if !seenQualities.contains(link.quality) {
                link.isBestInCategory = true
                seenQualities.insert(link.quality)
            }
            processedLinks.append(link)
        }

        return processedLinks
    }

    /// Resolves an AggregatedLink to a direct playable streaming URL via RealDebrid
    func resolveStreamURL(for link: AggregatedLink) async throws -> URL {
        if let directURL = link.url {
            return try await rdService.unrestrict(link: directURL)
        } else if let hash = link.infoHash {
            return try await rdService.addMagnetAndGetLink(infoHash: hash)
        } else {
            throw NSError(domain: "Aggregator", code: 404, userInfo: [NSLocalizedDescriptionKey: "No valid URL or infoHash available for this stream."])
        }
    }
}
