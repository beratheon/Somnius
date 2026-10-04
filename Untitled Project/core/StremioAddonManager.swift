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

    // Popular community templates available for 1-click user installation
    let communityTemplates: [CommunityAddonTemplate] = [
        CommunityAddonTemplate(
            id: "community.torrentio",
            name: "Torrentio",
            description: "High-speed torrent stream provider with RealDebrid multi-hoster support.",
            manifestUrl: "https://torrentio.strem.fun/manifest.json",
            icon: "bolt.horizontal.fill",
            isDebridConfigurable: true
        ),
        CommunityAddonTemplate(
            id: "community.comet",
            name: "Comet",
            description: "Fast Prowlarr/Zilean stream resolver with instant debrid cache checking.",
            manifestUrl: "https://comet.elfhosted.com/manifest.json",
            icon: "sparkles",
            isDebridConfigurable: true
        ),
        CommunityAddonTemplate(
            id: "community.mediafusion",
            name: "MediaFusion",
            description: "Multi-language and global torrent scraper supporting movies, series & sports.",
            manifestUrl: "https://mediafusion.elfhosted.com/manifest.json",
            icon: "film.stack.fill",
            isDebridConfigurable: true
        ),
        CommunityAddonTemplate(
            id: "community.knightcrawler",
            name: "Knightcrawler",
            description: "Torrentio alternative powered by ElfHosted indexers and cached debrid.",
            manifestUrl: "https://knightcrawler.elfhosted.com/manifest.json",
            icon: "shield.lefthalf.filled",
            isDebridConfigurable: true
        ),
        CommunityAddonTemplate(
            id: "community.cyberflix",
            name: "Cyberflix Catalog",
            description: "Catalog and stream bridge for streaming platforms and popular media.",
            manifestUrl: "https://cyberflix.elfhosted.com/manifest.json",
            icon: "globe.americas.fill",
            isDebridConfigurable: true
        )
    ]

    private init() {
        loadAddons()
        // If first launch, seed default templates locally for instant out-of-the-box experience
        if installedAddons.isEmpty {
            seedDefaultAddons()
        }
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

    private func seedDefaultAddons() {
        for template in communityTemplates.prefix(3) {
            let cleanBase = template.manifestUrl.replacingOccurrences(of: "/manifest.json", with: "")
            let addon = InstalledAddon(
                id: template.id,
                name: template.name,
                description: template.description,
                manifestUrl: template.manifestUrl,
                transportUrl: cleanBase,
                isEnabled: true,
                iconUrl: nil,
                version: "1.0.0",
                supportedTypes: ["movie", "series"],
                supportedResources: ["stream"]
            )
            installedAddons.append(addon)
        }
        saveAddons()
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
            description: manifest.description ?? "Community Stremio Addon",
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

    func toggleAddon(id: String) {
        if let idx = installedAddons.firstIndex(where: { $0.id == id }) {
            installedAddons[idx].isEnabled.toggle()
            saveAddons()
        }
    }

    // MARK: - Stream Fetching Protocol
    func fetchStreams(imdbID: String, tmdbID: String, type: MediaItem.MediaType, season: Int?, episode: Int?) async -> [AggregatedLink] {
        let typeString = (type == .series) ? "series" : "movie"
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        let activeStreamAddons = installedAddons.filter { addon in
            addon.isEnabled &&
            addon.supportedResources.contains("stream") &&
            addon.supportedTypes.contains(typeString)
        }

        guard !activeStreamAddons.isEmpty else { return [] }

        let rdKey = Config.realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let rdParam = !rdKey.isEmpty ? "realdebrid=\(rdKey)" : ""

        var allLinks: [AggregatedLink] = []

        await withTaskGroup(of: [AggregatedLink].self) { group in
            for addon in activeStreamAddons {
                group.addTask {
                    return await self.queryAddonStreams(addon: addon, typeString: typeString, targetID: targetID, rdParam: rdParam)
                }
            }

            for await links in group {
                allLinks.append(contentsOf: links)
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

                        return StreamParser.parse(rawTitle: combinedText, source: addon.name, url: streamURL, infoHash: stream.infoHash)
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
}
