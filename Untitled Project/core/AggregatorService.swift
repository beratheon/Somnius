import Foundation

protocol StreamProvider {
    var name: String { get }
    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink]
}

// MARK: - Helper for RD Config String
private func rdConfigPath() -> String {
    let key = Config.realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    if !key.isEmpty {
        return "realdebrid=\(key)"
    }
    return ""
}

// MARK: - 1. Torrentio Scraper (Multi-Debrid Enabled)
class TorrentioScraper: StreamProvider {
    let name = "Torrentio"

    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink] {
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        let mediaPath = (type == .series) ? "series" : "movie"
        let rdConfig = rdConfigPath()

        var endpoints: [String] = []
        if !rdConfig.isEmpty {
            endpoints.append("https://torrentio.strem.fun/\(rdConfig)")
        }
        endpoints.append("https://torrentio.strem.fun")

        var allLinks: [AggregatedLink] = []

        for base in endpoints {
            let cleanBase = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let url = URL(string: "\(cleanBase)/stream/\(mediaPath)/\(targetID).json") else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            request.setValue("Stremio/4.4.168 (macOS; x86_64)", forHTTPHeaderField: "User-Agent")

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
                    let items = streams.compactMap { stream -> AggregatedLink? in
                        let titleText = stream.title ?? stream.name ?? "Torrentio Stream"
                        let nameText = stream.name ?? ""
                        let combinedText = "\(nameText) \n \(titleText)"
                        let streamURL = stream.url.flatMap { URL(string: $0) }

                        return StreamParser.parse(rawTitle: combinedText, source: name, url: streamURL, infoHash: stream.infoHash)
                    }
                    if !items.isEmpty {
                        allLinks.append(contentsOf: items)
                        break
                    }
                }
            } catch {
                continue
            }
        }

        return allLinks
    }
}

// MARK: - 2. Comet Scraper
class CometScraper: StreamProvider {
    let name = "Comet"

    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink] {
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        let mediaPath = (type == .series) ? "series" : "movie"
        let rdConfig = rdConfigPath()

        var endpoints: [String] = []
        if !rdConfig.isEmpty {
            endpoints.append("https://comet.elfhosted.com/\(rdConfig)")
        }
        endpoints.append("https://comet.elfhosted.com")
        endpoints.append(Config.cometUrl)

        var allLinks: [AggregatedLink] = []

        for base in endpoints {
            let cleanBase = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !cleanBase.isEmpty else { continue }
            guard let url = URL(string: "\(cleanBase)/stream/\(mediaPath)/\(targetID).json") else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 3.5

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
                    let items = streams.compactMap { stream -> AggregatedLink? in
                        let titleText = stream.title ?? stream.name ?? "Comet Stream"
                        let nameText = stream.name ?? ""
                        let combinedText = "\(nameText) \n \(titleText)"
                        let streamURL = stream.url.flatMap { URL(string: $0) }

                        return StreamParser.parse(rawTitle: combinedText, source: name, url: streamURL, infoHash: stream.infoHash)
                    }
                    if !items.isEmpty {
                        allLinks.append(contentsOf: items)
                        break
                    }
                }
            } catch {
                continue
            }
        }

        return allLinks
    }
}

// MARK: - 3. MediaFusion Scraper
class MediaFusionScraper: StreamProvider {
    let name = "MediaFusion"

    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink] {
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        let mediaPath = (type == .series) ? "series" : "movie"
        let rdConfig = rdConfigPath()

        var endpoints: [String] = []
        if !rdConfig.isEmpty {
            endpoints.append("https://mediafusion.elfhosted.com/\(rdConfig)")
        }
        endpoints.append("https://mediafusion.elfhosted.com")

        var allLinks: [AggregatedLink] = []

        for base in endpoints {
            let cleanBase = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let url = URL(string: "\(cleanBase)/stream/\(mediaPath)/\(targetID).json") else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 3.5

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
                    let items = streams.compactMap { stream -> AggregatedLink? in
                        let titleText = stream.title ?? stream.name ?? "MediaFusion Stream"
                        let nameText = stream.name ?? ""
                        let combinedText = "\(nameText) \n \(titleText)"
                        let streamURL = stream.url.flatMap { URL(string: $0) }

                        return StreamParser.parse(rawTitle: combinedText, source: name, url: streamURL, infoHash: stream.infoHash)
                    }
                    if !items.isEmpty {
                        allLinks.append(contentsOf: items)
                        break
                    }
                }
            } catch {
                continue
            }
        }

        return allLinks
    }
}

