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
        // Prioritize Quality (4K > FHD > HD), Dolby Vision / HDR (DV > HDR10+ > HDR), Remux, then Audio & Seeders
        uniqueLinks.sort { l1, l2 in
            if Config.isDebridMode {
                if l1.isCached != l2.isCached {
                    return l1.isCached && !l2.isCached
                }
            } else {
                let l1IsDirect = (l1.url?.scheme?.lowercased() == "http" || l1.url?.scheme?.lowercased() == "https")
                let l2IsDirect = (l2.url?.scheme?.lowercased() == "http" || l2.url?.scheme?.lowercased() == "https")
                if l1IsDirect != l2IsDirect { return l1IsDirect && !l2IsDirect }
            }

            let rank1 = self.qualityRank(for: l1)
            let rank2 = self.qualityRank(for: l2)
            if rank1 != rank2 {
                return rank1 > rank2
            }

            let s1 = l1.seeds ?? 0
            let s2 = l2.seeds ?? 0
            if s1 != s2 { return s1 > s2 }

            return l1.score > l2.score
        }

        if !uniqueLinks.isEmpty {
            uniqueLinks[0].isBestInCategory = true
        }

        return uniqueLinks
    }

    private func qualityRank(for link: AggregatedLink) -> Int {
        var score = 0
        switch link.quality {
        case "4K": score += 40000
        case "FHD": score += 20000
        case "HD": score += 10000
        default: score += 5000
        }

        if let hdr = link.hdrTag?.uppercased() {
            if hdr.contains("DV") { score += 5000 }
            else if hdr.contains("HDR10+") { score += 4000 }
            else if hdr.contains("HDR") { score += 3000 }
        }

        let upper = link.rawTitle.uppercased()
        if upper.contains("REMUX") { score += 2500 }
        else if upper.contains("BLURAY") || upper.contains("BDRIP") { score += 1500 }
        else if upper.contains("WEB-DL") || upper.contains("WEBDL") { score += 1000 }

        if let audio = link.audioTag?.uppercased() {
            if audio.contains("ATMOS") || audio.contains("TRUEHD") { score += 500 }
            else if audio.contains("5.1") || audio.contains("7.1") { score += 300 }
        }

        return score
    }

    func resolveStreamURLWithFallback(startingLink: AggregatedLink, allLinks: [AggregatedLink]) async throws -> (URL, AggregatedLink) {
        let candidates = [startingLink] + allLinks.filter { $0.id != startingLink.id }
        let key = Config.realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Direct playable HTTP/HTTPS stream check
        for candidate in candidates {
            if let directURL = candidate.url,
               let scheme = directURL.scheme?.lowercased(),
               (scheme == "http" || scheme == "https") {
                return (directURL, candidate)
            }
        }

        // 2. Real-Debrid instant cloud resolution (if configured)
        if !key.isEmpty {
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
        }

        // 3. Local Streaming Engine resolution (127.0.0.1:11470)
        let isEngineRunning = await isLocalStreamingEngineAlive()
        if !isEngineRunning {
            tryLaunchLocalTorrentEngine()
            // Short grace period for daemon initialization
            try? await Task.sleep(nanoseconds: 600_000_000)
        }

        if await isLocalStreamingEngineAlive() {
            for candidate in candidates {
                var hashToResolve = candidate.infoHash
                if (hashToResolve == nil || hashToResolve!.isEmpty), let u = candidate.url, u.scheme?.lowercased() == "magnet" {
                    hashToResolve = extractInfoHash(from: u)
                }

                if let infoHash = hashToResolve, !infoHash.isEmpty {
                    if let localURL = URL(string: "http://127.0.0.1:11470/\(infoHash)/0") {
                        return (localURL, candidate)
                    }
                }
            }
        }

        // 4. Fallback when neither Debrid nor local engine is active
        for candidate in candidates {
            if let magnet = candidate.url, magnet.scheme?.lowercased() == "magnet" {
                return (magnet, candidate)
            }
            if let hash = candidate.infoHash, !hash.isEmpty,
               let constructed = URL(string: "magnet:?xt=urn:btih:\(hash)") {
                return (constructed, candidate)
            }
        }

        throw NSError(
            domain: "AggregatorService",
            code: 404,
            userInfo: [
                NSLocalizedDescriptionKey: "No playable stream found. For instant buffer-free streaming, connect a Debrid account in Settings > Add-ons."
            ]
        )
    }

    private func isLocalStreamingEngineAlive() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:11470/stats.json") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.0
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func tryLaunchLocalTorrentEngine() {
        let candidates = [
            "/Applications/StremioService.app/Contents/MacOS/stremio-service",
            "/Applications/Stremio.app/Contents/MacOS/stremio-runtime"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                try? process.run()
                return
            }
        }
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
