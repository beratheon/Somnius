import Foundation
import Combine

// MARK: - Stremio Addon Models (Protocol v3)

struct ManifestResource: Codable, Equatable {
    let name: String
    let types: [String]?
    let idPrefixes: [String]?

    init(name: String, types: [String]? = nil, idPrefixes: [String]? = nil) {
        self.name = name
        self.types = types
        self.idPrefixes = idPrefixes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringName = try? container.decode(String.self) {
            self.name = stringName
            self.types = nil
            self.idPrefixes = nil
            return
        }

        let dictContainer = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try dictContainer.decode(String.self, forKey: .name)
        self.types = try? dictContainer.decode([String].self, forKey: .types)
        self.idPrefixes = try? dictContainer.decode([String].self, forKey: .idPrefixes)
    }

    private enum CodingKeys: String, CodingKey {
        case name, types, idPrefixes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(types, forKey: .types)
        try container.encodeIfPresent(idPrefixes, forKey: .idPrefixes)
    }
}

struct StremioManifest: Codable, Equatable {
    let id: String
    let name: String
    let version: String
    let description: String?
    let icon: String?
    let background: String?
    let resources: [ManifestResource]?
    let types: [String]?
    let idPrefixes: [String]?
}

struct InstalledAddon: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String
    var manifestUrl: String
    var transportUrl: String
    var isEnabled: Bool
    var iconUrl: String?
    var version: String
    var supportedTypes: [String]
    var supportedResources: [String]

    init(
        id: String,
        name: String,
        description: String,
        manifestUrl: String,
        transportUrl: String,
        isEnabled: Bool = true,
        iconUrl: String? = nil,
        version: String = "1.0.0",
        supportedTypes: [String] = ["movie", "series"],
        supportedResources: [String] = ["stream"]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.manifestUrl = manifestUrl
        self.transportUrl = transportUrl
        self.isEnabled = isEnabled
        self.iconUrl = iconUrl
        self.version = version
        self.supportedTypes = supportedTypes
        self.supportedResources = supportedResources
    }
}

struct CommunityAddonTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let manifestUrl: String
    let icon: String
    let isDebridConfigurable: Bool

    init(id: String, name: String, description: String, manifestUrl: String, icon: String, isDebridConfigurable: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.manifestUrl = manifestUrl
        self.icon = icon
        self.isDebridConfigurable = isDebridConfigurable
    }
}

// MARK: - Stremio Addon Manager
@MainActor
class StremioAddonManager: ObservableObject {
    static let shared = StremioAddonManager()

    private let storageKey = "Somnius_Installed_Stremio_Addons_v1"

    @Published private(set) var installedAddons: [InstalledAddon] = []
    @Published var isInstalling: Bool = false
    @Published var lastErrorMessage: String?

    // Verified community streaming add-on templates
    let communityTemplates: [CommunityAddonTemplate] = [
        CommunityAddonTemplate(
            id: "torrentio",
            name: "Torrentio",
            description: "High-speed multi-source indexer for movies & series with quality sorting",
            manifestUrl: "https://torrentio.strem.fun/sort=qualitysize/manifest.json",
            icon: "bolt.fill",
            isDebridConfigurable: true
        ),
        CommunityAddonTemplate(
            id: "comet",
            name: "Comet (ElfHosted)",
            description: "High-speed multi-indexer search engine with Real-Debrid streaming",
            manifestUrl: "https://comet.elfhosted.com/manifest.json",
            icon: "sparkles",
            isDebridConfigurable: true
        ),
        CommunityAddonTemplate(
            id: "mediafusion",
            name: "MediaFusion (Bitmagnet)",
            description: "Decentralized DHT & bitmagnet indexer for global streaming sources",
            manifestUrl: "https://mediafusion.elfhosted.com/manifest.json",
            icon: "waveform.path.ecg",
            isDebridConfigurable: true
        ),
        CommunityAddonTemplate(
            id: "opensubtitles-v3",
            name: "OpenSubtitles v3",
            description: "Global multilingual subtitle synchronization service",
            manifestUrl: "https://opensubtitles-v3.strem.io/manifest.json",
            icon: "captions.bubble.fill",
            isDebridConfigurable: false
        )
    ]