// MARK: - 4. Knightcrawler Scraper
class KnightcrawlerScraper: StreamProvider {
    let name = "Knightcrawler"

    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink] {
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        let mediaPath = (type == .series) ? "series" : "movie"
        let rdConfig = rdConfigPath()

        var endpoints: [String] = []
        if !rdConfig.isEmpty {
            endpoints.append("https://knightcrawler.elfhosted.com/\(rdConfig)")
        }
        endpoints.append("https://knightcrawler.elfhosted.com")

        var allLinks: [AggregatedLink] = []

        for base in endpoints {
            let cleanBase = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let url = URL(string: "\(cleanBase)/stream/\(mediaPath)/\(targetID).json") else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 3.5

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
                    let items = streams.compactMap { stream -> AggregatedLink? in
                        let titleText = stream.title ?? stream.name ?? "Knightcrawler Stream"
                        let nameText = stream.name ?? ""
                        let combinedText = "\(nameText) \n \(titleText)"
                        let streamURL = stream.url.flatMap { URL(string: $0) }

                        return StreamParser.parse(rawTitle: combinedText, source: name, url: streamURL, infoHash: stream.infoHash)
                    }
                    if !items.isEmpty {
                        allLinks.append(contentsOf: items)
                        break
                    }
                }
            } catch {
                continue
            }
        }

        return allLinks
    }
}

// MARK: - 5. Zilean & DMM Scraper
class ZileanScraper: StreamProvider {
    let name = "Zilean & Bitmagnet"

    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink] {
        let mediaPath = (type == .series) ? "series" : "movie"
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        var allLinks: [AggregatedLink] = []

        // A. Stremio Addon API
        let stremioEndpoints = [
            "https://zilean.elfhosted.com",
            Config.zileanUrl
        ]

        for base in stremioEndpoints {
            let cleanBase = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !cleanBase.isEmpty else { continue }
            guard let url = URL(string: "\(cleanBase)/stream/\(mediaPath)/\(targetID).json") else { continue }

            var req = URLRequest(url: url)
            req.timeoutInterval = 3.5
            req.setValue("Stremio/4.4.168 (macOS; x86_64)", forHTTPHeaderField: "User-Agent")

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { continue }

                struct StreamItem: Decodable {
                    let name: String?
                    let title: String?
                    let url: String?
                    let infoHash: String?
                }
                struct StreamResponse: Decodable {
                    let streams: [StreamItem]?
                }

                if let decoded = try? JSONDecoder().decode(StreamResponse.self, from: data),
                   let streams = decoded.streams, !streams.isEmpty {
                    let items = streams.compactMap { s -> AggregatedLink? in
                        let t = s.title ?? s.name ?? "Zilean Stream"
                        let streamURL = s.url.flatMap { URL(string: $0) }
                        return StreamParser.parse(rawTitle: t, source: name, url: streamURL, infoHash: s.infoHash)
                    }
                    allLinks.append(contentsOf: items)
                }
            } catch {}
        }

        // B. Zilean Native DMM API Endpoint (/dmm/filtered)
        let title = (try? await TMDBService().fetchTitle(tmdbID: tmdbID, type: type)) ?? ""
        let category = (type == .series) ? "tv" : "movie"

        var components = URLComponents(string: "\(Config.zileanUrl)/dmm/filtered")
        var queryItems = [
            URLQueryItem(name: "Query", value: title),
            URLQueryItem(name: "ImdbId", value: imdbID),
            URLQueryItem(name: "Category", value: category)
        ]
        if type == .series, let s = season, let e = episode {
            queryItems.append(URLQueryItem(name: "Season", value: "\(s)"))
            queryItems.append(URLQueryItem(name: "Episode", value: "\(e)"))
        }
        components?.queryItems = queryItems

        if let dmmURL = components?.url {
            var dmmReq = URLRequest(url: dmmURL)
            dmmReq.timeoutInterval = 3.5

            do {
                let (data, resp) = try await URLSession.shared.data(for: dmmReq)
                if let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    struct DmmTorrentInfo: Decodable {
                        let raw_title: String?
                        let parsed_title: String?
                        let info_hash: String?
                        let resolution: String?
                        let size: String?
                    }

                    if let dmmItems = try? JSONDecoder().decode([DmmTorrentInfo].self, from: data) {
                        let items = dmmItems.compactMap { dmm -> AggregatedLink? in
                            guard let hash = dmm.info_hash, !hash.isEmpty else { return nil }
                            let rawTitle = dmm.raw_title ?? dmm.parsed_title ?? title
                            let sz = dmm.size != nil ? " [\(dmm.size!)]" : ""
                            let combined = "\(rawTitle)\(sz)"
                            return StreamParser.parse(rawTitle: combined, source: name, url: nil, infoHash: hash)
                        }
                        allLinks.append(contentsOf: items)
                    }
                }
            } catch {}
        }

        return allLinks
    }
}

