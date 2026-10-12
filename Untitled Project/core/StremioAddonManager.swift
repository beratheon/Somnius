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
            manifestUrl: "https://torrentio.strem.fun/sort=qualitysize|qualityfilter=4k,1080p,720p,other/manifest.json",
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
            self.installedAddons = decoded
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
                    targetManifest = "https://torrentio.strem.fun/realdebrid=\(cleanDebrid)|sort=qualitysize|qualityfilter=4k,1080p,720p,other/manifest.json"
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
            // 1. High-Speed Torrentio Debrid (All 17 providers enabled: YTS, RARBG, 1337x, TPB, EZTV, Rutracker, etc.)
            if isTurbo && !rdParam.isEmpty {
                group.addTask {
                    return await self.queryTorrentio(typeString: typeString, targetID: targetID, rdParam: rdParam)
                }
            }

            // 2. High-Speed Torrentio P2P (All 17 providers uncached/p2p)
            group.addTask {
                return await self.queryTorrentioP2P(typeString: typeString, targetID: targetID)
            }

            // 3. ThePirateBay Direct API (Over 100 torrents, seeders, and hash info)
            if let searchTitle = title, !searchTitle.isEmpty {
                group.addTask {
                    return await self.queryThePirateBay(title: searchTitle, type: type, season: season, episode: episode)
                }
            }

            // 4. User-installed custom add-ons
            for addon in self.installedAddons where addon.isEnabled && addon.supportedResources.contains("stream") {
                // If user installed a Torrentio instance with RD already, let it run
                group.addTask {
                    return await self.queryGenericAddon(addon: addon, typeString: typeString, targetID: targetID)
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

        // If addon transport URL doesn't have RD configured yet and user has RD key, try RD endpoint first
        if !rdParam.isEmpty && !addon.transportUrl.contains("realdebrid=") {
            endpoints.append("\(addon.transportUrl)/\(rdParam)")
        }
        endpoints.append(addon.transportUrl)

        struct StreamItem: Decodable {
            let name: String?
            let title: String?
            let url: String?
            let infoHash: String?
            let fileIdx: Int?
            let sources: [String]?
        }
        struct StreamResponse: Decodable {
            let streams: [StreamItem]?
        }

        for base in endpoints {
            let cleanBase = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let url = URL(string: "\(cleanBase)/stream/\(typeString)/\(targetID).json") else { continue }

            var req = URLRequest(url: url)
            req.timeoutInterval = 4.0
            req.setValue("Stremio/4.4.168 (macOS; x86_64)", forHTTPHeaderField: "User-Agent")

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { continue }

                let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)
                if let streams = decoded.streams, !streams.isEmpty {
                    let items = streams.compactMap { stream -> AggregatedLink? in
                        let titleText = stream.title ?? stream.name ?? "\(addon.name) Stream"
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
    private func queryRawStreamEndpoint(url: URL, source: String? = nil) async -> [AggregatedLink] {
        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
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
        let cleanBase = addon.transportUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: addon.name)
    }

    // MARK: - 1. High-Speed Torrentio Provider (All 17 Providers Enabled)
    private func queryTorrentio(typeString: String, targetID: String, rdParam: String) async -> [AggregatedLink] {
        let allProviders = "providers=yts,eztv,rarbg,1337x,thepiratebay,kickasstorrents,torrentgalaxy,magnetdl,horriblesubs,nyaasi,tokyotosho,anidex,rutor,rutracker,torrent9,mejortorrent,cinecalidad|sort=qualitysize"
        let fullConfig = rdParam.isEmpty ? allProviders : "\(allProviders)|\(rdParam)"
        guard let url = URL(string: "https://torrentio.strem.fun/\(fullConfig)/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: "Torrentio")
    }

    // MARK: - 2. Torrentio P2P Provider
    private func queryTorrentioP2P(typeString: String, targetID: String) async -> [AggregatedLink] {
        let allProviders = "providers=yts,eztv,rarbg,1337x,thepiratebay,kickasstorrents,torrentgalaxy,magnetdl,horriblesubs,nyaasi,tokyotosho,anidex,rutor,rutracker,torrent9,mejortorrent,cinecalidad|sort=qualitysize"
        guard let url = URL(string: "https://torrentio.strem.fun/\(allProviders)/stream/\(typeString)/\(targetID).json") else { return [] }
        return await queryRawStreamEndpoint(url: url, source: "Torrentio")
    }

    // MARK: - 3. ThePirateBay Direct API (Fast & Reliable Fallback)
    private func queryThePirateBay(title: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async -> [AggregatedLink] {
        var query = title
        if type == .series, let s = season, let e = episode {
            query += String(format: " S%02dE%02d", s, e)
        }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://apibay.org/q.php?q=\(encoded)") else { return [] }

        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            struct PBItem: Decodable {
                let name: String
                let info_hash: String
                let size: String
                let seeders: String
            }
            let items = try JSONDecoder().decode([PBItem].self, from: data)
            return items.prefix(80).compactMap { item -> AggregatedLink? in
                guard item.info_hash != "0000000000000000000000000000000000000000" else { return nil }
                let seeds = Int(item.seeders) ?? 0
                let sizeBytes = Int64(item.size) ?? 0
                let gb = Double(sizeBytes) / 1_073_741_824.0
                let sizeStr = gb >= 1.0 ? String(format: "%.2f GB", gb) : String(format: "%.0f MB", Double(sizeBytes) / 1_048_576.0)
                let rawTitle = "\(item.name)\n👤 \(seeds) 💾 \(sizeStr) ⚙️ ThePirateBay"
                return StreamParser.parse(rawTitle: rawTitle, source: "ThePirateBay", url: nil, infoHash: item.info_hash)
            }
        } catch {
            return []
        }
    }
}

