import Foundation

// MARK: - Generic Stream Provider Protocol
protocol StreamProvider {
    var name: String { get }
    func fetchLinks(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async throws -> [AggregatedLink]
}

// MARK: - Master Stremio-Agnostic Aggregator Service
class AggregatorService {
    private let rdService = RealDebridService()
    private let tmdbService = TMDBService()

    init() {}

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

        // 1. Fetch streams dynamically from user's installed Stremio add-ons
        var allLinks: [AggregatedLink] = await StremioAddonManager.shared.fetchStreams(
            imdbID: baseIMDb,
            tmdbID: tmdbID,
            type: type,
            season: season,
            episode: episode
        )

        // 2. RealDebrid Instant Availability Cache Verification
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

        // 3. Deduplicate links by infoHash or URL
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

        // 4. Filter based on setup mode: Classic vs Debrid
        if !Config.isDebridMode {
            // In Classic mode (without Debrid), only bring fast, verified, or highly seeded sources
            uniqueLinks = uniqueLinks.filter { link in
                if let url = link.url, let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https") {
                    return true
                }
                if link.isCached {
                    return true
                }
                if let seeds = link.seeds {
                    return seeds >= 10
                }
                return false
            }
        } else if Config.showOnlyCachedResults {
            uniqueLinks = uniqueLinks.filter { $0.isCached }
        }

        // 5. Sort links:
        // In Debrid mode: RealDebrid cached first, then by score
        // In Classic mode: Direct HTTP/HTTPS first, then high seeders, then by score
        uniqueLinks.sort { l1, l2 in
            if !Config.isDebridMode {
                let l1IsDirect = (l1.url?.scheme?.lowercased() == "http" || l1.url?.scheme?.lowercased() == "https")
                let l2IsDirect = (l2.url?.scheme?.lowercased() == "http" || l2.url?.scheme?.lowercased() == "https")
                if l1IsDirect != l2IsDirect { return l1IsDirect && !l2IsDirect }
                let s1 = l1.seeds ?? 0
                let s2 = l2.seeds ?? 0
                if s1 != s2 { return s1 > s2 }
            } else {
                if l1.isCached != l2.isCached {
                    return l1.isCached && !l2.isCached
                }
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
        let key = Config.realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. First check if any candidate is already a playable HTTP/HTTPS stream
        for candidate in candidates {
            if let directURL = candidate.url,
               let scheme = directURL.scheme?.lowercased(),
               (scheme == "http" || scheme == "https") {
                return (directURL, candidate)
            }
        }

        // 2. All remaining candidates are torrents (magnet / infoHash). Real-Debrid is required to convert them to HTTP streams.
        guard !key.isEmpty else {
            throw NSError(
                domain: "AggregatorService",
                code: 401,
                userInfo: [
                    NSLocalizedDescriptionKey: "Real-Debrid API Key is required to resolve torrent streams into video. Please enter your Real-Debrid API Key in Profile > Settings to stream 4K/HDR content."
                ]
            )
        }

        for candidate in candidates {
            var hashToResolve = candidate.infoHash
            if (hashToResolve == nil || hashToResolve!.isEmpty), let u = candidate.url, u.scheme?.lowercased() == "magnet" {
                hashToResolve = extractInfoHash(from: u)
            }

            if let infoHash = hashToResolve, !infoHash.isEmpty {
                do {
                    let resolvedURL = try await rdService.addMagnetAndGetLink(infoHash: infoHash)
                    return (resolvedURL, candidate)
                } catch {
                    print("Failed to resolve candidate infoHash \(infoHash): \(error.localizedDescription)")
                    continue
                }
            }
        }

        throw NSError(
            domain: "AggregatorService",
            code: 404,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed to resolve stream: All available stream candidates are offline or blocked on Real-Debrid."
            ]
        )
    }

    private func extractInfoHash(from url: URL) -> String? {
        let str = url.absoluteString
        guard let range = str.range(of: "urn:btih:", options: .caseInsensitive) else { return nil }
        let sub = str[range.upperBound...]
        let endIdx = sub.firstIndex(where: { $0 == "&" || $0 == "/" }) ?? sub.endIndex
        let hash = String(sub[..<endIdx])
        return hash.isEmpty ? nil : hash
    }
}
