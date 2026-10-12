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

        // Also fetch title if available to empower indexers like Knaben
        let title = try? await tmdbService.fetchTitle(tmdbID: tmdbID, type: type)

        // 1. Fetch streams dynamically from user's installed Stremio add-ons
        var allLinks: [AggregatedLink] = await StremioAddonManager.shared.fetchStreams(
            imdbID: baseIMDb,
            tmdbID: tmdbID,
            type: type,
            title: title,
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
            // For debridless P2P streaming, filter for healthy torrents with seeds >= 1
            let hasSeededLinks = uniqueLinks.contains { ($0.seeds ?? 0) >= 1 }
            if hasSeededLinks {
                uniqueLinks = uniqueLinks.filter { link in
                    if let seeds = link.seeds {
                        return seeds > 0
                    }
                    return link.url?.scheme?.lowercased() == "http" || link.url?.scheme?.lowercased() == "https"
                }
            }
        } else if Config.showOnlyCachedResults {
            let cachedLinks = uniqueLinks.filter { $0.isCached }
            if !cachedLinks.isEmpty {
                uniqueLinks = cachedLinks
            }
        }

        // 5. Sort links:
        uniqueLinks.sort { l1, l2 in
            if Config.isDebridMode {
                // Debrid mode: Cached instant links first, then Quality rank, then Seeds, then Score
                if l1.isCached != l2.isCached {
                    return l1.isCached && !l2.isCached
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
            } else {
                // Debridless mode: List strictly according to seeders first (highest seeders at top)!
                let s1 = l1.seeds ?? 0
                let s2 = l2.seeds ?? 0
                if s1 != s2 {
                    return s1 > s2
                }
                // When seeders are equal, rank by resolution & quality, then score
                let rank1 = self.qualityRank(for: l1)
                let rank2 = self.qualityRank(for: l2)
                if rank1 != rank2 {
                    return rank1 > rank2
                }
                return l1.score > l2.score
            }
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

    private static var activeEngineProcess: Process?

    func resolveStreamURLWithFallback(startingLink: AggregatedLink, allLinks: [AggregatedLink]) async throws -> (URL, AggregatedLink) {
        let candidates = [startingLink] + allLinks.filter { $0.id != startingLink.id }
        let key = Config.realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Direct playable HTTP/HTTPS stream check for requested startingLink
        if let directURL = startingLink.url,
           let scheme = directURL.scheme?.lowercased(),
           (scheme == "http" || scheme == "https") {
            return (directURL, startingLink)
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

        // 3. Local P2P Streaming Engine resolution (127.0.0.1:11470) for debridless playback
        let isEngineReady = await ensureLocalTorrentEngineIsRunning()
        if isEngineReady {
            for candidate in candidates {
                var hashToResolve = candidate.infoHash
                if (hashToResolve == nil || hashToResolve!.isEmpty), let u = candidate.url, u.scheme?.lowercased() == "magnet" {
                    hashToResolve = extractInfoHash(from: u)
                }

                if let infoHash = hashToResolve, !infoHash.isEmpty {
                    let fileIdx = candidate.fileIdx ?? 0
                    if let localStreamURL = URL(string: "http://127.0.0.1:11470/\(infoHash)/\(fileIdx)") {
                        return (localStreamURL, candidate)
                    }
                }
            }
        }

        // 4. External Player direct pass-through (IINA / VLC handle magnet links directly)
        if Config.defaultPlayerSelection != "native" {
            for candidate in candidates {
                if let u = candidate.url {
                    return (u, candidate)
                }
            }
        }

        // 5. If native player requested but local engine unavailable, check if IINA or VLC is installed
        for candidate in candidates {
            if let u = candidate.url, u.scheme?.lowercased() == "magnet" {
                if FileManager.default.fileExists(atPath: "/Applications/IINA.app") || FileManager.default.fileExists(atPath: "/Applications/VLC.app") {
                    return (u, candidate)
                }
            }
        }

        // 6. Direct HTTP/HTTPS stream from any candidate
        for candidate in candidates {
            if let directURL = candidate.url,
               let scheme = directURL.scheme?.lowercased(),
               (scheme == "http" || scheme == "https") {
                return (directURL, candidate)
            }
        }

        throw NSError(
            domain: "AggregatorService",
            code: 404,
            userInfo: [
                NSLocalizedDescriptionKey: "No working stream found. In debridless mode, please connect Real-Debrid in Settings or ensure Stremio / IINA / VLC is available."
            ]
        )
    }

    func isLocalStreamingEngineAlive() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:11470/stats.json") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 0.8
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func ensureLocalTorrentEngineIsRunning() async -> Bool {
        if await isLocalStreamingEngineAlive() {
            return true
        }

        let candidates = [
            (bin: "/Applications/Stremio.app/Contents/MacOS/node", arg: "/Applications/Stremio.app/Contents/Resources/server.js"),
            (bin: "/Applications/StremioService.app/Contents/MacOS/stremio-runtime", arg: "/Applications/StremioService.app/Contents/MacOS/server.js"),
            (bin: "/Applications/StremioService.app/Contents/MacOS/stremio-service", arg: ""),
            (bin: "/Applications/Stremio Enhanced.app/Contents/MacOS/node", arg: "/Applications/Stremio Enhanced.app/Contents/Resources/server.js"),
            (bin: "/usr/local/bin/node", arg: "/Applications/Stremio.app/Contents/Resources/server.js"),
            (bin: "/opt/homebrew/bin/node", arg: "/Applications/Stremio.app/Contents/Resources/server.js")
        ]

        for item in candidates {
            if FileManager.default.fileExists(atPath: item.bin) {
                if !item.arg.isEmpty && !FileManager.default.fileExists(atPath: item.arg) {
                    continue
                }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: item.bin)
                if !item.arg.isEmpty {
                    process.arguments = [item.arg]
                }
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    Self.activeEngineProcess = process
                    break
                } catch {
                    continue
                }
            }
        }

        for _ in 0..<16 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if await isLocalStreamingEngineAlive() {
                return true
            }
        }

        return false
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