// MARK: - 6. Cyberflix Scraper
class CyberflixScraper: StreamProvider {
    let name = "Cyberflix"

    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink] {
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        let mediaPath = (type == .series) ? "series" : "movie"
        let rdConfig = rdConfigPath()

        var endpoints: [String] = []
        if !rdConfig.isEmpty {
            endpoints.append("https://cyberflix.elfhosted.com/\(rdConfig)")
        }
        endpoints.append("https://cyberflix.elfhosted.com")

        var allLinks: [AggregatedLink] = []

        for base in endpoints {
            let cleanBase = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let url = URL(string: "\(cleanBase)/stream/\(mediaPath)/\(targetID).json") else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 3.5

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
                    let items = streams.compactMap { stream -> AggregatedLink? in
                        let titleText = stream.title ?? stream.name ?? "Cyberflix Stream"
                        let nameText = stream.name ?? ""
                        let combinedText = "\(nameText) \n \(titleText)"
                        let streamURL = stream.url.flatMap { URL(string: $0) }

                        return StreamParser.parse(rawTitle: combinedText, source: name, url: streamURL, infoHash: stream.infoHash)
                    }
                    if !items.isEmpty {
                        allLinks.append(contentsOf: items)
                        break
                    }
                }
            } catch {
                continue
            }
        }

        return allLinks
    }
}