    private init() {
        loadAddons()
    }

    // MARK: - Persistence
    private func loadAddons() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([InstalledAddon].self, from: data)
            // Sanitize previously cached addons that had the erroneous qualityfilter exclusion
            let badFilter = "qualityfilter=4k,1080p,720p,other"
            var sanitized: [InstalledAddon] = []
            var needsResave = false
            for addon in decoded {
                var cleanAddon = addon
                if cleanAddon.manifestUrl.contains(badFilter) || cleanAddon.transportUrl.contains(badFilter) {
                    cleanAddon.manifestUrl = cleanAddon.manifestUrl
                        .replacingOccurrences(of: "|\(badFilter)", with: "")
                        .replacingOccurrences(of: "\(badFilter)|", with: "")
                        .replacingOccurrences(of: badFilter, with: "")
                    cleanAddon.transportUrl = cleanAddon.transportUrl
                        .replacingOccurrences(of: "|\(badFilter)", with: "")
                        .replacingOccurrences(of: "\(badFilter)|", with: "")
                        .replacingOccurrences(of: badFilter, with: "")
                    needsResave = true
                }
                sanitized.append(cleanAddon)
            }
            self.installedAddons = sanitized
            if needsResave {
                saveAddons()
            }
        } catch {
            print("Failed to decode installed addons: \(error.localizedDescription)")
        }
    }

    private func saveAddons() {
        do {
            let data = try JSONEncoder().encode(installedAddons)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to encode installed addons: \(error.localizedDescription)")
        }
    }

    // MARK: - 1-Click Community Streaming Pack
    public func installCommunityStreamingPack(debridKey: String? = nil) async {
        isInstalling = true
        defer { isInstalling = false }

        let cleanDebrid = debridKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanDebrid.isEmpty {
            Config.realDebridApiKey = cleanDebrid
            Config.streamingSetupMode = "debrid"
        }

        for template in communityTemplates {
            var targetManifest = template.manifestUrl

            if !cleanDebrid.isEmpty && template.isDebridConfigurable {
                if template.id == "torrentio" {
                    targetManifest = "https://torrentio.strem.fun/realdebrid=\(cleanDebrid)|sort=qualitysize/manifest.json"
                } else if template.id == "knightcrawler" {
                    targetManifest = "https://knightcrawler.elfhosted.com/realdebrid=\(cleanDebrid)|sort=qualitysize/manifest.json"
                }
            }

            // Attempt installation from manifest; if network fails, add template fallback
            do {
                _ = try await installAddon(rawUrl: targetManifest)
            } catch {
                let cleanBase = targetManifest.replacingOccurrences(of: "/manifest.json", with: "")
                let fallbackAddon = InstalledAddon(
                    id: template.id,
                    name: template.name,
                    description: template.description,
                    manifestUrl: targetManifest,
                    transportUrl: cleanBase,
                    isEnabled: true,
                    iconUrl: nil,
                    version: "1.0.0",
                    supportedTypes: ["movie", "series"],
                    supportedResources: ["stream"]
                )
                if let idx = installedAddons.firstIndex(where: { $0.id == fallbackAddon.id }) {
                    installedAddons[idx] = fallbackAddon
                } else {
                    installedAddons.append(fallbackAddon)
                }
                saveAddons()
            }
        }
    }

    public func updateDebridForInstalledAddons(debridKey: String) async {
        let clean = debridKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        await installCommunityStreamingPack(debridKey: clean)
    }

    // MARK: - Install / Uninstall
    func installAddon(rawUrl: String) async throws -> InstalledAddon {
        isInstalling = true
        defer { isInstalling = false }

        var urlString = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.hasPrefix("stremio://") {
            urlString = urlString.replacingOccurrences(of: "stremio://", with: "https://")
        }
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }
        if !urlString.hasSuffix("/manifest.json") {
            if urlString.hasSuffix("/") {
                urlString += "manifest.json"
            } else {
                urlString += "/manifest.json"
            }
        }

        guard let manifestURL = URL(string: urlString) else {
            throw NSError(domain: "StremioAddonManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Addon URL."])
        }

        var req = URLRequest(url: manifestURL)
        req.timeoutInterval = 6.0
        req.setValue("Stremio/4.4.168 (macOS; x86_64)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "StremioAddonManager", code: 502, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to addon server."])
        }

        let manifest = try JSONDecoder().decode(StremioManifest.self, from: data)

        let transportUrl = manifestURL.deletingLastPathComponent().absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let supportedResources: [String] = manifest.resources?.compactMap { $0.name } ?? ["stream"]
        let supportedTypes: [String] = manifest.types ?? ["movie", "series"]

        let newAddon = InstalledAddon(
            id: manifest.id,
            name: manifest.name,
            description: manifest.description ?? "Community Add-on",
            manifestUrl: urlString,
            transportUrl: transportUrl,
            isEnabled: true,
            iconUrl: manifest.icon,
            version: manifest.version,
            supportedTypes: supportedTypes,
            supportedResources: supportedResources
        )

        // Replace if already installed, otherwise append
        if let idx = installedAddons.firstIndex(where: { $0.id == newAddon.id || $0.manifestUrl == newAddon.manifestUrl }) {
            installedAddons[idx] = newAddon
        } else {
            installedAddons.append(newAddon)
        }

        saveAddons()
        return newAddon
    }

    func removeAddon(id: String) {
        installedAddons.removeAll { $0.id == id }
        saveAddons()
    }

    func removeAllAddons() {
        installedAddons.removeAll()
        saveAddons()
    }

    func toggleAddon(id: String) {
        if let idx = installedAddons.firstIndex(where: { $0.id == id }) {
            installedAddons[idx].isEnabled.toggle()
            saveAddons()
        }
    }

    // MARK: - Stream Fetching Protocol
    func fetchStreams(
        imdbID: String,
        tmdbID: String,
        type: MediaItem.MediaType,
        title: String? = nil,
        season: Int?,
        episode: Int?,
        onBatch: (([AggregatedLink]) -> Void)? = nil
    ) async -> [AggregatedLink] {
        let typeString = (type == .series) ? "series" : "movie"
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        var allLinks: [AggregatedLink] = []
        let isTurbo = Config.isDebridMode
        let rdKey = Config.realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let rdParam = !rdKey.isEmpty ? "realdebrid=\(rdKey)" : ""

        await withTaskGroup(of: [AggregatedLink].self) { group in
            var handledHosts = Set<String>()

            // 1. TorrentsDB Multi-Indexer (20+ providers: 1337x, YTS, EZTV, RARBG, Knaben, TPB, LimeTorrent, TorrentCSV, Sk-CzTorrent, Nyaa, Rutor, Rutracker)
            handledHosts.insert("torrentsdb.com")
            group.addTask {
                return await self.queryTorrentsDB(typeString: typeString, targetID: targetID)
            }

            // 2. ThePirateBay / ApiBay Direct Indexer (by IMDb ID & Title)
            group.addTask {
                return await self.queryThePirateBay(imdbID: imdbID, title: title, type: type, season: season, episode: episode)
            }

            // 3. Direct YTS (Movies) or EZTV (Series) Fast API
            if type == .movie {
                group.addTask {
                    return await self.queryYTS(imdbID: imdbID)
                }
            } else {
                group.addTask {
                    return await self.queryEZTV(imdbID: imdbID, season: season, episode: episode)
                }
            }

            // 4. Peerflix Stremio Indexer
            handledHosts.insert("peerflix.mov")
            group.addTask {
                return await self.queryPeerflix(typeString: typeString, targetID: targetID)
            }

            // 5. High-Speed Torrentio & Comet Scrapers
            if isTurbo && !rdParam.isEmpty {
                handledHosts.insert("torrentio.strem.fun")
                group.addTask {
                    return await self.queryTorrentio(typeString: typeString, targetID: targetID, rdParam: rdParam)
                }

                handledHosts.insert("comet.elfhosted.com")
                group.addTask {
                    return await self.queryComet(typeString: typeString, targetID: targetID, rdKey: rdKey)
                }
            } else {
                handledHosts.insert("torrentio.strem.fun")
                group.addTask {
                    return await self.queryTorrentioP2P(typeString: typeString, targetID: targetID)
                }
            }

            // 6. User-installed custom add-ons (MediaFusion, KnightCrawler, Jackettio, etc.)
            for addon in self.installedAddons where addon.isEnabled && addon.supportedResources.contains("stream") {
                let lowerURL = addon.transportUrl.lowercased()
                let alreadyQueried = handledHosts.contains { lowerURL.contains($0) }
                if alreadyQueried {
                    continue
                }
                group.addTask {
                    return await self.queryAddonStreams(addon: addon, typeString: typeString, targetID: targetID, rdParam: isTurbo ? rdParam : "")
                }
            }

            for await links in group {
                if !links.isEmpty {
                    allLinks.append(contentsOf: links)
                    onBatch?(links)
                }
            }
        }

        return allLinks
    }

    private func queryAddonStreams(addon: InstalledAddon, typeString: String, targetID: String, rdParam: String) async -> [AggregatedLink] {
        var endpoints: [String] = []

        if !rdParam.isEmpty && !addon.transportUrl.contains("realdebrid=") {
            endpoints.append("\(addon.transportUrl)/\(rdParam)")
        }
        endpoints.append(addon.transportUrl)

        struct StreamItem: Decodable {
            let name: String?
            let title: String?
            let description: String?
            let url: String?
            let infoHash: String?
            let fileIdx: Int?
            let sources: [String]?
        }
        struct StreamResponse: Decodable {
            let streams: [StreamItem]?
        }

        for base in endpoints {
            let cleanBase = base.trimmingCharacters(in: CharacterSet(charactersIn: "/")).replacingOccurrences(of: "|", with: "%7C")
            guard let url = URL(string: "\(cleanBase)/stream/\(typeString)/\(targetID).json") else { continue }

            var req = URLRequest(url: url)
            req.timeoutInterval = 5.0
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { continue }

                let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)
                if let streams = decoded.streams, !streams.isEmpty {
                    let items = streams.compactMap { stream -> AggregatedLink? in
                        let titleText = stream.title ?? stream.description ?? stream.name ?? "\(addon.name) Stream"
                        let nameText = stream.name ?? addon.name
                        let combinedText = "\(nameText) \n \(titleText)"
                        let streamURL = stream.url.flatMap { URL(string: $0) }
                        let customTrackers = stream.sources?.compactMap { src -> String? in
                            if src.hasPrefix("tracker:") {
                                return String(src.dropFirst("tracker:".count))
                            }
                            return nil
                        }

                        return StreamParser.parse(rawTitle: combinedText, source: addon.name, url: streamURL, infoHash: stream.infoHash, fileIdx: stream.fileIdx, trackers: customTrackers)
                    }
                    if !items.isEmpty {
                        return items
                    }
                }
            } catch {
                continue
            }
        }

        return []
    }

    // MARK: - Raw Stremio Endpoint Scraper
    private func queryRawStreamEndpoint(url: URL, source: String? = nil, timeout: TimeInterval = 5.5) async -> [AggregatedLink] {
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        struct StreamItem: Decodable {
            let name: String?
            let title: String?
            let description: String?
            let url: String?
            let infoHash: String?
            let fileIdx: Int?
            let sources: [String]?
        }
        struct StreamResponse: Decodable {
            let streams: [StreamItem]?
        }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }

            let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)
            guard let streams = decoded.streams, !streams.isEmpty else { return [] }

            return streams.compactMap { stream -> AggregatedLink? in
                let titleText = stream.title ?? stream.name ?? "Community Stream"
                let descText = stream.description ?? ""
                let nameText = stream.name ?? "Community Stream"
                let combinedText = "\(nameText) \n \(titleText) \n \(descText)"

                // Filter out provider notice/error banner streams
                let lower = combinedText.lowercased()
                if lower.contains("obsolete configuration") || lower.contains("please re-configure") || (lower.contains("error") && stream.url == nil && stream.infoHash == nil) {
                    return nil
                }

                let streamURL = stream.url.flatMap { URL(string: $0) }
                let finalSource = source ?? nameText
                let customTrackers = stream.sources?.compactMap { src -> String? in
                    if src.hasPrefix("tracker:") {
                        return String(src.dropFirst("tracker:".count))
                    }
                    return nil
                }

                return StreamParser.parse(rawTitle: combinedText, source: finalSource, url: streamURL, infoHash: stream.infoHash, fileIdx: stream.fileIdx, trackers: customTrackers)
            }
        } catch {
            return []
        }
    }

    private func queryGenericAddon(addon: InstalledAddon, typeString: String, targetID: String) async -> [AggregatedLink] {
        let cleanBase = addon.transportUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")).replacingOccurrences(of: "|", with: "%7C")
        guard let url = URL(string: "\(cleanBase)/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: addon.name)
    }

    // MARK: - 1. TorrentsDB Multi-Indexer Provider (20+ Indexers)
    private func queryTorrentsDB(typeString: String, targetID: String) async -> [AggregatedLink] {
        guard let url = URL(string: "https://torrentsdb.com/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: "TorrentsDB", timeout: 5.5)
    }

    // MARK: - 2. Peerflix Stremio Provider
    private func queryPeerflix(typeString: String, targetID: String) async -> [AggregatedLink] {
        guard let url = URL(string: "https://peerflix.mov/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: "Peerflix", timeout: 5.0)
    }

    // MARK: - 3. ThePirateBay / ApiBay Direct API (IMDb ID & Title Search)
    private func queryThePirateBay(imdbID: String, title: String?, type: MediaItem.MediaType, season: Int?, episode: Int?) async -> [AggregatedLink] {
        struct PBItem: Decodable {
            let name: String
            let info_hash: String
            let size: String
            let seeders: String
            let category: String?
            let imdb: String?
        }

        var queries: [String] = []
        if type == .movie {
            if imdbID.hasPrefix("tt") {
                queries.append(imdbID)
            }
            if let t = title, !t.isEmpty {
                queries.append(t)
            }
        } else {
            let s = season ?? 1
            let e = episode ?? 1
            if let t = title, !t.isEmpty {
                queries.append(String(format: "%@ S%02dE%02d", t, s, e))
            } else if imdbID.hasPrefix("tt") {
                queries.append(imdbID)
            }
        }

        var results: [AggregatedLink] = []
        var seenHashes = Set<String>()

        for q in queries {
            guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://apibay.org/q.php?q=\(encoded)") else { continue }

            var req = URLRequest(url: url)
            req.timeoutInterval = 4.5
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let items = try? JSONDecoder().decode([PBItem].self, from: data) else { continue }

                for item in items.prefix(60) {
                    let hash = item.info_hash.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard hash.count == 40, hash != "0000000000000000000000000000000000000000" else { continue }

                    // Only accept Video categories (200..299) or items explicitly matching the IMDb ID
                    if let cat = item.category, !cat.isEmpty, !cat.hasPrefix("2") {
                        continue
                    }
                    // If item specifies an IMDb ID and it doesn't match the requested IMDb ID, skip it
                    if let itemImdb = item.imdb, !itemImdb.isEmpty, itemImdb.hasPrefix("tt"), imdbID.hasPrefix("tt"), itemImdb != imdbID {
                        continue
                    }

                    // For series episodes, ensure SxxExx or Sxx matches
                    if type == .series, let s = season, let e = episode {
                        let seTag = String(format: "S%02dE%02d", s, e)
                        let seAlt = String(format: "%dx%02d", s, e)
                        let sPack = String(format: "S%02d", s)
                        let upperName = item.name.uppercased()
                        if !upperName.contains(seTag) && !upperName.contains(seAlt.uppercased()) && !upperName.contains(sPack) {
                            continue
                        }
                    }

                    let upperHash = hash.uppercased()
                    if seenHashes.contains(upperHash) { continue }
                    seenHashes.insert(upperHash)

                    let seeds = Int(item.seeders) ?? 0
                    let sizeBytes = Int64(item.size) ?? 0
                    let gb = Double(sizeBytes) / 1_073_741_824.0
                    let sizeStr = gb >= 1.0 ? String(format: "%.2f GB", gb) : String(format: "%.0f MB", Double(sizeBytes) / 1_048_576.0)
                    let rawTitle = "\(item.name)\n👤 \(seeds) 💾 \(sizeStr) ⚙️ ThePirateBay"
                    if let parsed = StreamParser.parse(rawTitle: rawTitle, source: "ThePirateBay", url: nil, infoHash: hash.lowercased()) {
                        results.append(parsed)
                    }
                }

                if !results.isEmpty && q == imdbID {
                    break
                }
            } catch {
                continue
            }
        }

        return results
    }

    // MARK: - 4. YTS Direct Movie API
    private func queryYTS(imdbID: String) async -> [AggregatedLink] {
        guard imdbID.hasPrefix("tt"),
              let url = URL(string: "https://movies-api.accel.li/api/v2/list_movies.json?query_term=\(imdbID)") else { return [] }

        var req = URLRequest(url: url)
        req.timeoutInterval = 4.5
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        struct YTSTorrent: Decodable {
            let hash: String?
            let quality: String?
            let type: String?
            let seeds: Int?
            let size: String?
            let video_codec: String?
            let bit_depth: String?
            let audio_channels: String?
        }
        struct YTSMovie: Decodable {
            let title_long: String?
            let title: String?
            let imdb_code: String?
            let torrents: [YTSTorrent]?
        }
        struct YTSData: Decodable {
            let movies: [YTSMovie]?
        }
        struct YTSResponse: Decodable {
            let data: YTSData?
        }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let decoded = try? JSONDecoder().decode(YTSResponse.self, from: data),
                  let movies = decoded.data?.movies else { return [] }

            var results: [AggregatedLink] = []
            for movie in movies {
                if let code = movie.imdb_code, code != imdbID { continue }
                let mTitle = movie.title_long ?? movie.title ?? "Movie"
                for t in movie.torrents ?? [] {
                    guard let hash = t.hash, hash.count == 40 else { continue }
                    let q = t.quality ?? "1080p"
                    let tp = (t.type ?? "web").uppercased()
                    let codec = (t.video_codec ?? "x264").uppercased()
                    let bit = (t.bit_depth == "10") ? "10bit HDR" : ""
                    let ch = t.audio_channels ?? "2.0"
                    let seeds = t.seeds ?? 0
                    let sz = t.size ?? ""
                    let rawTitle = "\(mTitle) \(q) \(tp) \(codec) \(bit) \(ch) - YTS\n👤 \(seeds) 💾 \(sz) ⚙️ YTS"
                    if let parsed = StreamParser.parse(rawTitle: rawTitle, source: "YTS", url: nil, infoHash: hash.lowercased()) {
                        results.append(parsed)
                    }
                }
            }
            return results
        } catch {
            return []
        }
    }

    // MARK: - 5. EZTV Direct Series API
    private func queryEZTV(imdbID: String, season: Int?, episode: Int?) async -> [AggregatedLink] {
        let numericImdb = imdbID.replacingOccurrences(of: "tt", with: "")
        guard !numericImdb.isEmpty, Int(numericImdb) != nil,
              let url = URL(string: "https://eztvx.to/api/get-torrents?imdb_id=\(numericImdb)&limit=100") else { return [] }

        var req = URLRequest(url: url)
        req.timeoutInterval = 4.5
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        struct EZTVTorrent: Decodable {
            let hash: String?
            let filename: String?
            let title: String?
            let season: String?
            let episode: String?
            let seeds: Int?
            let size_bytes: String?
        }
        struct EZTVResponse: Decodable {
            let torrents: [EZTVTorrent]?
        }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let decoded = try? JSONDecoder().decode(EZTVResponse.self, from: data),
                  let torrents = decoded.torrents else { return [] }

            let targetS = season ?? 1
            let targetE = episode ?? 1

            return torrents.compactMap { t -> AggregatedLink? in
                guard let hash = t.hash, hash.count == 40 else { return nil }
                let sNum = Int(t.season ?? "") ?? 0
                let eNum = Int(t.episode ?? "") ?? 0
                let name = t.filename ?? t.title ?? "Episode"
                let seTag = String(format: "S%02dE%02d", targetS, targetE)
                if (sNum != targetS || eNum != targetE) && !name.uppercased().contains(seTag) {
                    return nil
                }
                let seeds = t.seeds ?? 0
                let bytes = Int64(t.size_bytes ?? "") ?? 0
                let gb = Double(bytes) / 1_073_741_824.0
                let sizeStr = gb >= 1.0 ? String(format: "%.2f GB", gb) : String(format: "%.0f MB", Double(bytes) / 1_048_576.0)
                let rawTitle = "\(name)\n👤 \(seeds) 💾 \(sizeStr) ⚙️ EZTV"
                return StreamParser.parse(rawTitle: rawTitle, source: "EZTV", url: nil, infoHash: hash.lowercased())
            }
        } catch {
            return []
        }
    }

    // MARK: - 6. High-Speed Torrentio Provider (All 17 Providers Enabled)
    private func queryTorrentio(typeString: String, targetID: String, rdParam: String) async -> [AggregatedLink] {
        let allProviders = "providers=yts,eztv,rarbg,1337x,thepiratebay,kickasstorrents,torrentgalaxy,magnetdl,horriblesubs,nyaasi,tokyotosho,anidex,rutor,rutracker,torrent9,mejortorrent,cinecalidad%7Csort=qualitysize"
        let fullConfig = rdParam.isEmpty ? allProviders : "\(allProviders)%7C\(rdParam)"
        guard let url = URL(string: "https://torrentio.strem.fun/\(fullConfig)/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: "Torrentio")
    }

    // MARK: - 7. Torrentio P2P Provider
    private func queryTorrentioP2P(typeString: String, targetID: String) async -> [AggregatedLink] {
        let allProviders = "providers=yts,eztv,rarbg,1337x,thepiratebay,kickasstorrents,torrentgalaxy,magnetdl,horriblesubs,nyaasi,tokyotosho,anidex,rutor,rutracker,torrent9,mejortorrent,cinecalidad%7Csort=qualitysize"
        guard let url = URL(string: "https://torrentio.strem.fun/\(allProviders)/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: "Torrentio")
    }

    // MARK: - 8. Comet Debrid Provider (ElfHosted)
    private func queryComet(typeString: String, targetID: String, rdKey: String) async -> [AggregatedLink] {
        guard !rdKey.isEmpty else { return [] }

        let cometConfig: [String: Any] = [
            "maxResultsPerResolution": 0,
            "maxSize": 0,
            "cachedOnly": false,
            "sortCachedUncachedTogether": false,
            "removeTrash": false,
            "resultFormat": ["all"],
            "debridServices": [
                ["service": "realdebrid", "apiKey": rdKey]
            ],
            "enableTorrent": true,
            "deduplicateStreams": false,
            "scrapeDebridAccountTorrents": false,
            "debridStreamProxyPassword": "",
            "languages": [
                "required": [String](),
                "allowed": [String](),
                "exclude": [String](),
                "preferred": [String]()
            ],
            "resolutions": [String: Bool](),
            "options": [
                "remove_ranks_under": -10000000000,
                "allow_english_in_languages": true,
                "remove_unknown_languages": false
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: cometConfig),
              let b64 = jsonData.base64EncodedString() as String? else {
            return []
        }

        let base = "https://comet.elfhosted.com/\(b64)"
        guard let url = URL(string: "\(base)/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: "Comet", timeout: 6.5)
    }
}

