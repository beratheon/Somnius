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
    private static let subtitleColorKey = "Subtitle_Color_Preference"
    private static let subtitleSizeKey = "Subtitle_Size_Preference"

    static var autoPlayMaxGbSize: Double {
        get { 
            if UserDefaults.standard.object(forKey: "Auto_Play_Max_GB") == nil { return 8.0 }
            return UserDefaults.standard.double(forKey: "Auto_Play_Max_GB")
        }
        set { UserDefaults.standard.set(newValue, forKey: "Auto_Play_Max_GB") }
    }
    
    static var autoPlayPreferredQuality: String {
        get { UserDefaults.standard.string(forKey: "Auto_Play_Quality") ?? "1080p" }
        set { UserDefaults.standard.set(newValue, forKey: "Auto_Play_Quality") }
    }

    static var autoPlayPreferHDR: Bool {
        get {
            if UserDefaults.standard.object(forKey: "Auto_Play_Prefer_HDR") == nil { return true }
            return UserDefaults.standard.bool(forKey: "Auto_Play_Prefer_HDR")
        }
        set { UserDefaults.standard.set(newValue, forKey: "Auto_Play_Prefer_HDR") }
    }

    static var autoPlayPreferDolbyVision: Bool {
        get {
            if UserDefaults.standard.object(forKey: "Auto_Play_Prefer_DV") == nil { return true }
            return UserDefaults.standard.bool(forKey: "Auto_Play_Prefer_DV")
        }
        set { UserDefaults.standard.set(newValue, forKey: "Auto_Play_Prefer_DV") }
    }

    static var autoPlayPreferSurround: Bool {
        get {
            if UserDefaults.standard.object(forKey: "Auto_Play_Prefer_Surround") == nil { return true }
            return UserDefaults.standard.bool(forKey: "Auto_Play_Prefer_Surround")
        }
        set { UserDefaults.standard.set(newValue, forKey: "Auto_Play_Prefer_Surround") }
    }

    static var autoPlayCachedOnly: Bool {
        get {
            if UserDefaults.standard.object(forKey: "Auto_Play_Cached_Only") == nil { return true }
            return UserDefaults.standard.bool(forKey: "Auto_Play_Cached_Only")
        }
        set { UserDefaults.standard.set(newValue, forKey: "Auto_Play_Cached_Only") }
    }

    static var autoPlaySkipShortClips: Bool {
        get {
            if UserDefaults.standard.object(forKey: "Auto_Play_Skip_Short_Clips") == nil { return true }
            return UserDefaults.standard.bool(forKey: "Auto_Play_Skip_Short_Clips")
        }
        set { UserDefaults.standard.set(newValue, forKey: "Auto_Play_Skip_Short_Clips") }
    }

    private static let autoPlayDirectlyKey = "Auto_Play_Directly_Without_Picker"
    static var autoPlayDirectly: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoPlayDirectlyKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: autoPlayDirectlyKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoPlayDirectlyKey) }
    }

    private static let skipIntroModeKey = "TheIntroDB_Skip_Intro_Mode"
    static var skipIntroMode: String {
        get { UserDefaults.standard.string(forKey: skipIntroModeKey) ?? "button" }
        set { UserDefaults.standard.set(newValue, forKey: skipIntroModeKey) }
    }


    static var realDebridApiKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: apiKeyKey) }
    }

    static var realDebridAPIKey: String {
        get { realDebridApiKey }
        set { realDebridApiKey = newValue }
    }

    // Real-Debrid Affiliate & Referral Program Configuration
    private static let affiliateUrlKey = "Somnius_RealDebrid_Affiliate_URL"
    private static let affiliateIdKey = "Somnius_RealDebrid_Affiliate_ID"
    public static let defaultAffiliateId = "10141263"

    static var realDebridAffiliateId: String {
        get {
            let saved = UserDefaults.standard.string(forKey: affiliateIdKey) ?? ""
            return saved.isEmpty ? defaultAffiliateId : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: affiliateIdKey) }
    }

    static var realDebridAffiliateUrlString: String {
        get { UserDefaults.standard.string(forKey: affiliateUrlKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: affiliateUrlKey) }
    }

    static var realDebridAffiliateUrl: URL {
        let customUrl = realDebridAffiliateUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customUrl.isEmpty, let url = URL(string: customUrl) {
            return url
        }
        let cleanId = realDebridAffiliateId.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeId = cleanId.isEmpty ? defaultAffiliateId : cleanId
        return URL(string: "https://real-debrid.com/?id=\(activeId)") ?? URL(string: "https://real-debrid.com/?id=10141263")!
    }

    static let realDebridApiTokenUrl = URL(string: "https://real-debrid.com/apitoken")!

    private static let tvdbApiKeyKey = "TVDB_API_Key"
    static let defaultTVDBApiKey = "619b8175-6279-4345-afe1-67ffe08e2acf"

    static var tvdbApiKey: String {
        get {
            let key = UserDefaults.standard.string(forKey: tvdbApiKeyKey) ?? ""
            return key.isEmpty ? defaultTVDBApiKey : key
        }
        set { UserDefaults.standard.set(newValue, forKey: tvdbApiKeyKey) }
    }

    static var preferredSubtitleLanguage: String {
        get { UserDefaults.standard.string(forKey: subtitleLangKey) ?? "en" }
        set { UserDefaults.standard.set(newValue, forKey: subtitleLangKey) }
    }

    static var preferredStreamQuality: String {
        get { UserDefaults.standard.string(forKey: preferredQualityKey) ?? "4k" }
        set { UserDefaults.standard.set(newValue, forKey: preferredQualityKey) }
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

    private static let subtitleVerticalPosKey = "Subtitle_Vertical_Offset_Pt"
    static var subtitleVerticalPosition: Double {
        get {
            if UserDefaults.standard.object(forKey: subtitleVerticalPosKey) == nil { return 55.0 }
            return UserDefaults.standard.double(forKey: subtitleVerticalPosKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: subtitleVerticalPosKey) }
    }

    private static let subtitleHorizontalPosKey = "Subtitle_Horizontal_Offset_Pct"
    static var subtitleHorizontalPosition: Double {
        get {
            if UserDefaults.standard.object(forKey: subtitleHorizontalPosKey) == nil { return 0.0 }
            return UserDefaults.standard.double(forKey: subtitleHorizontalPosKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: subtitleHorizontalPosKey) }
    }

    static var showOnlyCachedResults: Bool {
        get { UserDefaults.standard.bool(forKey: showOnlyCachedKey) }
        set { UserDefaults.standard.set(newValue, forKey: showOnlyCachedKey) }
    }

    static var defaultPlayerSelection: String {
        get { "native" }
        set { }
    }

    static var useIINAByDefault: Bool {
        get { false }
        set { }
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

    private static let onboardingKey = "Has_Completed_Onboarding_V1"
    private static let setupModeKey = "Streaming_Setup_Mode"
    private static let staticSubtitlesKey = "Static_Subtitles_Preference"
    private static let fastStartBufferingKey = "Fast_Start_Buffering_Preference"

    static var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: onboardingKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    static var streamingSetupMode: String {
        get {
            UserDefaults.standard.string(forKey: setupModeKey) ?? (!realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "debrid" : "classic")
        }
        set { UserDefaults.standard.set(newValue, forKey: setupModeKey) }
    }

    static var isDebridMode: Bool {
        return streamingSetupMode == "debrid" && !realDebridApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var staticSubtitles: Bool {
        get {
            if UserDefaults.standard.object(forKey: staticSubtitlesKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: staticSubtitlesKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: staticSubtitlesKey) }
    }

    static var fastStartBuffering: Bool {
        get {
            if UserDefaults.standard.object(forKey: fastStartBufferingKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: fastStartBufferingKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: fastStartBufferingKey) }
    }

    private static let audioInjectionKey = "enableExternalAudioInjection"
    private static let preferredAudioLangKey = "preferredAudioLanguage"
    private static let palSpeedupKey = "enablePALSpeedupCorrection"

    static var enableExternalAudioInjection: Bool {
        get {
            if UserDefaults.standard.object(forKey: audioInjectionKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: audioInjectionKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: audioInjectionKey) }
    }

    static var preferredAudioLanguage: String {
        get { UserDefaults.standard.string(forKey: preferredAudioLangKey) ?? "tr" }
        set { UserDefaults.standard.set(newValue, forKey: preferredAudioLangKey) }
    }

    private static let updateRepositoryKey = "App_Update_GitHub_Repository"
    static var updateRepository: String {
        get {
            let val = UserDefaults.standard.string(forKey: updateRepositoryKey) ?? ""
            return val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "beratheon/Somnius" : val
        }
        set { UserDefaults.standard.set(newValue, forKey: updateRepositoryKey) }
    }

    static var enablePALSpeedupCorrection: Bool {
        get {
            if UserDefaults.standard.object(forKey: palSpeedupKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: palSpeedupKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: palSpeedupKey) }
    }

    static let cometUrl = "http://localhost:8000"
    static let zileanUrl = "http://localhost:8181"
    static let prowlarrUrl = "http://localhost:9696"
    static var prowlarrApiKey: String = ""
    static let stremthruUrl = "http://localhost:8080"
    static let tmdbApiKey = "a07e22bc18f5cb106bfe4cc1f83ad8ed"
    static let tmdbApiKeyFallback = "e9e9d8da18ae29fc430845952232787c"

    private static let geminiApiKeyKey = "Gemini_API_Key"
    static var geminiApiKey: String {
        get {
            let key = UserDefaults.standard.string(forKey: geminiApiKeyKey) ?? ""
            if !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return key }
            return ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        }
        set { UserDefaults.standard.set(newValue, forKey: geminiApiKeyKey) }
    }
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

        for _ in 0..<4 {
            try await Task.sleep(nanoseconds: 600_000_000)

            var infoRequest = URLRequest(url: infoURL)
            infoRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            if let (infoData, infoResp) = try? await URLSession.shared.data(for: infoRequest),
               let infoHTTP = infoResp as? HTTPURLResponse, (200...299).contains(infoHTTP.statusCode),
               let info = try? JSONDecoder().decode(TorrentInfoResponse.self, from: infoData) {

                if info.status == "downloading" || info.status == "queued" {
                    throw NSError(domain: "RealDebrid", code: 409, userInfo: [NSLocalizedDescriptionKey: "Torrent is not cached in cloud (status: \(info.status))"])
                }

                if let links = info.links, !links.isEmpty {
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

// MARK: - Title Disambiguation & Year Extraction Helper
struct TitleDisambiguationHelper {
    static func parseTitleAndYear(_ raw: String) -> (cleanTitle: String, year: Int?, subtitle: String?) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return ("", nil, nil) }

        var extractedYear: Int? = nil

        // 1. Bracketed or parenthesized year: e.g. "Dexter (2006)" or "Dexter [2006]"
        let bracketRegex = try? NSRegularExpression(pattern: #"[\(\[]\s*([12]\d{3})\s*[\)\]]"#)
        if let match = bracketRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text),
           let y = Int(text[range]), y >= 1900 && y <= 2099 {
            extractedYear = y
            if let fullRange = Range(match.range(at: 0), in: text) {
                text.removeSubrange(fullRange)
            }
        } else {
            // 2. Trailing year: e.g. "Dexter 2006" or "Dexter - 2006"
            let trailingRegex = try? NSRegularExpression(pattern: #"(?:^|\s|-)\s*([12]\d{3})\s*$"#)
            if let match = trailingRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let y = Int(text[range]), y >= 1900 && y <= 2099 {
                extractedYear = y
                if let fullRange = Range(match.range(at: 0), in: text) {
                    text.removeSubrange(fullRange)
                }
            }
        }

        let clean = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-:")))

        var sub: String? = nil
        if let colonIdx = clean.firstIndex(of: ":") {
            let after = clean[clean.index(after: colonIdx)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !after.isEmpty {
                sub = after
            }
        }

        return (clean, extractedYear, sub)
    }
}

// MARK: - TheTVDB (TVDB) Service API Client
class TVDBService {
    static let shared = TVDBService()
    private let baseURL = "https://api4.thetvdb.com/v4"
    private var apiKey: String {
        return Config.tvdbApiKey
    }

    private var cachedToken: String? = nil
    private var tokenExpiry: Date? = nil
    private var seriesIDCache: [String: Int] = [:]
    private let lock = NSLock()

    private func getValidToken() async -> String? {
        lock.lock()
        if let token = cachedToken, let expiry = tokenExpiry, expiry > Date() {
            lock.unlock()
            return token
        }
        lock.unlock()

        guard let url = URL(string: "\(baseURL)/login") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0
        let body = ["apikey": apiKey]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            struct LoginResponse: Decodable {
                struct DataClass: Decodable {
                    let token: String?
                }
                let status: String?
                let data: DataClass?
            }
            if let decoded = try? JSONDecoder().decode(LoginResponse.self, from: data),
               let token = decoded.data?.token {
                lock.lock()
                self.cachedToken = token
                self.tokenExpiry = Date().addingTimeInterval(7 * 24 * 3600)
                lock.unlock()
                return token
            }
        } catch {}
        return nil
    }

    private func executeRequest(endpoint: String, queryItems: [URLQueryItem] = []) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw NSError(domain: "TVDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw NSError(domain: "TVDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"])
        }

        guard let token = await getValidToken() else {
            throw NSError(domain: "TVDB", code: 401, userInfo: [NSLocalizedDescriptionKey: "Failed to authenticate with TVDB"])
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TVDB", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        if httpResponse.statusCode == 401 {
            lock.lock()
            self.cachedToken = nil
            lock.unlock()
            if let freshToken = await getValidToken() {
                var retryRequest = URLRequest(url: url)
                retryRequest.timeoutInterval = 8.0
                retryRequest.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
                retryRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                if let retryHTTP = retryResponse as? HTTPURLResponse {
                    return (retryData, retryHTTP)
                }
            }
        }

        return (data, httpResponse)
    }

    // Resolves TVDB Series ID using IMDb ID, TMDB numeric ID, or title search with strict disambiguation
    func resolveTVDBSeriesID(id: String, imdbID: String? = nil, title: String? = nil, year: Int? = nil) async -> Int? {
        if id.hasPrefix("tvdb-") { return Int(id.replacingOccurrences(of: "tvdb-", with: "")) }
        let lookupKey = "\(id)_\(imdbID ?? "")_\(title ?? "")_\(year ?? 0)"
        lock.lock()
        if let cached = seriesIDCache[lookupKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // 1. Try IMDb ID (e.g. tt0944947) via /search/remoteid/{id}
        if let imdb = imdbID, imdb.hasPrefix("tt") {
            if let found = await searchRemoteID(imdb) {
                cacheSeriesID(key: lookupKey, id: found)
                return found
            }
        }
        if id.hasPrefix("tt") {
            if let found = await searchRemoteID(id) {
                cacheSeriesID(key: lookupKey, id: found)
                return found
            }
        }

        // 2. Try TMDB numeric ID via /search/remoteid/{id}
        if let _ = Int(id) {
            if let found = await searchRemoteID(id) {
                cacheSeriesID(key: lookupKey, id: found)
                return found
            }
        }

        // 3. Try search by title with cautious matching
        if let t = title, !t.isEmpty {
            if let found = await searchByTitle(t, year: year) {
                cacheSeriesID(key: lookupKey, id: found)
                return found
            }
        }

        return nil
    }

    private func cacheSeriesID(key: String, id: Int) {
        lock.lock()
        seriesIDCache[key] = id
        lock.unlock()
    }

    private func searchRemoteID(_ remoteID: String) async -> Int? {
        do {
            let (data, response) = try await executeRequest(endpoint: "/search/remoteid/\(remoteID)")
            guard response.statusCode == 200 else { return nil }
            struct RemoteResponse: Decodable {
                struct ResultItem: Decodable {
                    struct SeriesItem: Decodable {
                        let id: Int
                    }
                    let series: SeriesItem?
                    let id: Int?
                }
                let data: [ResultItem]?
            }
            if let decoded = try? JSONDecoder().decode(RemoteResponse.self, from: data),
               let items = decoded.data {
                if let seriesID = items.compactMap({ $0.series?.id }).first {
                    return seriesID
                }
                if let firstID = items.compactMap({ $0.id }).first {
                    return firstID
                }
            }
        } catch {}
        return nil
    }

    private func searchByTitle(_ title: String, year: Int? = nil) async -> Int? {
        let (cleanTitle, parsedYear, _) = TitleDisambiguationHelper.parseTitleAndYear(title)
        let effectiveYear = year ?? parsedYear
        let targetTitle = cleanTitle.isEmpty ? title.trimmingCharacters(in: .whitespacesAndNewlines) : cleanTitle
        guard !targetTitle.isEmpty else { return nil }

        do {
            let (data, response) = try await executeRequest(
                endpoint: "/search",
                queryItems: [
                    URLQueryItem(name: "query", value: targetTitle),
                    URLQueryItem(name: "type", value: "series")
                ]
            )
            guard response.statusCode == 200 else { return nil }
            struct SearchResponse: Decodable {
                struct SearchItem: Decodable {
                    let tvdb_id: String?
                    let id: String?
                    let name: String?
                    let year: String?
                }
                let data: [SearchItem]?
            }
            guard let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data),
                  let items = decoded.data, !items.isEmpty else { return nil }

            let cleanLower = targetTitle.lowercased()
            let cleanHasColon = cleanLower.contains(":")

            let scored = items.compactMap { item -> (SearchResponse.SearchItem, Double)? in
                let itemName = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !itemName.isEmpty else { return nil }
                let itemLower = itemName.lowercased()

                var score: Double = 0.0

                if itemLower == cleanLower {
                    score += 10000.0
                } else if !cleanHasColon && itemLower.contains(":") {
                    score -= 50000.0
                } else if itemLower.hasPrefix(cleanLower) {
                    score += 500.0
                } else {
                    score -= 10000.0
                }

                if let ey = effectiveYear, let iyStr = item.year, let iy = Int(iyStr) {
                    if iy == ey {
                        score += 15000.0
                    } else if abs(iy - ey) == 1 {
                        score += 3000.0
                    } else if abs(iy - ey) >= 3 {
                        score -= 20000.0
                    }
                }

                return (item, score)
            }.sorted { $0.1 > $1.1 }

            if let best = scored.first, best.1 > 0 {
                let item = best.0
                if let tidStr = item.tvdb_id, let tid = Int(tidStr) {
                    return tid
                }
                if let rawID = item.id {
                    let stripped = rawID.replacingOccurrences(of: "series-", with: "")
                    if let sid = Int(stripped) {
                        return sid
                    }
                }
            }
        } catch {}
        return nil
    }

    // Comprehensive TV Series & Docuseries search using TVDB API with strict disambiguation
    func searchSeries(query: String) async -> [MediaItem] {
        let (cleanQuery, queryYear, _) = TitleDisambiguationHelper.parseTitleAndYear(query)
        let trimmed = cleanQuery.isEmpty ? query.trimmingCharacters(in: .whitespacesAndNewlines) : cleanQuery
        guard !trimmed.isEmpty else { return [] }
        do {
            let (data, response) = try await executeRequest(
                endpoint: "/search",
                queryItems: [
                    URLQueryItem(name: "query", value: trimmed),
                    URLQueryItem(name: "type", value: "series")
                ]
            )
            guard response.statusCode == 200 else { return [] }

            struct TVDBSearchResponse: Decodable {
                struct SearchData: Decodable {
                    let id: String?
                    let tvdb_id: String?
                    let name: String?
                    let overview: String?
                    let image_url: String?
                    let year: String?
                    struct RemoteID: Decodable {
                        let id: String?
                        let sourceName: String?
                    }
                    let remote_ids: [RemoteID]?
                }
                let data: [SearchData]?
            }

            guard let decoded = try? JSONDecoder().decode(TVDBSearchResponse.self, from: data),
                  let items = decoded.data else { return [] }

            let cleanLower = trimmed.lowercased()
            let cleanHasColon = cleanLower.contains(":")

            let sortedItems = items.sorted { a, b in
                let aName = (a.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let bName = (b.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                var aScore: Double = 0
                var bScore: Double = 0

                if aName == cleanLower { aScore += 10000 }
                else if !cleanHasColon && aName.contains(":") { aScore -= 50000 }
                else if aName.hasPrefix(cleanLower) { aScore += 500 }

                if bName == cleanLower { bScore += 10000 }
                else if !cleanHasColon && bName.contains(":") { bScore -= 50000 }
                else if bName.hasPrefix(cleanLower) { bScore += 500 }

                if let qy = queryYear {
                    if let ayStr = a.year, let ay = Int(ayStr) {
                        if ay == qy { aScore += 15000 }
                        else if abs(ay - qy) >= 3 { aScore -= 20000 }
                    }
                    if let byStr = b.year, let by = Int(byStr) {
                        if by == qy { bScore += 15000 }
                        else if abs(by - qy) >= 3 { bScore -= 20000 }
                    }
                }

                return aScore > bScore
            }

            let df = DateFormatter()
            df.dateFormat = "yyyy"

            return sortedItems.prefix(20).compactMap { item in
                guard let name = item.name, !name.isEmpty else { return nil }

                var imdbID: String? = nil
                var tmdbID: String? = nil

                if let remotes = item.remote_ids {
                    for r in remotes {
                        let src = (r.sourceName ?? "").lowercased()
                        if let rId = r.id {
                            if src.contains("imdb") || rId.hasPrefix("tt") {
                                imdbID = rId
                            } else if src.contains("themoviedb") || src.contains("tmdb") {
                                tmdbID = rId
                            }
                        }
                    }
                }

                let numericTVDB: Int? = {
                    if let s = item.tvdb_id, let v = Int(s) { return v }
                    if let raw = item.id {
                        let stripped = raw.replacingOccurrences(of: "series-", with: "")
                        return Int(stripped)
                    }
                    return nil
                }()

                let finalID = imdbID ?? (tmdbID ?? (numericTVDB.map { "\($0)" } ?? (item.id ?? UUID().uuidString)))

                if let tid = numericTVDB {
                    self.cacheSeriesID(key: finalID, id: tid)
                    if let im = imdbID { self.cacheSeriesID(key: im, id: tid) }
                    self.cacheSeriesID(key: "\(finalID)_\(imdbID ?? "")_\(name)", id: tid)
                }

                let pURL = item.image_url.flatMap { URL(string: $0) }
                let relDate = item.year.flatMap { df.date(from: $0) }

                return MediaItem(
                    id: finalID,
                    title: name,
                    description: item.overview,
                    releaseDate: relDate,
                    rating: nil,
                    type: .series,
                    imdbID: imdbID,
                    posterURL: pURL,
                    backdropURL: nil,
                    voteCount: nil
                )
            }
        } catch {
            return []
        }
    }

    func fetchTVSeasons(tvdbID: Int) async -> [TMDBService.TVSeasonInfo] {
        do {
            let (data, response) = try await executeRequest(endpoint: "/series/\(tvdbID)/extended")
            guard response.statusCode == 200 else { return [] }
            struct ExtendedResponse: Decodable {
                struct ExtendedData: Decodable {
                    struct SeasonItem: Decodable {
                        struct SeasonType: Decodable {
                            let id: Int?
                            let type: String?
                        }
                        let id: Int?
                        let type: SeasonType?
                        let number: Int
                        let name: String?
                    }
                    let seasons: [SeasonItem]?
                }
                let data: ExtendedData?
            }
            guard let decoded = try? JSONDecoder().decode(ExtendedResponse.self, from: data),
                  let rawSeasons = decoded.data?.seasons else { return [] }

            let valid = rawSeasons.filter { s in
                let isOfficial = (s.type?.id == 1 || s.type?.type == "official" || s.type == nil)
                return isOfficial && s.number > 0
            }

            var seen = Set<Int>()
            var result: [TMDBService.TVSeasonInfo] = []
            for s in valid.sorted(by: { $0.number < $1.number }) {
                if !seen.contains(s.number) {
                    seen.insert(s.number)
                    let seasonName: String = {
                        if let n = s.name, !n.isEmpty && !n.contains("シーズン") {
                            return n
                        }
                        return "Season \(s.number)"
                    }()
                    result.append(TMDBService.TVSeasonInfo(seasonNumber: s.number, name: seasonName, episodeCount: nil))
                }
            }
            return result
        } catch {
            return []
        }
    }

    func fetchSeasonEpisodes(tvdbID: Int, seasonNumber: Int) async -> [TVEpisodeItem] {
        if let eps = await fetchEpisodesEndpoint(tvdbID: tvdbID, path: "/series/\(tvdbID)/episodes/default/eng", seasonNumber: seasonNumber), !eps.isEmpty {
            return eps
        }
        if let eps = await fetchEpisodesEndpoint(tvdbID: tvdbID, path: "/series/\(tvdbID)/episodes/default", seasonNumber: seasonNumber), !eps.isEmpty {
            return eps
        }
        return []
    }

    private func fetchEpisodesEndpoint(tvdbID: Int, path: String, seasonNumber: Int) async -> [TVEpisodeItem]? {
        do {
            let (data, response) = try await executeRequest(
                endpoint: path,
                queryItems: [URLQueryItem(name: "season", value: "\(seasonNumber)")]
            )
            guard response.statusCode == 200 else { return nil }

            struct EpisodesResponse: Decodable {
                struct EpisodeData: Decodable {
                    struct EpisodeRaw: Decodable {
                        let id: Int
                        let number: Int
                        let name: String?
                        let overview: String?
                        let image: String?
                        let runtime: Int?
                    }
                    let episodes: [EpisodeRaw]?
                }
                let data: EpisodeData?
            }

            if let decoded = try? JSONDecoder().decode(EpisodesResponse.self, from: data),
               let rawList = decoded.data?.episodes, !rawList.isEmpty {
                return rawList.map { ep in
                    let name = (ep.name?.isEmpty == false) ? ep.name! : "Episode \(ep.number)"
                    return TVEpisodeItem(
                        id: ep.id,
                        episodeNumber: ep.number,
                        name: name,
                        overview: ep.overview,
                        stillPath: ep.image,
                        voteAverage: nil,
                        runtime: ep.runtime
                    )
                }.sorted { $0.episodeNumber < $1.episodeNumber }
            }
        } catch {}
        return nil
    }

    func fetchTVDBLogo(tvdbID: Int) async -> URL? {
        do {
            let (data, response) = try await executeRequest(endpoint: "/series/\(tvdbID)/artworks")
            guard response.statusCode == 200 else { return nil }
            struct ArtworksResponse: Decodable {
                struct ArtworksData: Decodable {
                    struct ArtworkRaw: Decodable {
                        let type: Int
                        let language: String?
                        let image: String?
                    }
                    let artworks: [ArtworkRaw]?
                }
                let data: ArtworksData?
            }
            if let decoded = try? JSONDecoder().decode(ArtworksResponse.self, from: data),
               let list = decoded.data?.artworks {
                if let engLogo = list.first(where: { ($0.type == 23 || $0.type == 22) && $0.language == "eng" && $0.image != nil })?.image {
                    return URL(string: engLogo)
                }
                if let anyLogo = list.first(where: { ($0.type == 23 || $0.type == 22) && $0.image != nil })?.image {
                    return URL(string: anyLogo)
                }
            }
        } catch {}
        return nil
    }

    func fetchTVDBCast(tvdbID: Int) async -> [CastMember] {
        do {
            let (data, response) = try await executeRequest(endpoint: "/series/\(tvdbID)/extended")
            guard response.statusCode == 200 else { return [] }
            struct ExtendedResponse: Decodable {
                struct ExtendedData: Decodable {
                    struct CharacterRaw: Decodable {
                        let id: Int?
                        let peopleId: Int?
                        let personName: String?
                        let name: String?
                        let image: String?
                        let personImgURL: String?
                        let sort: Int?
                    }
                    let characters: [CharacterRaw]?
                }
                let data: ExtendedData?
            }
            if let decoded = try? JSONDecoder().decode(ExtendedResponse.self, from: data),
               let chars = decoded.data?.characters, !chars.isEmpty {
                return chars
                    .sorted { ($0.sort ?? 999) < ($1.sort ?? 999) }
                    .prefix(20)
                    .compactMap { c in
                        guard let name = c.personName, !name.isEmpty else { return nil }
                        let photo = c.personImgURL ?? c.image
                        return CastMember(
                            id: c.peopleId ?? c.id ?? Int.random(in: 100000...999999),
                            name: name,
                            character: c.name,
                            profilePath: photo,
                            order: c.sort
                        )
                    }
            }
        } catch {}
        return []
    }
}

// MARK: - TMDB API Service
class TMDBService {
    private let primaryKey = Config.tmdbApiKey
    private let fallbackKey = Config.tmdbApiKeyFallback
    private let baseURL = "https://api.themoviedb.org/3"
    private let tvdb = TVDBService.shared

    private func executeRequest(endpoint: String, queryItems: [URLQueryItem] = []) async throws -> (Data, HTTPURLResponse) {
        let keys = [primaryKey, fallbackKey]
        var lastError: Error?

        for key in keys {
            var components = URLComponents(string: "\(baseURL)\(endpoint)")
            var items = components?.queryItems ?? []
            items.append(contentsOf: queryItems)
            items.append(URLQueryItem(name: "api_key", value: key))
            items.append(URLQueryItem(name: "include_adult", value: "false"))
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

    public func cleanNumericTMDBID(_ rawID: String) -> String? {
        let cleaned = rawID.replacingOccurrences(of: "tmdb:", with: "")
                           .replacingOccurrences(of: "tvdb:", with: "")
                           .trimmingCharacters(in: .whitespacesAndNewlines)
        if Int(cleaned) != nil {
            return cleaned
        }
        return nil
    }

    func fetchTitle(tmdbID: String, type: MediaItem.MediaType) async throws -> String {
        guard let numeric = cleanNumericTMDBID(tmdbID) else {
            return tmdbID
        }
        let endpoint = (type == .series) ? "/tv/\(numeric)" : "/movie/\(numeric)"
        let (data, _) = try await executeRequest(endpoint: endpoint)

        struct TitleDetails: Decodable {
            let title: String?
            let name: String?
        }
        let details = try JSONDecoder().decode(TitleDetails.self, from: data)
        return details.title ?? details.name ?? "Movie"
    }

    func fetchIMDbID(tmdbID: String, type: MediaItem.MediaType) async throws -> String {
        if tmdbID.hasPrefix("tt") { return tmdbID }
        guard let numericID = cleanNumericTMDBID(tmdbID) else {
            throw NSError(domain: "TMDBService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid numeric TMDB ID: \(tmdbID)"])
        }
        let endpoint = (type == .series) ? "/tv/\(numericID)/external_ids" : "/movie/\(numericID)/external_ids"
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

    func searchKeywordIDs(query: String) async -> [Int] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        do {
            let items = [
                URLQueryItem(name: "query", value: trimmed),
                URLQueryItem(name: "page", value: "1")
            ]
            let (data, _) = try await executeRequest(endpoint: "/search/keyword", queryItems: items)
            struct KeywordResponse: Decodable {
                struct KW: Decodable { let id: Int; let name: String }
                let results: [KW]?
            }
            let res = try JSONDecoder().decode(KeywordResponse.self, from: data)
            return res.results?.map { $0.id } ?? []
        } catch {
            return []
        }
    }

    func discoverMedia(
        type: MediaItem.MediaType = .movie,
        genres: [Int] = [],
        keywordIDs: [Int] = [],
        yearMin: Int? = nil,
        yearMax: Int? = nil,
        sortBy: String = "popularity.desc",
        page: Int = 1
    ) async -> [MediaItem] {
        let endpoint = (type == .series) ? "/discover/tv" : "/discover/movie"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: sortBy),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "vote_count.gte", value: "15")
        ]

        if !genres.isEmpty {
            let genreStr = genres.map { String($0) }.joined(separator: ",")
            items.append(URLQueryItem(name: "with_genres", value: genreStr))
        }

        if !keywordIDs.isEmpty {
            let kwStr = keywordIDs.prefix(5).map { String($0) }.joined(separator: "|")
            items.append(URLQueryItem(name: "with_keywords", value: kwStr))
        }

        if type == .movie {
            if let min = yearMin {
                items.append(URLQueryItem(name: "primary_release_date.gte", value: "\(min)-01-01"))
            }
            if let max = yearMax {
                items.append(URLQueryItem(name: "primary_release_date.lte", value: "\(max)-12-31"))
            }
        } else {
            if let min = yearMin {
                items.append(URLQueryItem(name: "first_air_date.gte", value: "\(min)-01-01"))
            }
            if let max = yearMax {
                items.append(URLQueryItem(name: "first_air_date.lte", value: "\(max)-12-31"))
            }
        }

        do {
            let (data, _) = try await executeRequest(endpoint: endpoint, queryItems: items)
            return parseMediaItems(data: data, type: type)
        } catch {
            return []
        }
    }

    func searchSingleMedia(title: String, year: Int? = nil, type: MediaItem.MediaType = .movie) async -> MediaItem? {
        let (cleanTitle, parsedYear, _) = TitleDisambiguationHelper.parseTitleAndYear(title)
        let effectiveYear = year ?? parsedYear
        let targetTitle = cleanTitle.isEmpty ? title.trimmingCharacters(in: .whitespacesAndNewlines) : cleanTitle
        guard !targetTitle.isEmpty else { return nil }
        let endpoint = (type == .series) ? "/search/tv" : "/search/movie"
        var queryItems = [
            URLQueryItem(name: "query", value: targetTitle),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        if let y = effectiveYear {
            if type == .movie {
                queryItems.append(URLQueryItem(name: "year", value: "\(y)"))
            } else {
                queryItems.append(URLQueryItem(name: "first_air_date_year", value: "\(y)"))
            }
        }

        do {
            let (data, _) = try await executeRequest(endpoint: endpoint, queryItems: queryItems)
            let items = parseMediaItems(data: data, type: type)
            let cleanLower = targetTitle.lowercased()
            let cleanHasColon = cleanLower.contains(":")

            let sortedItems = items.sorted { a, b in
                let aTitle = a.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let bTitle = b.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                var aScore: Double = 0
                var bScore: Double = 0

                if aTitle == cleanLower { aScore += 10000 }
                else if !cleanHasColon && aTitle.contains(":") { aScore -= 50000 }
                else if aTitle.hasPrefix(cleanLower) { aScore += 500 }

                if bTitle == cleanLower { bScore += 10000 }
                else if !cleanHasColon && bTitle.contains(":") { bScore -= 50000 }
                else if bTitle.hasPrefix(cleanLower) { bScore += 500 }

                if let ey = effectiveYear {
                    if let ay = a.releaseYear {
                        if ay == ey { aScore += 15000 }
                        else if abs(ay - ey) >= 3 { aScore -= 20000 }
                    }
                    if let by = b.releaseYear {
                        if by == ey { bScore += 15000 }
                        else if abs(by - ey) >= 3 { bScore -= 20000 }
                    }
                }

                aScore += (a.rating ?? 0) * 10
                bScore += (b.rating ?? 0) * 10

                return aScore > bScore
            }

            if let first = sortedItems.first {
                return first
            }
            // Fallback without year if year was too restrictive
            if effectiveYear != nil {
                return await searchSingleMedia(title: targetTitle, year: nil, type: type)
            }
            return nil
        } catch {
            return nil
        }
    }

    func search(query: String) async -> [MediaItem] {
        return await searchMedia(query: query)
    }

    func searchMedia(query: String) async -> [MediaItem] {
        let (cleanQuery, queryYear, _) = TitleDisambiguationHelper.parseTitleAndYear(query)
        let trimmed = cleanQuery.isEmpty ? query.trimmingCharacters(in: .whitespacesAndNewlines) : cleanQuery
        guard !trimmed.isEmpty else { return [] }
        let lowerQuery = trimmed.lowercased()
        let queryHasColon = lowerQuery.contains(":")

        // 1. Standard Search: Query Movies & TV first
        do {
            let items = [
                URLQueryItem(name: "query", value: trimmed),
                URLQueryItem(name: "include_adult", value: "false")
            ]
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
                let vote_count: Int?
                let popularity: Double?
                let release_date: String?
                let first_air_date: String?
                let adult: Bool?
                let original_language: String?
            }

            let decoded = try JSONDecoder().decode(TMDBMultiResponse.self, from: data)
            let raw = decoded.results ?? []

            // Strictly filter out any adult/NSFW content and keep only movies & TV series
            let filtered = raw.filter { item in
                guard item.adult != true else { return false }
                return item.media_type == "movie" || item.media_type == "tv"
            }
            .sorted { a, b in
                let aTitle = (a.title ?? a.name ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let bTitle = (b.title ?? b.name ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                var aScore: Double = 0
                var bScore: Double = 0

                if aTitle == lowerQuery {
                    aScore += 10000
                } else if !queryHasColon && aTitle.contains(":") {
                    aScore -= 50000
                } else if aTitle.hasPrefix(lowerQuery) {
                    aScore += 500
                }

                if bTitle == lowerQuery {
                    bScore += 10000
                } else if !queryHasColon && bTitle.contains(":") {
                    bScore -= 50000
                } else if bTitle.hasPrefix(lowerQuery) {
                    bScore += 500
                }

                if let qy = queryYear {
                    let aDate = a.release_date ?? a.first_air_date
                    let bDate = b.release_date ?? b.first_air_date
                    if let ad = aDate, ad.count >= 4, let ay = Int(ad.prefix(4)) {
                        if ay == qy { aScore += 15000 }
                        else if abs(ay - qy) >= 3 { aScore -= 20000 }
                    }
                    if let bd = bDate, bd.count >= 4, let by = Int(bd.prefix(4)) {
                        if by == qy { bScore += 15000 }
                        else if abs(by - qy) >= 3 { bScore -= 20000 }
                    }
                }

                aScore += Double(a.vote_count ?? 0) / 10.0
                bScore += Double(b.vote_count ?? 0) / 10.0

                return aScore > bScore
            }

            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"

            if !filtered.isEmpty {
                // Concurrently resolve IMDb IDs for top results using proper media type
                var imdbMap: [Int: String] = [:]
                await withTaskGroup(of: (Int, String?).self) { group in
                    for item in filtered.prefix(20) {
                        let isTV = item.media_type == "tv"
                        group.addTask {
                            let imdb = await self.resolveIMDbID(tmdbID: item.id, type: isTV ? .series : .movie)
                            return (item.id, imdb)
                        }
                    }
                    for await (mID, imdb) in group {
                        if let imdb = imdb { imdbMap[mID] = imdb }
                    }
                }

                return filtered.compactMap { res -> MediaItem? in
                    let title = res.title ?? res.name ?? "Untitled"
                    let pURL = res.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
                    let bURL = res.backdrop_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
                    let type: MediaItem.MediaType = (res.media_type == "tv") ? .series : .movie
                    let rawDate = res.release_date ?? res.first_air_date
                    let date = rawDate.flatMap { df.date(from: $0) }
                    let imdb = imdbMap[res.id]

                    return MediaItem(
                        id: imdb ?? "\(res.id)",
                        title: title,
                        description: res.overview,
                        releaseDate: date,
                        rating: res.vote_average,
                        type: type,
                        imdbID: imdb,
                        posterURL: pURL,
                        backdropURL: bURL,
                        voteCount: res.vote_count,
                        originalLanguage: res.original_language
                    )
                }
            }

            // 2. Fallback: Only if NO movies or TV series were found, check if user searched for an acclaimed director or actor
            if let (pData, _) = try? await executeRequest(endpoint: "/search/person", queryItems: [
                URLQueryItem(name: "query", value: trimmed),
                URLQueryItem(name: "include_adult", value: "false")
            ]) {
                struct PersonSearch: Decodable {
                    struct P: Decodable { let id: Int; let name: String; let popularity: Double?; let adult: Bool? }
                    let results: [P]?
                }
                if let pRes = try? JSONDecoder().decode(PersonSearch.self, from: pData),
                   let personList = pRes.results?.filter({ $0.adult != true }) {
                    let sortedPersons = personList.sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
                    if let topPerson = sortedPersons.first, (topPerson.popularity ?? 0) > 3.0 {
                        if let (cData, _) = try? await executeRequest(endpoint: "/person/\(topPerson.id)/combined_credits") {
                            struct Credits: Decodable {
                                struct CreditItem: Decodable {
                                    let id: Int
                                    let title: String?
                                    let name: String?
                                    let overview: String?
                                    let poster_path: String?
                                    let backdrop_path: String?
                                    let media_type: String?
                                    let vote_average: Double?
                                    let vote_count: Int?
                                    let job: String?
                                    let release_date: String?
                                    let first_air_date: String?
                                    let adult: Bool?
                                }
                                let crew: [CreditItem]?
                                let cast: [CreditItem]?
                            }
                            if let cRes = try? JSONDecoder().decode(Credits.self, from: cData) {
                                var creditList: [Credits.CreditItem] = []
                                if let crew = cRes.crew?.filter({ $0.adult != true }) {
                                    let directedOrWritten = crew.filter { $0.job == "Director" || $0.job == "Writer" }
                                    creditList.append(contentsOf: directedOrWritten)
                                }
                                if let cast = cRes.cast?.filter({ $0.adult != true }) {
                                    creditList.append(contentsOf: cast)
                                }

                                creditList.sort(by: { ($0.vote_count ?? 0) > ($1.vote_count ?? 0) })

                                var seenIDs = Set<Int>()
                                var topCredits: [Credits.CreditItem] = []
                                for item in creditList {
                                    if !seenIDs.contains(item.id) && (item.vote_count ?? 0) > 50 {
                                        seenIDs.insert(item.id)
                                        topCredits.append(item)
                                        if topCredits.count >= 24 { break }
                                    }
                                }

                                if !topCredits.isEmpty {
                                    var imdbMap: [Int: String] = [:]
                                    await withTaskGroup(of: (Int, String?).self) { group in
                                        for item in topCredits.prefix(12) {
                                            let isTV = item.media_type == "tv"
                                            group.addTask {
                                                let imdb = await self.resolveIMDbID(tmdbID: item.id, type: isTV ? .series : .movie)
                                                return (item.id, imdb)
                                            }
                                        }
                                        for await (mID, imdb) in group {
                                            if let imdb = imdb { imdbMap[mID] = imdb }
                                        }
                                    }

                                    return topCredits.compactMap { res in
                                        let isTV = res.media_type == "tv"
                                        let title = res.title ?? res.name ?? "Untitled"
                                        let pURL = res.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
                                        let bURL = res.backdrop_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
                                        let rawDate = res.release_date ?? res.first_air_date
                                        let date = rawDate.flatMap { df.date(from: $0) }
                                        let imdb = imdbMap[res.id]

                                        return MediaItem(
                                            id: imdb ?? "\(res.id)",
                                            title: title,
                                            description: res.overview,
                                            releaseDate: date,
                                            rating: res.vote_average,
                                            type: isTV ? .series : .movie,
                                            imdbID: imdb,
                                            posterURL: pURL,
                                            backdropURL: bURL,
                                            voteCount: res.vote_count
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            return []
        }
        return []
    }

    // Cinemeta Series metadata structures for instant, comprehensive seasons & episodes
    struct CinemetaSeriesResponse: Decodable {
        let meta: CinemetaMeta?
    }
    struct CinemetaMeta: Decodable {
        let name: String?
        let videos: [CinemetaVideoItem]?
    }
    struct CinemetaVideoItem: Decodable {
        let name: String?
        let title: String?
        let season: Int?
        let number: Int?
        let episode: Int?
        let overview: String?
        let description: String?
        let thumbnail: String?
        let id: String?
    }

    private static var cinemetaSeriesCache: [String: [CinemetaVideoItem]] = [:]

    private func fetchCinemetaVideos(imdbID: String) async -> [CinemetaVideoItem]? {
        if let cached = Self.cinemetaSeriesCache[imdbID] {
            return cached
        }
        guard let url = URL(string: "https://v3-cinemeta.strem.io/meta/series/\(imdbID).json") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(CinemetaSeriesResponse.self, from: data)
            if let videos = decoded.meta?.videos, !videos.isEmpty {
                Self.cinemetaSeriesCache[imdbID] = videos
                return videos
            }
        } catch {
            print("[TMDBService] Cinemeta series fetch error for \(imdbID): \(error)")
        }
        return nil
    }

    struct TVSeasonInfo: Identifiable, Hashable {
        let seasonNumber: Int
        let name: String
        let episodeCount: Int?

        var id: Int { seasonNumber }
    }

    func fetchTVSeasons(tvID: String, imdbID: String? = nil, title: String? = nil, year: Int? = nil) async -> [TVSeasonInfo] {
        var tmdbNumericID: String? = cleanNumericTMDBID(tvID)
        if tmdbNumericID == nil, let imdb = imdbID, let num = cleanNumericTMDBID(imdb) {
            tmdbNumericID = num
        }
        if tmdbNumericID == nil {
            let lookup = imdbID ?? tvID
            if let found = await resolveTMDBID(imdbID: lookup, type: .series) {
                tmdbNumericID = found
            } else if let t = title, let found = await resolveTMDBIDByTitle(title: t, type: .series, year: year) {
                tmdbNumericID = found
            }
        }

        // 1. Try TMDB
        if let numericID = tmdbNumericID {
            do {
                let (data, _) = try await executeRequest(endpoint: "/tv/\(numericID)")
                struct TVDetails: Decodable {
                    struct SeasonItem: Decodable {
                        let season_number: Int
                        let name: String?
                        let episode_count: Int?
                    }
                    let seasons: [SeasonItem]?
                }
                let details = try JSONDecoder().decode(TVDetails.self, from: data)
                if let rawSeasons = details.seasons {
                    let validSeasons = rawSeasons
                        .filter { $0.season_number > 0 }
                        .sorted { $0.season_number < $1.season_number }
                        .map { TVSeasonInfo(seasonNumber: $0.season_number, name: $0.name ?? "Season \($0.season_number)", episodeCount: $0.episode_count) }
                    if !validSeasons.isEmpty {
                        return validSeasons
                    }
                }
            } catch {}
        }

        // 2. Try TheTVDB (TVDB) for complete TV seasons
        if let tvdbID = await tvdb.resolveTVDBSeriesID(id: tvID, imdbID: imdbID, title: title, year: year) {
            let tvdbSeasons = await tvdb.fetchTVSeasons(tvdbID: tvdbID)
            if !tvdbSeasons.isEmpty {
                return tvdbSeasons
            }
        }

        // 3. Cinemeta fallback
        let resolvedIMDb = (tvID.hasPrefix("tt") ? tvID : (imdbID?.hasPrefix("tt") == true ? imdbID : nil))
        if let imdb = resolvedIMDb {
            if let videos = await fetchCinemetaVideos(imdbID: imdb) {
                let seasonNums = Set(videos.compactMap { $0.season }).filter { $0 > 0 }.sorted()
                if !seasonNums.isEmpty {
                    return seasonNums.map { sNum in
                        let count = videos.filter { $0.season == sNum }.count
                        return TVSeasonInfo(seasonNumber: sNum, name: "Season \(sNum)", episodeCount: count > 0 ? count : nil)
                    }
                }
            }
        }

        return [TVSeasonInfo(seasonNumber: 1, name: "Season 1", episodeCount: nil)]
    }

    func fetchTVSeasonsCount(tvID: String, imdbID: String? = nil, title: String? = nil, year: Int? = nil) async -> Int {
        let seasons = await fetchTVSeasons(tvID: tvID, imdbID: imdbID, title: title, year: year)
        return seasons.map { $0.seasonNumber }.max() ?? 1
    }

    func fetchSeasonEpisodes(tvID: String, imdbID: String? = nil, seasonNumber: Int, title: String? = nil, year: Int? = nil) async -> [TVEpisodeItem] {
        // 1. First try TMDB directly for high-resolution 16:9 still pictures, precise runtimes, and clean synopsis
        var tmdbNumericID: String? = cleanNumericTMDBID(tvID)
        if tmdbNumericID == nil, let imdb = imdbID, let num = cleanNumericTMDBID(imdb) {
            tmdbNumericID = num
        }
        if tmdbNumericID == nil {
            let lookup = imdbID ?? tvID
            if let found = await resolveTMDBID(imdbID: lookup, type: .series) {
                tmdbNumericID = found
            } else if let t = title, let found = await resolveTMDBIDByTitle(title: t, type: .series, year: year) {
                tmdbNumericID = found
            }
        }

        var tmdbEpisodes: [TVEpisodeItem]? = nil

        if let numericID = tmdbNumericID {
            do {
                let (data, _) = try await executeRequest(endpoint: "/tv/\(numericID)/season/\(seasonNumber)")
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
                if let rawEps = details.episodes, !rawEps.isEmpty {
                    tmdbEpisodes = rawEps.map { ep in
                        TVEpisodeItem(
                            id: ep.id,
                            episodeNumber: ep.episode_number,
                            name: ep.name,
                            overview: ep.overview,
                            stillPath: ep.still_path,
                            voteAverage: ep.vote_average,
                            runtime: ep.runtime
                        )
                    }.sorted { $0.episodeNumber < $1.episodeNumber }
                }
            } catch {}
        }

        // If TMDB returned episodes, verify if any episode is missing artwork or synopsis. If so, enrich from TVDB!
        if let eps = tmdbEpisodes, !eps.isEmpty {
            let hasMissingData = eps.contains(where: { ($0.stillPath == nil || $0.stillPath!.isEmpty) || ($0.overview == nil || $0.overview!.isEmpty) })
            if !hasMissingData {
                return eps
            }
            if let tvdbID = await tvdb.resolveTVDBSeriesID(id: tvID, imdbID: imdbID, title: title) {
                let tvdbEps = await tvdb.fetchSeasonEpisodes(tvdbID: tvdbID, seasonNumber: seasonNumber)
                if !tvdbEps.isEmpty {
                    let tvdbMap = Dictionary(tvdbEps.map { ($0.episodeNumber, $0) }, uniquingKeysWith: { first, _ in first })
                    let enriched = eps.map { ep -> TVEpisodeItem in
                        let tvdbMatch = tvdbMap[ep.episodeNumber]
                        let finalStill = (ep.stillPath != nil && !ep.stillPath!.isEmpty) ? ep.stillPath : tvdbMatch?.stillPath
                        let finalOverview = (ep.overview != nil && !ep.overview!.isEmpty) ? ep.overview : tvdbMatch?.overview
                        let finalRuntime = (ep.runtime != nil && ep.runtime! > 0) ? ep.runtime : tvdbMatch?.runtime
                        return TVEpisodeItem(
                            id: ep.id,
                            episodeNumber: ep.episodeNumber,
                            name: ep.name,
                            overview: finalOverview,
                            stillPath: finalStill,
                            voteAverage: ep.voteAverage,
                            runtime: finalRuntime
                        )
                    }
                    return enriched
                }
            }
            return eps
        }

        // 2. If TMDB failed or returned empty: Try TheTVDB (TVDB) directly
        if let tvdbID = await tvdb.resolveTVDBSeriesID(id: tvID, imdbID: imdbID, title: title, year: year) {
            let tvdbEps = await tvdb.fetchSeasonEpisodes(tvdbID: tvdbID, seasonNumber: seasonNumber)
            if !tvdbEps.isEmpty {
                return tvdbEps
            }
        }

        // 3. Cinemeta fallback if both TMDB and TVDB fail
        var resolvedIMDb = (tvID.hasPrefix("tt") ? tvID : (imdbID?.hasPrefix("tt") == true ? imdbID : nil))
        if resolvedIMDb == nil, let num = tmdbNumericID ?? cleanNumericTMDBID(tvID) {
            resolvedIMDb = try? await fetchIMDbID(tmdbID: num, type: .series)
        }
        if resolvedIMDb == nil, let t = title {
            resolvedIMDb = await resolveIMDbIDByTitle(title: t, type: .series, year: year)
        }

        if let imdb = resolvedIMDb {
            if let videos = await fetchCinemetaVideos(imdbID: imdb) {
                let seasonVideos = videos.filter { $0.season == seasonNumber }
                if !seasonVideos.isEmpty {
                    return seasonVideos.enumerated().map { idx, v in
                        let epNum = v.episode ?? v.number ?? (idx + 1)
                        let epName = v.name ?? v.title ?? "Episode \(epNum)"
                        let epOverview = v.overview ?? v.description
                        return TVEpisodeItem(
                            id: idx + 1000 * seasonNumber,
                            episodeNumber: epNum,
                            name: epName,
                            overview: epOverview,
                            stillPath: v.thumbnail,
                            voteAverage: nil,
                            runtime: nil
                        )
                    }.sorted { $0.episodeNumber < $1.episodeNumber }
                }
            }
        }

        return []
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
            let release_date: String?
            let first_air_date: String?
            let adult: Bool?
            let original_language: String?
        }

        guard let decoded = try? JSONDecoder().decode(TMDBPageResponse.self, from: data),
              let raw = decoded.results else { return [] }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        return raw.compactMap { res in
            guard res.adult != true else { return nil }
            let title = res.title ?? res.name ?? "Untitled"
            let pURL = res.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\( $0 )") }
            let bURL = res.backdrop_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\( $0 )") }
            let rawDate = res.release_date ?? res.first_air_date
            let date = rawDate.flatMap { df.date(from: $0) }

            return MediaItem(
                id: "\(res.id)",
                title: title,
                description: res.overview,
                posterUrl: pURL,
                backdropUrl: bURL,
                releaseDate: date,
                rating: res.vote_average,
                type: type,
                originalLanguage: res.original_language
            )
        }
    }

    // MARK: - Collections & Sequels
    struct MovieCollectionResult {
        let name: String
        let items: [MediaItem]
    }

    func fetchMovieCollection(movieID: String, imdbID: String? = nil, title: String? = nil, year: Int? = nil) async -> MovieCollectionResult? {
        var targetID: String? = cleanNumericTMDBID(movieID)
        if targetID == nil, let imdb = imdbID, let num = cleanNumericTMDBID(imdb) {
            targetID = num
        }
        if targetID == nil {
            let lookup = imdbID ?? movieID
            if let found = await resolveTMDBID(imdbID: lookup, type: .movie) {
                targetID = found
            } else if let t = title, let found = await resolveTMDBIDByTitle(title: t, type: .movie, year: year) {
                targetID = found
            }
        }
        guard let validTargetID = targetID else { return nil }

        do {
            let (movieData, _) = try await executeRequest(endpoint: "/movie/\(validTargetID)")
            struct CollectionRef: Decodable {
                let id: Int
                let name: String
            }
            struct MovieDetails: Decodable {
                let belongs_to_collection: CollectionRef?
            }

            guard let details = try? JSONDecoder().decode(MovieDetails.self, from: movieData),
                  let collection = details.belongs_to_collection else {
                return nil
            }

            let (colData, _) = try await executeRequest(endpoint: "/collection/\(collection.id)")
            struct CollectionResponse: Decodable {
                let name: String?
                let parts: [TMDBCollectionPart]?
            }
            struct TMDBCollectionPart: Decodable {
                let id: Int
                let title: String?
                let overview: String?
                let poster_path: String?
                let backdrop_path: String?
                let vote_average: Double?
                let release_date: String?
                let adult: Bool?
            }

            guard let colRes = try? JSONDecoder().decode(CollectionResponse.self, from: colData),
                  let parts = colRes.parts, !parts.isEmpty else {
                return nil
            }

            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"

            // Concurrently resolve IMDb IDs for each part so btttr.cc poster provider and stream scrapers work seamlessly
            var imdbMap: [Int: String] = [:]
            await withTaskGroup(of: (Int, String?).self) { group in
                for part in parts where part.adult != true {
                    group.addTask {
                        let imdb = await self.resolveIMDbIDForMovie(tmdbID: part.id)
                        return (part.id, imdb)
                    }
                }
                for await (partID, imdb) in group {
                    if let imdb = imdb { imdbMap[partID] = imdb }
                }
            }

            let items: [MediaItem] = parts.filter({ $0.adult != true }).compactMap { part in
                let pURL = part.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
                let bURL = part.backdrop_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
                let date = part.release_date.flatMap { df.date(from: $0) }
                let imdb = imdbMap[part.id]

                return MediaItem(
                    id: imdb ?? "\(part.id)",
                    title: part.title ?? "Untitled",
                    description: part.overview,
                    releaseDate: date,
                    rating: part.vote_average,
                    type: .movie,
                    imdbID: imdb,
                    posterURL: pURL,
                    backdropURL: bURL
                )
            }.sorted { (m1, m2) -> Bool in
                guard let d1 = m1.releaseDate, let d2 = m2.releaseDate else { return false }
                return d1 < d2
            }

            return MovieCollectionResult(name: colRes.name ?? collection.name, items: items)
        } catch {
            return nil
        }
    }

    func fetchSimilarMedia(id: String, imdbID: String? = nil, type: MediaItem.MediaType, title: String? = nil, year: Int? = nil) async -> [MediaItem] {
        var targetID: String? = cleanNumericTMDBID(id)
        if targetID == nil, let imdb = imdbID, let num = cleanNumericTMDBID(imdb) {
            targetID = num
        }
        if targetID == nil {
            let lookup = imdbID ?? id
            if let found = await resolveTMDBID(imdbID: lookup, type: type) {
                targetID = found
            } else if let t = title, let found = await resolveTMDBIDByTitle(title: t, type: type, year: year) {
                targetID = found
            }
        }
        guard let validTargetID = targetID else { return [] }

        let prefix = (type == .series) ? "/tv" : "/movie"
        var rawItems: [MediaItem] = []
        if let (simData, _) = try? await executeRequest(endpoint: "\(prefix)/\(validTargetID)/similar") {
            let items = parseMediaItems(data: simData, type: type)
            if !items.isEmpty { rawItems = items }
        }

        if rawItems.isEmpty, let (recData, _) = try? await executeRequest(endpoint: "\(prefix)/\(validTargetID)/recommendations") {
            let items = parseMediaItems(data: recData, type: type)
            if !items.isEmpty { rawItems = items }
        }

        if rawItems.isEmpty { return [] }

        // Concurrently resolve IMDb IDs for high-res BetterPosters & seamless playback
        var imdbMap: [String: String] = [:]
        await withTaskGroup(of: (String, String?).self) { group in
            for item in rawItems.prefix(20) {
                if let tmdbInt = Int(item.id) {
                    group.addTask {
                        let imdb = await self.resolveIMDbID(tmdbID: tmdbInt, type: type)
                        return (item.id, imdb)
                    }
                }
            }
            for await (itemId, resolvedImdb) in group {
                if let resolvedImdb = resolvedImdb {
                    imdbMap[itemId] = resolvedImdb
                }
            }
        }

        return rawItems.map { item in
            let resolvedImdb = imdbMap[item.id] ?? item.imdbID
            return MediaItem(
                id: resolvedImdb ?? item.id,
                title: item.title,
                description: item.description,
                posterUrl: item.posterURL,
                backdropUrl: item.backdropURL,
                releaseDate: item.releaseDate,
                rating: item.rating,
                type: item.type,
                imdbID: resolvedImdb,
                posterURL: item.posterURL,
                backdropURL: item.backdropURL
            )
        }
    }

    func fetchRecommendations(id: String, imdbID: String? = nil, type: MediaItem.MediaType, title: String? = nil, year: Int? = nil) async -> [MediaItem] {
        var targetID: String? = cleanNumericTMDBID(id)
        if targetID == nil, let imdb = imdbID, let num = cleanNumericTMDBID(imdb) {
            targetID = num
        }
        if targetID == nil {
            let lookup = imdbID ?? id
            if let found = await resolveTMDBID(imdbID: lookup, type: type) {
                targetID = found
            } else if let t = title, let found = await resolveTMDBIDByTitle(title: t, type: type, year: year) {
                targetID = found
            }
        }
        guard let validTargetID = targetID else { return [] }

        let prefix = (type == .series) ? "/tv" : "/movie"
        var rawItems: [MediaItem] = []
        if let (recData, _) = try? await executeRequest(endpoint: "\(prefix)/\(validTargetID)/recommendations") {
            let items = parseMediaItems(data: recData, type: type)
            if !items.isEmpty { rawItems = items }
        }

        if rawItems.isEmpty { return [] }

        var imdbMap: [String: String] = [:]
        await withTaskGroup(of: (String, String?).self) { group in
            for item in rawItems.prefix(20) {
                if let tmdbInt = Int(item.id) {
                    group.addTask {
                        let imdb = await self.resolveIMDbID(tmdbID: tmdbInt, type: type)
                        return (item.id, imdb)
                    }
                }
            }
            for await (itemId, resolvedImdb) in group {
                if let resolvedImdb = resolvedImdb {
                    imdbMap[itemId] = resolvedImdb
                }
            }
        }

        return rawItems.map { item in
            let resolvedImdb = imdbMap[item.id] ?? item.imdbID
            return MediaItem(
                id: resolvedImdb ?? item.id,
                title: item.title,
                description: item.description,
                posterUrl: item.posterURL,
                backdropUrl: item.backdropURL,
                releaseDate: item.releaseDate,
                rating: item.rating,
                type: item.type,
                imdbID: resolvedImdb,
                posterURL: item.posterURL,
                backdropURL: item.backdropURL
            )
        }
    }

    // MARK: - Title Logo & Extended Details
    struct MediaExtendedDetails {
        let logoURL: URL?
        let runtimeMinutes: Int?
        let tagline: String?
        let originalLanguage: String?
        let imdbID: String?
        let overview: String?
        let year: String?
        let rating: Double?

        init(
            logoURL: URL?,
            runtimeMinutes: Int?,
            tagline: String? = nil,
            originalLanguage: String? = nil,
            imdbID: String? = nil,
            overview: String? = nil,
            year: String? = nil,
            rating: Double? = nil
        ) {
            self.logoURL = logoURL
            self.runtimeMinutes = runtimeMinutes
            self.tagline = tagline
            self.originalLanguage = originalLanguage
            self.imdbID = imdbID
            self.overview = overview
            self.year = year
            self.rating = rating
        }
    }

    func fetchMediaLogoAndDetails(id: String, imdbID: String? = nil, type: MediaItem.MediaType, title: String? = nil, year: Int? = nil) async -> MediaExtendedDetails {
        var targetID: String? = cleanNumericTMDBID(id)
        if targetID == nil, let imdb = imdbID, let num = cleanNumericTMDBID(imdb) {
            targetID = num
        }
        if targetID == nil {
            let lookup = imdbID ?? id
            if let found = await resolveTMDBID(imdbID: lookup, type: type) {
                targetID = found
            } else if let t = title, let found = await resolveTMDBIDByTitle(title: t, type: type, year: year) {
                targetID = found
            }
        }

        var actualIMDbID = imdbID?.hasPrefix("tt") == true ? imdbID : (id.hasPrefix("tt") ? id : nil)
        if actualIMDbID == nil, let num = targetID {
            actualIMDbID = try? await fetchIMDbID(tmdbID: num, type: type)
        }
        if actualIMDbID == nil, let t = title {
            actualIMDbID = await resolveIMDbIDByTitle(title: t, type: type, year: year)
        }

        // 1. Check Stremio Metahub official transparent title logo
        var resolvedLogoURL: URL? = nil
        if let imdb = actualIMDbID, !imdb.isEmpty {
            resolvedLogoURL = URL(string: "https://images.metahub.space/logo/medium/\(imdb)/img.png")
        }

        var runtimeMins: Int? = nil
        var resolvedTagline: String? = nil
        var resolvedOriginalLang: String? = nil
        var resolvedOverview: String? = nil
        var resolvedYear: String? = nil
        var resolvedRating: Double? = nil

        guard let validTargetID = targetID, let tmdbNumericID = Int(validTargetID) else {
            // Check TVDB logo if Metahub is not available for series
            if resolvedLogoURL == nil && type == .series {
                if let tvdbID = await tvdb.resolveTVDBSeriesID(id: id, imdbID: imdbID, title: title, year: year) {
                    if let logo = await tvdb.fetchTVDBLogo(tvdbID: tvdbID) {
                        resolvedLogoURL = logo
                    }
                }
            }
            // Fallback overview from Cinemeta if no TMDB ID was found
            if let imdb = actualIMDbID, !imdb.isEmpty {
                let cinemetaType = (type == .series) ? "series" : "movie"
                if let cineURL = URL(string: "https://v3-cinemeta.strem.io/meta/\(cinemetaType)/\(imdb).json"),
                   let (cData, cResp) = try? await URLSession.shared.data(from: cineURL),
                   (cResp as? HTTPURLResponse)?.statusCode == 200 {
                    struct CineMetaWrapper: Decodable {
                        struct CineMetaInner: Decodable {
                            let description: String?
                            let overview: String?
                            let year: String?
                            let imdbRating: String?
                        }
                        let meta: CineMetaInner?
                    }
                    if let cineDecoded = try? JSONDecoder().decode(CineMetaWrapper.self, from: cData), let meta = cineDecoded.meta {
                        resolvedOverview = meta.description ?? meta.overview
                        resolvedYear = meta.year
                        if let rStr = meta.imdbRating, let rDbl = Double(rStr) {
                            resolvedRating = rDbl
                        }
                    }
                }
            }
            return MediaExtendedDetails(
                logoURL: resolvedLogoURL,
                runtimeMinutes: nil,
                tagline: nil,
                originalLanguage: nil,
                imdbID: actualIMDbID,
                overview: resolvedOverview,
                year: resolvedYear,
                rating: resolvedRating
            )
        }

        let prefix = (type == .series) ? "/tv/\(tmdbNumericID)" : "/movie/\(tmdbNumericID)"

        // 2. Fetch runtime, tagline, overview, rating, release year from details endpoint
        if let (detailsData, _) = try? await executeRequest(endpoint: prefix) {
            struct RawDetails: Decodable {
                let runtime: Int?
                let episode_run_time: [Int]?
                let tagline: String?
                let original_language: String?
                let overview: String?
                let vote_average: Double?
                let release_date: String?
                let first_air_date: String?
            }
            if let decoded = try? JSONDecoder().decode(RawDetails.self, from: detailsData) {
                runtimeMins = decoded.runtime ?? decoded.episode_run_time?.first
                if let tag = decoded.tagline, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resolvedTagline = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                resolvedOriginalLang = decoded.original_language
                if let ov = decoded.overview, !ov.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resolvedOverview = ov.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let va = decoded.vote_average, va > 0 {
                    resolvedRating = va
                }
                if let rel = decoded.release_date ?? decoded.first_air_date, rel.count >= 4 {
                    resolvedYear = String(rel.prefix(4))
                }
            }
        }

        // 3. Fallback to TMDB transparent logo art if Metahub logo wasn't available
        if resolvedLogoURL == nil, let (imgData, _) = try? await executeRequest(endpoint: "\(prefix)/images") {
            struct RawImages: Decodable {
                struct LogoItem: Decodable {
                    let file_path: String?
                    let iso_639_1: String?
                }
                let logos: [LogoItem]?
            }
            if let imgRes = try? JSONDecoder().decode(RawImages.self, from: imgData), let logos = imgRes.logos {
                let enLogo = logos.first(where: { $0.iso_639_1 == "en" }) ?? logos.first
                if let path = enLogo?.file_path {
                    resolvedLogoURL = URL(string: "https://image.tmdb.org/t/p/w500\(path)")
                }
            }
        }

        // 4. TVDB ClearLogo fallback for TV series if still nil
        if resolvedLogoURL == nil && type == .series {
            if let tvdbID = await tvdb.resolveTVDBSeriesID(id: id, imdbID: imdbID, title: title, year: year) {
                if let logo = await tvdb.fetchTVDBLogo(tvdbID: tvdbID) {
                    resolvedLogoURL = logo
                }
            }
        }

        return MediaExtendedDetails(
            logoURL: resolvedLogoURL,
            runtimeMinutes: runtimeMins,
            tagline: resolvedTagline,
            originalLanguage: resolvedOriginalLang,
            imdbID: actualIMDbID,
            overview: resolvedOverview,
            year: resolvedYear,
            rating: resolvedRating
        )
    }

    // MARK: - Scene Images & Timeline Backdrops
    func fetchSceneImages(id: String, imdbID: String? = nil, type: MediaItem.MediaType, title: String? = nil, year: Int? = nil) async -> [URL] {
        var tmdbNumericID: String? = cleanNumericTMDBID(id)
        if tmdbNumericID == nil, let imdb = imdbID, !imdb.isEmpty {
            tmdbNumericID = await resolveTMDBID(imdbID: imdb, type: type)
        }
        if tmdbNumericID == nil, let t = title, !t.isEmpty {
            tmdbNumericID = await resolveTMDBIDByTitle(title: t, type: type, year: year)
        }
        guard let numID = tmdbNumericID else { return [] }
        let prefix = (type == .series) ? "/tv/\(numID)" : "/movie/\(numID)"
        guard let (imgData, _) = try? await executeRequest(endpoint: "\(prefix)/images", queryItems: [URLQueryItem(name: "include_image_language", value: "en,null")]) else {
            return []
        }
        struct RawBackdropsResponse: Decodable {
            struct BackdropItem: Decodable {
                let file_path: String?
            }
            let backdrops: [BackdropItem]?
        }
        guard let decoded = try? JSONDecoder().decode(RawBackdropsResponse.self, from: imgData), let backdrops = decoded.backdrops else {
            return []
        }
        return backdrops.compactMap { item in
            guard let path = item.file_path, !path.isEmpty else { return nil }
            return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
        }
    }

    // MARK: - Videos, Trailers & Extras
    struct MediaExtra: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let key: String
        let site: String
        let type: String // "Trailer", "Teaser", "Behind the Scenes", "Featurette", "Bloopers", "Recap", "Clip"
        let official: Bool?
        let publishedAt: String?

        var thumbnailURL: URL? {
            if site.lowercased() == "youtube" {
                return URL(string: "https://img.youtube.com/vi/\(key)/hqdefault.jpg")
            }
            return nil
        }

        var youtubeURL: URL? {
            if site.lowercased() == "youtube" {
                return URL(string: "https://www.youtube.com/watch?v=\(key)")
            }
            return nil
        }
    }

    func fetchMediaExtras(id: String, imdbID: String? = nil, type: MediaItem.MediaType, title: String? = nil, year: Int? = nil) async -> [MediaExtra] {
        var targetID: String? = cleanNumericTMDBID(id)
        if targetID == nil, let imdb = imdbID, let num = cleanNumericTMDBID(imdb) {
            targetID = num
        }
        if targetID == nil {
            let lookup = imdbID ?? id
            if let found = await resolveTMDBID(imdbID: lookup, type: type) {
                targetID = found
            } else if let t = title, let found = await resolveTMDBIDByTitle(title: t, type: type, year: year) {
                targetID = found
            }
        }
        guard let validTargetID = targetID, let tmdbNumericID = Int(validTargetID) else { return [] }

        let endpoint = (type == .series) ? "/tv/\(tmdbNumericID)/videos" : "/movie/\(tmdbNumericID)/videos"
        guard let (data, _) = try? await executeRequest(endpoint: endpoint) else { return [] }

        struct RawVideosResponse: Decodable {
            struct RawVideoItem: Decodable {
                let id: String
                let name: String
                let key: String
                let site: String
                let type: String
                let official: Bool?
                let published_at: String?
            }
            let results: [RawVideoItem]?
        }

        guard let decoded = try? JSONDecoder().decode(RawVideosResponse.self, from: data),
              let results = decoded.results else { return [] }

        // Sort priority: Behind the Scenes, Featurette, Recap, Bloopers, Clip, Trailer, Teaser
        let typePriority: [String: Int] = [
            "Behind the Scenes": 1,
            "Featurette": 2,
            "Recap": 3,
            "Bloopers": 4,
            "Clip": 5,
            "Trailer": 6,
            "Teaser": 7
        ]

        let sorted = results.sorted { a, b in
            let pA = typePriority[a.type] ?? 99
            let pB = typePriority[b.type] ?? 99
            if pA != pB { return pA < pB }
            return (a.official == true && b.official != true)
        }

        return sorted.map {
            MediaExtra(
                id: $0.id,
                name: $0.name,
                key: $0.key,
                site: $0.site,
                type: $0.type,
                official: $0.official,
                publishedAt: $0.published_at
            )
        }
    }

    // MARK: - Cast, Crew & Person Works
    func fetchMediaCredits(id: String, imdbID: String? = nil, type: MediaItem.MediaType, title: String? = nil, year: Int? = nil) async -> MediaCredits? {
        var targetID: String? = cleanNumericTMDBID(id)
        if targetID == nil, let imdb = imdbID, let num = cleanNumericTMDBID(imdb) {
            targetID = num
        }
        if targetID == nil {
            let lookup = imdbID ?? id
            if let found = await resolveTMDBID(imdbID: lookup, type: type) {
                targetID = found
            } else if let t = title, let found = await resolveTMDBIDByTitle(title: t, type: type, year: year) {
                targetID = found
            }
        }

        var tmdbCast: [CastMember] = []
        var tmdbDirectors: [CrewMember] = []

        if let validTarget = targetID, let tmdbNumericID = Int(validTarget) {
            let endpoint = (type == .series) ? "/tv/\(tmdbNumericID)/credits" : "/movie/\(tmdbNumericID)/credits"
            if let (data, _) = try? await executeRequest(endpoint: endpoint) {
                struct RawCredits: Decodable {
                    struct RawCast: Decodable {
                        let id: Int
                        let name: String
                        let character: String?
                        let profile_path: String?
                        let order: Int?
                    }
                    struct RawCrew: Decodable {
                        let id: Int
                        let name: String
                        let job: String?
                        let department: String?
                        let profile_path: String?
                    }
                    let cast: [RawCast]?
                    let crew: [RawCrew]?
                }

                if let decoded = try? JSONDecoder().decode(RawCredits.self, from: data) {
                    let rawCast: [RawCredits.RawCast] = decoded.cast ?? []
                    let sortedCast = rawCast.sorted { ($0.order ?? 999) < ($1.order ?? 999) }.prefix(20)
                    tmdbCast = sortedCast.map { CastMember(id: $0.id, name: $0.name, character: $0.character, profilePath: $0.profile_path, order: $0.order) }

                    let rawCrew: [RawCredits.RawCrew] = decoded.crew ?? []
                    let filteredCrew = rawCrew.filter { $0.job == "Director" || $0.job == "Series Director" || $0.job == "Creator" }
                    tmdbDirectors = filteredCrew.map { CrewMember(id: $0.id, name: $0.name, job: $0.job, department: $0.department, profilePath: $0.profile_path) }
                }
            }
        }

        if !tmdbCast.isEmpty {
            return MediaCredits(directors: tmdbDirectors, cast: tmdbCast)
        }

        // TVDB Cast Fallback for TV Series
        if type == .series {
            if let tvdbID = await tvdb.resolveTVDBSeriesID(id: id, imdbID: imdbID, title: title) {
                let tvdbCast = await tvdb.fetchTVDBCast(tvdbID: tvdbID)
                if !tvdbCast.isEmpty {
                    return MediaCredits(directors: tmdbDirectors, cast: tvdbCast)
                }
            }
        }

        if !tmdbDirectors.isEmpty {
            return MediaCredits(directors: tmdbDirectors, cast: [])
        }

        return nil
    }

    struct PersonCategorizedWorks {
        var directed: [MediaItem] = []
        var produced: [MediaItem] = []
        var acted: [MediaItem] = []

        var all: [MediaItem] {
            var seen = Set<String>()
            var combined: [MediaItem] = []
            for item in directed + acted + produced {
                if !seen.contains(item.id) {
                    seen.insert(item.id)
                    combined.append(item)
                }
            }
            return combined
        }
    }

    func fetchPersonCategorizedWorks(personID: Int) async -> PersonCategorizedWorks {
        guard let (data, _) = try? await executeRequest(endpoint: "/person/\(personID)/combined_credits") else {
            return PersonCategorizedWorks()
        }

        struct RawPersonCredits: Decodable {
            struct RawCreditItem: Decodable {
                let id: Int
                let title: String?
                let name: String?
                let overview: String?
                let poster_path: String?
                let backdrop_path: String?
                let media_type: String?
                let vote_average: Double?
                let vote_count: Int?
                let release_date: String?
                let first_air_date: String?
                let job: String?
                let character: String?
                let adult: Bool?
            }
            let cast: [RawCreditItem]?
            let crew: [RawCreditItem]?
        }

        guard let decoded = try? JSONDecoder().decode(RawPersonCredits.self, from: data) else {
            return PersonCategorizedWorks()
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let cleanCrew = (decoded.crew ?? []).filter { $0.adult != true }
        let cleanCast = (decoded.cast ?? []).filter { $0.adult != true }

        // 1. Filter directed works (strictly Director or Creator)
        let rawDirected = cleanCrew.filter { $0.job == "Director" || $0.job == "Creator" }

        // 2. Filter produced works (strictly Producer, Executive Producer, Co-Producer, etc.)
        let rawProduced = cleanCrew.filter {
            guard let job = $0.job else { return false }
            return (job.contains("Producer") || job == "Production") && job != "Director"
        }

        // 3. Filter acted works (exclude "Self", empty characters if other roles exist, etc.)
        let rawCast = cleanCast
        let legitCast = rawCast.filter {
            let char = ($0.character ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !char.isEmpty && char != "self" && char != "himself" && char != "herself"
        }
        let rawActed = legitCast.isEmpty ? rawCast : legitCast

        // Helper to deduplicate and take top items
        func deduplicateTop(_ items: [RawPersonCredits.RawCreditItem], limit: Int = 30) -> [RawPersonCredits.RawCreditItem] {
            var seen = Set<Int>()
            let sorted = items.sorted { ($0.vote_count ?? 0) > ($1.vote_count ?? 0) }
            var result: [RawPersonCredits.RawCreditItem] = []
            for item in sorted {
                if !seen.contains(item.id) {
                    seen.insert(item.id)
                    result.append(item)
                    if result.count >= limit { break }
                }
            }
            return result
        }

        let topDirected = deduplicateTop(rawDirected)
        let topProduced = deduplicateTop(rawProduced)
        let topActed = deduplicateTop(rawActed)

        // Collect all IDs and their media types to resolve IMDb IDs concurrently
        var allTopIDs: [Int] = []
        var idSet = Set<Int>()
        var idToType: [Int: MediaItem.MediaType] = [:]
        for list in [topDirected, topProduced, topActed] {
            for item in list {
                if !idSet.contains(item.id) {
                    idSet.insert(item.id)
                    allTopIDs.append(item.id)
                    idToType[item.id] = (item.media_type == "tv") ? .series : .movie
                }
            }
        }

        var imdbMap: [Int: String] = [:]
        await withTaskGroup(of: (Int, String?).self) { group in
            for tmdbID in allTopIDs.prefix(24) {
                let mType = idToType[tmdbID] ?? .movie
                group.addTask {
                    let imdb = await self.resolveIMDbID(tmdbID: tmdbID, type: mType)
                    return (tmdbID, imdb)
                }
            }
            for await (mID, imdb) in group {
                if let imdb = imdb { imdbMap[mID] = imdb }
            }
        }

        func mapToMediaItems(_ items: [RawPersonCredits.RawCreditItem]) -> [MediaItem] {
            return items.compactMap { res in
                let isTV = res.media_type == "tv"
                let title = res.title ?? res.name ?? "Untitled"
                let pURL = res.poster_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
                let bURL = res.backdrop_path.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
                let rawDate = res.release_date ?? res.first_air_date
                let date = rawDate.flatMap { df.date(from: $0) }
                let imdb = imdbMap[res.id]

                return MediaItem(
                    id: imdb ?? "\(res.id)",
                    title: title,
                    description: res.overview,
                    releaseDate: date,
                    rating: res.vote_average,
                    type: isTV ? .series : .movie,
                    imdbID: imdb,
                    posterURL: pURL,
                    backdropURL: bURL
                )
            }
        }

        return PersonCategorizedWorks(
            directed: mapToMediaItems(topDirected),
            produced: mapToMediaItems(topProduced),
            acted: mapToMediaItems(topActed)
        )
    }

    func fetchPersonWorks(personID: Int) async -> [MediaItem] {
        let cat = await fetchPersonCategorizedWorks(personID: personID)
        return cat.all
    }

    func resolveTMDBID(imdbID: String, type: MediaItem.MediaType) async -> String? {
        if let numeric = cleanNumericTMDBID(imdbID) {
            return numeric
        }
        guard imdbID.hasPrefix("tt") else { return nil }
        guard let (data, _) = try? await executeRequest(
            endpoint: "/find/\(imdbID)",
            queryItems: [URLQueryItem(name: "external_source", value: "imdb_id")]
        ) else { return nil }
        struct FindResponse: Decodable {
            struct FindItem: Decodable {
                let id: Int
            }
            let movie_results: [FindItem]?
            let tv_results: [FindItem]?
        }
        guard let res = try? JSONDecoder().decode(FindResponse.self, from: data) else { return nil }
        if type == .series {
            return res.tv_results?.first.map { "\($0.id)" }
        } else {
            return res.movie_results?.first.map { "\($0.id)" }
        }
    }

    func resolveIMDbID(tmdbID: Int, type: MediaItem.MediaType) async -> String? {
        if type == .series {
            return await resolveIMDbIDForTV(tmdbID: tmdbID)
        } else {
            return await resolveIMDbIDForMovie(tmdbID: tmdbID)
        }
    }

    private func resolveIMDbIDForMovie(tmdbID: Int) async -> String? {
        guard let (data, _) = try? await executeRequest(endpoint: "/movie/\(tmdbID)/external_ids") else { return nil }
        struct ExtResponse: Decodable {
            let imdb_id: String?
        }
        return (try? JSONDecoder().decode(ExtResponse.self, from: data))?.imdb_id
    }

    private func resolveIMDbIDForTV(tmdbID: Int) async -> String? {
        guard let (data, _) = try? await executeRequest(endpoint: "/tv/\(tmdbID)/external_ids") else { return nil }
        struct ExtResponse: Decodable {
            let imdb_id: String?
        }
        return (try? JSONDecoder().decode(ExtResponse.self, from: data))?.imdb_id
    }

    static func parseTitleAndYear(_ raw: String) -> (cleanTitle: String, year: Int?, subtitle: String?) {
        return TitleDisambiguationHelper.parseTitleAndYear(raw)
    }

    func resolveTMDBIDByTitle(title: String, type: MediaItem.MediaType, year: Int? = nil) async -> String? {
        let (clean, parsedYear, _) = TitleDisambiguationHelper.parseTitleAndYear(title)
        let effectiveYear = year ?? parsedYear
        let targetTitle = clean.isEmpty ? title.trimmingCharacters(in: .whitespacesAndNewlines) : clean
        guard !targetTitle.isEmpty else { return nil }

        func queryAndRank(withYear: Int?) async -> String? {
            var queryItems = [
                URLQueryItem(name: "query", value: targetTitle),
                URLQueryItem(name: "include_adult", value: "false")
            ]
            if let y = withYear {
                if type == .series {
                    queryItems.append(URLQueryItem(name: "first_air_date_year", value: "\(y)"))
                } else {
                    queryItems.append(URLQueryItem(name: "primary_release_year", value: "\(y)"))
                }
            }
            let endpoint = (type == .series) ? "/search/tv" : "/search/movie"
            guard let (data, _) = try? await executeRequest(endpoint: endpoint, queryItems: queryItems) else { return nil }

            struct Candidate: Decodable {
                let id: Int
                let name: String?
                let title: String?
                let original_name: String?
                let original_title: String?
                let first_air_date: String?
                let release_date: String?
                let vote_count: Int?
                let popularity: Double?
            }
            struct SearchResp: Decodable {
                let results: [Candidate]?
            }
            guard let candidates = (try? JSONDecoder().decode(SearchResp.self, from: data))?.results, !candidates.isEmpty else {
                return nil
            }

            let cleanLower = targetTitle.lowercased()
            let cleanHasColon = cleanLower.contains(":")

            let scored = candidates.compactMap { cand -> (Candidate, Double)? in
                let candTitle = (cand.name ?? cand.title ?? cand.original_name ?? cand.original_title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !candTitle.isEmpty else { return nil }
                let candLower = candTitle.lowercased()

                var score: Double = 0.0

                let spinOffWords = ["resurrection", "resurrected", "original sin", "new blood", "origins", "origin", "reboot", "remake"]
                let hasExtraSpinoff = spinOffWords.contains { kw in candLower.contains(kw) && !cleanLower.contains(kw) }

                // 1. Exact Title Equality
                if candLower == cleanLower {
                    score += 10000.0
                } else if (!cleanHasColon && candLower.contains(":")) || hasExtraSpinoff {
                    // Queried base title (e.g. "Dexter") but candidate is a spin-off/subtitle (e.g. "Dexter: Resurrection", "Dexter Original Sin")
                    score -= 50000.0
                } else if candLower.hasPrefix(cleanLower) {
                    score += 500.0
                } else {
                    score -= 5000.0
                }

                // 2. Year Matching
                let rawDate = cand.first_air_date ?? cand.release_date
                var candYear: Int? = nil
                if let rd = rawDate, rd.count >= 4, let y = Int(rd.prefix(4)) {
                    candYear = y
                }

                if let ey = effectiveYear, let cy = candYear {
                    if cy == ey {
                        score += 20000.0
                    } else if abs(cy - ey) == 1 {
                        score += 3000.0
                    } else if abs(cy - ey) >= 2 {
                        score -= 50000.0
                    }
                }

                // 3. Vote count & Popularity
                let vc = cand.vote_count ?? 0
                score += min(Double(vc) / 5.0, 500.0)
                let pop = cand.popularity ?? 0.0
                score += min(pop, 100.0)

                return (cand, score)
            }.sorted { $0.1 > $1.1 }

            if let best = scored.first, best.1 > 0 {
                return "\(best.0.id)"
            }
            return nil
        }

        // First attempt with year (if specified)
        if let y = effectiveYear {
            if let found = await queryAndRank(withYear: y) {
                return found
            }
        }

        // Fallback without year query parameter, but still applying cautious scoring
        return await queryAndRank(withYear: nil)
    }

    func resolveIMDbIDByTitle(title: String, type: MediaItem.MediaType, year: Int? = nil) async -> String? {
        if let tmdbID = await resolveTMDBIDByTitle(title: title, type: type, year: year), let intID = Int(tmdbID) {
            return await resolveIMDbID(tmdbID: intID, type: type)
        }
        return nil
    }
}