// MARK: - 7. PirateBay Scraper (Fallback)
class PirateBayScraper: StreamProvider {
    let name = "PirateBay"

    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink] {
        guard let title = try? await TMDBService().fetchTitle(tmdbID: tmdbID, type: type) else { return [] }

        var searchQuery = title
        if type == .series, let s = season, let e = episode {
            searchQuery += String(format: " S%02dE%02d", s, e)
        }

        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://apibay.org/q.php?q=\(encodedQuery)") else { return [] }

        var req = URLRequest(url: url)
        req.timeoutInterval = 2.5
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }

            struct PBItem: Decodable {
                let name: String
                let info_hash: String
                let size: String
                let seeders: String
            }

            let items = try JSONDecoder().decode([PBItem].self, from: data)
            return items.prefix(10).compactMap { item -> AggregatedLink? in
                guard item.info_hash != "0000000000000000000000000000000000000000" else { return nil }
                let rawTitle = "\(item.name) [\(item.seeders) seeders]"
                return StreamParser.parse(rawTitle: rawTitle, source: name, url: nil, infoHash: item.info_hash)
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
    private let tmdbService = TMDBService()

    init() {
        self.providers = [
            TorrentioScraper(),
            CometScraper(),
            MediaFusionScraper(),
            KnightcrawlerScraper(),
            ZileanScraper(),
            CyberflixScraper(),
            PirateBayScraper()
        ]
    }

    func fetchBestLinks(tmdbID: String, imdbID: String? = nil, type: MediaItem.MediaType, season: Int? = nil, episode: Int? = nil) async throws -> [AggregatedLink] {
        return try await getBestLinks(tmdbID: tmdbID, imdbID: imdbID, type: type, season: season, episode: episode)
    }

    func getBestLinks(tmdbID: String, imdbID: String? = nil, type: MediaItem.MediaType, season: Int? = nil, episode: Int? = nil) async throws -> [AggregatedLink] {
        // Resolve IMDb ID once so providers don't duplicate TMDB calls
        var resolvedIMDb: String? = imdbID
        if resolvedIMDb == nil || resolvedIMDb!.isEmpty {
            if tmdbID.hasPrefix("tt") {
                resolvedIMDb = tmdbID
            } else {
                resolvedIMDb = try? await tmdbService.fetchIMDbID(tmdbID: tmdbID, type: type)
            }
        }

        guard let baseIMDb = resolvedIMDb, !baseIMDb.isEmpty else {
            return []
        }

        var allLinks: [AggregatedLink] = []

        await withTaskGroup(of: [AggregatedLink].self) { group in
            for provider in providers {
                let providerName = provider.name
                group.addTask {
                    do {
                        return try await provider.fetchLinks(imdbID: baseIMDb, tmdbID: tmdbID, type: type, season: season, episode: episode)
                    } catch {
                        print("Provider \(providerName) error: \(error.localizedDescription)")
                        return []
                    }
                }
            }

            for await links in group {
                allLinks.append(contentsOf: links)
            }
        }

        // RealDebrid Instant Availability Cache Verification
        let hashesToCheck = allLinks.compactMap { $0.infoHash }
        if !hashesToCheck.isEmpty, let cachedSet = try? await rdService.checkInstantAvailability(hashes: hashesToCheck), !cachedSet.isEmpty {
            allLinks = allLinks.map { link in
                if let h = link.infoHash, cachedSet.contains(h.lowercased()) {
                    var updated = link
                    updated.isCached = true
                    return updated
                }
                return link
            }
        }

        if Config.showOnlyCachedResults {
            allLinks = allLinks.filter { $0.isCached }
        }

        // Deduplicate links by infoHash or URL
        var seenHashes = Set<String>()
        var seenURLs = Set<String>()
        var uniqueLinks: [AggregatedLink] = []

        for link in allLinks {
            if let hash = link.infoHash, !hash.isEmpty {
                let cleanHash = hash.uppercased()
                if seenHashes.contains(cleanHash) { continue }
                seenHashes.insert(cleanHash)
            } else if let url = link.url {
                let uStr = url.absoluteString
                if seenURLs.contains(uStr) { continue }
                seenURLs.insert(uStr)
            }
            uniqueLinks.append(link)
        }

        // Sort links: RealDebrid cached first, then by score
        uniqueLinks.sort { l1, l2 in
            if l1.isCached != l2.isCached {
                return l1.isCached && !l2.isCached
            }
            return l1.score > l2.score
        }

        if !uniqueLinks.isEmpty {
            uniqueLinks[0].isBestInCategory = true
        }

        return uniqueLinks
    }

    func resolveStreamURLWithFallback(startingLink: AggregatedLink, allLinks: [AggregatedLink]) async throws -> (URL, AggregatedLink) {
        let candidates = [startingLink] + allLinks.filter { $0.id != startingLink.id }

        for candidate in candidates {
            if let directURL = candidate.url {
                return (directURL, candidate)
            }

            if let infoHash = candidate.infoHash, !infoHash.isEmpty {
                do {
                    let resolvedURL = try await rdService.addMagnetAndGetLink(infoHash: infoHash)
                    return (resolvedURL, candidate)
                } catch {
                    print("Failed to resolve candidate infoHash \(infoHash): \(error.localizedDescription)")
                    continue
                }
            }
        }

        throw NSError(domain: "AggregatorService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve stream: All available stream candidates are DMCA blocked or offline on RealDebrid."])
    }
}
