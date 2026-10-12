import Foundation

struct AggregatedLink: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let rawTitle: String
    let fileName: String
    let url: URL?
    let infoHash: String?
    let quality: String
    let resolutionBadge: String
    let hdrTag: String?
    let audioTag: String?
    let codecTag: String?
    let source: String
    let score: Int
    var isCached: Bool
    var isBestInCategory: Bool = false
    let sizeString: String?
    let seeds: Int?
    let fileIdx: Int?
    let trackers: [String]?

    init(id: String = UUID().uuidString, title: String, rawTitle: String, fileName: String? = nil, url: URL?, infoHash: String?, quality: String, resolutionBadge: String, hdrTag: String?, audioTag: String?, codecTag: String?, source: String, score: Int, isCached: Bool, isBestInCategory: Bool = false, sizeString: String? = nil, seeds: Int? = nil, fileIdx: Int? = nil, trackers: [String]? = nil) {
        self.id = id
        self.title = title
        self.rawTitle = rawTitle
        self.fileName = fileName ?? title
        self.url = url
        self.infoHash = infoHash
        self.quality = quality
        self.resolutionBadge = resolutionBadge
        self.hdrTag = hdrTag
        self.audioTag = audioTag
        self.codecTag = codecTag
        self.source = source
        self.score = score
        self.isCached = isCached
        self.isBestInCategory = isBestInCategory
        self.sizeString = sizeString
        self.seeds = seeds
        self.fileIdx = fileIdx
        self.trackers = trackers
    }

    static func cleanQuality(from title: String) -> String {
        let upper = title.uppercased()
        if upper.contains("2160P") || upper.contains("4K") || upper.contains("UHD") { return "4K" }
        if upper.contains("1080P") || upper.contains("FHD") { return "FHD" }
        if upper.contains("720P") || upper.contains("HD") { return "HD" }
        return "SD"
    }

    var sizeInGigabytes: Double? {
        guard let raw = sizeString?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if raw.contains("gb") || raw.contains("gib") {
            let numStr = raw.replacingOccurrences(of: "gib", with: "").replacingOccurrences(of: "gb", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(numStr)
        } else if raw.contains("mb") || raw.contains("mib") {
            let numStr = raw.replacingOccurrences(of: "mib", with: "").replacingOccurrences(of: "mb", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let mb = Double(numStr) { return mb / 1024.0 }
        } else if raw.contains("tb") || raw.contains("tib") {
            let numStr = raw.replacingOccurrences(of: "tib", with: "").replacingOccurrences(of: "tb", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let tb = Double(numStr) { return tb * 1024.0 }
        }
        return nil
    }

    static func checkIsCached(url: URL?, title: String) -> Bool {
        let upper = title.uppercased()

        // 1. Explicitly check for non-cached indicators first
        if upper.contains("DOWNLOAD") || upper.contains("[RD DOWNLOAD]") || upper.contains("[AD DOWNLOAD]") ||
           upper.contains("⏳") || upper.contains("0%") || upper.contains("DOWNLOADING") {
            return false
        }

        // 2. Check for positive cached badges from all supported debrid indexers
        if upper.contains("[RD+]") || upper.contains("RD+") ||
           upper.contains("[AD+]") || upper.contains("AD+") ||
           upper.contains("[PM+]") || upper.contains("[TB+]") ||
           upper.contains("⚡") || upper.contains("CACHED") ||
           upper.contains("INSTANT") {
            return true
        }

        // 3. Direct CDN link already un-restricted by RealDebrid
        if let host = url?.host?.lowercased(), host.contains("download.real-debrid.com") {
            return true
        }

        return false
    }

    public static func selectBestStream(from links: [AggregatedLink], preferredQuality: String? = nil, maxGbSize: Double? = nil) -> AggregatedLink? {
        guard !links.isEmpty else { return nil }

        let isDebrid = Config.isDebridMode
        let maxGb = maxGbSize ?? Config.autoPlayMaxGbSize

        // Filter out oversized files if configured
        var validLinks = links.filter { link in
            if maxGb > 0, let gb = link.sizeInGigabytes, gb > maxGb {
                return false
            }
            return true
        }
        if validLinks.isEmpty {
            validLinks = links
        }

        if isDebrid {
            // Debrid Mode: Cached reliable streams first!
            let cachedOnly = Config.autoPlayCachedOnly
            let cachedLinks = validLinks.filter { $0.isCached }
            let pool = (cachedOnly && !cachedLinks.isEmpty) ? cachedLinks : (cachedLinks.isEmpty ? validLinks : cachedLinks)

            let pref = (preferredQuality ?? Config.autoPlayPreferredQuality).lowercased()

            return pool.sorted { a, b in
                // 1. Cached stream status first
                if a.isCached != b.isCached {
                    return a.isCached && !b.isCached
                }

                // 2. User target quality match first (e.g. 1080p FHD vs 4K UHD)
                let aMatch = matchesQuality(a.quality, target: pref)
                let bMatch = matchesQuality(b.quality, target: pref)
                if aMatch != bMatch { return aMatch && !bMatch }

                // 3. Best quality rank (4K > FHD > HD > SD)
                let qA = qualityRankScore(a.quality)
                let qB = qualityRankScore(b.quality)
                if qA != qB { return qA > qB }

                // 4. Reliability Guard: Prefer stable, decent-sized streams (<= 35 GB) over 80GB bloated discs for instant autoplay
                let aSize = a.sizeInGigabytes ?? 0
                let bSize = b.sizeInGigabytes ?? 0
                let aReasonable = aSize > 0 && aSize <= 35.0
                let bReasonable = bSize > 0 && bSize <= 35.0
                if aReasonable != bReasonable {
                    return aReasonable && !bReasonable
                }

                // 5. Dolby Vision / HDR
                let aDV = a.hdrTag == "DV" || a.rawTitle.localizedCaseInsensitiveContains("dolby vision") || a.rawTitle.localizedCaseInsensitiveContains("dovi")
                let bDV = b.hdrTag == "DV" || b.rawTitle.localizedCaseInsensitiveContains("dolby vision") || b.rawTitle.localizedCaseInsensitiveContains("dovi")
                if aDV != bDV { return aDV && !bDV }

                let aHDR = a.hdrTag != nil
                let bHDR = b.hdrTag != nil
                if aHDR != bHDR { return aHDR && !bHDR }

                let sA = a.seeds ?? 0
                let sB = b.seeds ?? 0
                if sA != sB { return sA > sB }
                return a.score > b.score
            }.first
        } else {
            // Classic (Non-Debrid) Mode: Best quality first (4K > 1080p > 720p > SD), then most seeders!
            // Never pick 0-seeder streams when seeded streams exist.
            let tiers = ["4K", "FHD", "HD", "SD"]
            for tier in tiers {
                let tierLinks = validLinks.filter { matchesTier($0.quality, tier: tier) }
                // Only consider healthy streams with active seeders (>= 3 seeds)
                let healthy = tierLinks.filter { ($0.seeds ?? 0) >= 3 }
                if let best = healthy.max(by: { ($0.seeds ?? 0) < ($1.seeds ?? 0) }) {
                    return best
                }
            }

            // Fallback: If no tier has >= 3 seeds, pick the link with the highest seeders (> 0)
            let anySeeded = validLinks.filter { ($0.seeds ?? 0) > 0 }
            if let bestOverall = anySeeded.max(by: { ($0.seeds ?? 0) < ($1.seeds ?? 0) }) {
                return bestOverall
            }

            return validLinks.first
        }
    }

    private static func qualityRankScore(_ quality: String) -> Int {
        switch quality.uppercased() {
        case "4K": return 4000
        case "FHD", "1080P": return 3000
        case "HD", "720P": return 2000
        default: return 1000
        }
    }

    private static func matchesTier(_ quality: String, tier: String) -> Bool {
        let q = quality.uppercased()
        let t = tier.uppercased()
        if t == "4K" { return q == "4K" }
        if t == "FHD" { return q == "FHD" || q == "1080P" }
        if t == "HD" { return q == "HD" || q == "720P" }
        return q == "SD" || (q != "4K" && q != "FHD" && q != "HD")
    }

    private static func matchesQuality(_ quality: String, target: String) -> Bool {
        let q = quality.lowercased()
        let t = target.lowercased()
        if t == "4k" { return q == "4k" }
        if t == "1080p" { return q == "fhd" || q == "1080p" }
        if t == "720p" { return q == "hd" || q == "720p" }
        return q == t
    }

    var cleanDisplayTitle: String {
        var str = fileName
        // Strip video file extensions
        for ext in [".mkv", ".mp4", ".avi", ".ts", ".m4v", ".mov"] {
            if str.lowercased().hasSuffix(ext) {
                str = String(str.dropLast(ext.count))
            }
        }

        // Strip tracker / indexer / community tags in brackets
        if let regex = try? NSRegularExpression(pattern: #"(?i)\[(?:yts|tgx|rarbg|eztv|etrg|galaxyrg|psa|qxr|framestor|flux|glhf|torrent|p2p|rd\+|rd|rd☁️|rd🌩️|debrid|torrentio|comet|knightcrawler|mediafusion)[^\]]*\]"#, options: []) {
            str = regex.stringByReplacingMatches(in: str, options: [], range: NSRange(str.startIndex..., in: str), withTemplate: "")
        }

        // Strip release group suffixes (-YIFY, -SPARKS, -FraMeSToR, etc.)
        if let regex = try? NSRegularExpression(pattern: #"-[A-Za-z0-9_]+$"#, options: []) {
            str = regex.stringByReplacingMatches(in: str, options: [], range: NSRange(str.startIndex..., in: str), withTemplate: "")
        }

        // Strip torrent / peer keywords
        let bannedWords = ["torrent", "torrentio", "p2p", ".torrent", "magnet"]
        for bad in bannedWords {
            if let regex = try? NSRegularExpression(pattern: #"(?i)\b\#(bad)\b"#, options: []) {
                str = regex.stringByReplacingMatches(in: str, options: [], range: NSRange(str.startIndex..., in: str), withTemplate: "")
            }
        }

        // Replace underscores with spaces and collapse spaces
        str = str.replacingOccurrences(of: "_", with: " ")
        if let spaceRegex = try? NSRegularExpression(pattern: #"\s+"#, options: []) {
            str = spaceRegex.stringByReplacingMatches(in: str, options: [], range: NSRange(str.startIndex..., in: str), withTemplate: " ")
        }

        str = str.trimmingCharacters(in: CharacterSet(charactersIn: " -|/\\ \n\r\t[]()"))
        return str.isEmpty ? "Media Source (\(resolutionBadge))" : str
    }
}

struct StreamParser {
    static func parse(rawTitle: String, source: String, url: URL?, infoHash: String?, fileIdx: Int? = nil, trackers: [String]? = nil) -> AggregatedLink? {
        let upper = rawTitle.uppercased()

        // 0. Filter out invalid addon configuration error messages & failed access stubs
        let invalidKeywords = [
            "CONFIGURATION IS INVALID", "FAULTY MEDIAFUSION", "DELETE ONLY THE FAULTY",
            "INVALID ADD-ON", "RECONFIGURE IT", "ERROR.MP4", "INVALID REALDEBRID",
            "FAILED_ACCESS", "FAILED ACCESS", "INVALID MEDIAFUSION", "INVALID_CONFIG",
            "DELETE AND RECONFIGURE"
        ]
        for bad in invalidKeywords {
            if upper.contains(bad) {
                return nil
            }
        }
        if let uStr = url?.absoluteString.lowercased(), uStr.contains("failed_access") || uStr.contains("error.mp4") || uStr.contains("invalid_config") {
            return nil
        }

        // 0.1 Filter out Adult / NSFW / Porn releases
        let adultKeywords = [
            "XXX", "PORN", "EROTIC", "EROTICA", "FAMILYSTROKES", "MYDIRTYFAMILY",
            "MYPERVYFAMILY", "BRAZZERS", "BANGROS", "BANGBROS", "NAUGHTYAMERICA",
            "REALITYKINGS", "MOFOS", "BLACKED", "TUSHY", "VIXEN", "DEEPER",
            "FAKEHUB", "FAKETAXI", "PROPERTYSEX", "STEPSISTER", "STEPMOM",
            "STEP SIBLINGS", "SWAPPERS", "PURETABOO", "METART", "HENTAI",
            "JAV", "ONLYFANS", "PLAYBOY", "PENTHOUSE", "HUSTLER", "X-RATED",
            "ADULT", "DEVILS FILM", "EVIL ANGEL", "DIGITAL PLAYGROUND",
            "PRIVATE COM", "KINK.COM", "SWEET SINNER", "HARDX", "MILE HIGH"
        ]
        for adult in adultKeywords {
            if upper.contains(adult) {
                // False positive safeguards for legitimate titles
                if adult == "ADULT" && (upper.contains("ADULT SWIM") || upper.contains("ADULTHOOD")) {
                    continue
                }
                if adult == "XXX" && (upper.contains("XANDER") || upper.contains("VIN DIESEL") || upper.contains("STATE OF THE UNION") || upper.contains("XXX.2002") || upper.contains("XXX 2002") || upper.contains("XXX (2002)")) {
                    continue
                }
                return nil
            }
        }

        // 1. Filter out actual trash releases (CAM, HDCAM, TELESYNC, WORKPRINT, SAMPLE, .EXE, TRAILER)
        let trashKeywords = ["CAMRIP", "HDCAM", " CAM ", ".CAM.", "[CAM]", "TELESYNC", "TS-RIP", " WORKPRINT ", " SAMPLE ", ".EXE", "TRAILER"]
        for trash in trashKeywords {
            if upper.contains(trash) {
                return nil
            }
        }

        // 2. Resolution & Source Type
        var quality = "SD"
        var resBadge = "SD"
        var baseScore = 10

        let has2160 = upper.contains("2160P") || upper.contains("2160 ") || upper.contains(".2160.") || upper.contains("4K")
        let has1080 = upper.contains("1080P") || upper.contains("1080I") || upper.contains("1080 ") || upper.contains(".1080.") || upper.contains("FHD")
        let has720 = upper.contains("720P") || upper.contains(".720.") || upper.contains(" 720 ") || upper.contains("HD")

        if has2160 && !has1080 {
            quality = "4K"
            resBadge = "UHD"
            baseScore = upper.contains("REMUX") ? 100 : (upper.contains("BLURAY") ? 90 : 80)
        } else if has1080 {
            quality = "FHD"
            resBadge = "FHD"
            baseScore = upper.contains("REMUX") ? 70 : (upper.contains("BLURAY") ? 65 : 55)
        } else if upper.contains("UHD") && !has1080 && !has720 {
            quality = "4K"
            resBadge = "UHD"
            baseScore = 80
        } else if has720 {
            quality = "HD"
            resBadge = "HD"
            baseScore = 30
        }

        // Apply User Preferred Stream Quality Weighting
        if Config.preferredStreamQuality == "1080p" {
            if quality == "FHD" { baseScore += 50 }
        } else if Config.preferredStreamQuality == "720p" {
            if quality == "HD" { baseScore += 80 }
        } else {
            // Default: 4K priority
            if quality == "4K" { baseScore += 20 }
        }

        // 3. HDR / Dolby Vision Tag (Carefully exclude DVD, DVD9, DVDRip, DVB)
        var hdrTag: String? = nil
        let isDolbyVision = upper.contains("DOLBY VISION") ||
                            upper.contains("DOLBY-VISION") ||
                            upper.contains("DOVI") ||
                            rawTitle.range(of: #"(?<![a-zA-Z0-9])DV(?![a-zA-Z0-9])"#, options: .regularExpression) != nil

        if isDolbyVision {
            hdrTag = "DV"
            baseScore += 12
        } else if upper.contains("HDR10+") || upper.contains("HDR10PLUS") {
            hdrTag = "HDR10+"
            baseScore += 10
        } else if upper.contains("HDR10") {
            hdrTag = "HDR10"
            baseScore += 8
        } else if upper.contains("HDR") {
            hdrTag = "HDR"
            baseScore += 6
        }

        // 4. Audio Tag
        var audioTag: String? = nil
        if upper.contains("ATMOS") {
            audioTag = "Dolby Atmos"
            baseScore += 10
        } else if upper.contains("TRUEHD") {
            audioTag = "TrueHD 7.1"
            baseScore += 8
        } else if upper.contains("DTS-HD") || upper.contains("DTS-X") {
            audioTag = "DTS-HD MA"
            baseScore += 8
        } else if upper.contains("DTS") {
            audioTag = "DTS 5.1"
            baseScore += 5
        } else if upper.contains("DDP") || upper.contains("EAC3") || upper.contains("E-AC-3") || upper.contains("E-AC3") {
            audioTag = "Dolby Digital+ 5.1"
            baseScore += 5
        } else if upper.contains("FLAC") {
            audioTag = "Lossless FLAC"
            baseScore += 6
        } else if upper.contains("5.1") {
            audioTag = "5.1 Surround"
            baseScore += 4
        } else if upper.contains("7.1") {
            audioTag = "7.1 Surround"
            baseScore += 5
        } else if upper.contains("AAC") {
            audioTag = "AAC Stereo"
        }

        // 5. Codec Tag
        var codecTag: String? = nil
        if upper.contains("X265") || upper.contains("HEVC") || upper.contains("H.265") || upper.contains("H265") {
            codecTag = "HEVC x265"
            baseScore += 5
        } else if upper.contains("AV1") {
            codecTag = "AV1"
            baseScore += 5
        } else if upper.contains("X264") || upper.contains("H.264") || upper.contains("H264") {
            codecTag = "AVC x264"
        }

        // 6. Extract File Size if present
        let sizeString = extractSizeString(from: rawTitle)

        // Construct magnet URL if URL is nil and infoHash is present
        var finalURL = url
        if finalURL == nil, let hash = infoHash, !hash.isEmpty {
            let encodedTitle = rawTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            finalURL = URL(string: "magnet:?xt=urn:btih:\(hash)&dn=\(encodedTitle)")
        }

        // 7. Check RealDebrid Cached
        let isCached = AggregatedLink.checkIsCached(url: finalURL, title: rawTitle)
        if isCached {
            baseScore += 40
        }

        // 8. Extract real file name and seeds
        let cleanFile = extractFileName(from: rawTitle)
        let seeds = extractSeeds(from: rawTitle)

        // Seed bonus for non-debrid fast peers
        if let s = seeds, s > 0 {
            baseScore += min(30, s / 5)
        }

        return AggregatedLink(
            title: cleanFile,
            rawTitle: rawTitle,
            fileName: cleanFile,
            url: finalURL,
            infoHash: infoHash,
            quality: quality,
            resolutionBadge: resBadge,
            hdrTag: hdrTag,
            audioTag: audioTag,
            codecTag: codecTag,
            source: source,
            score: baseScore,
            isCached: isCached,
            sizeString: sizeString,
            seeds: seeds,
            fileIdx: fileIdx,
            trackers: trackers
        )
    }

    private static func extractSizeString(from title: String) -> String? {
        let pattern = #"(\d+(?:\.\d+)?\s*(?:GB|GIB|MB|MIB|TB|TIB))\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }
        return String(title[range]).uppercased()
    }

    private static func extractSeeds(from rawTitle: String) -> Int? {
        // Priority 1: Match 👤 or 👥 bust emoji (Stremio standard: Torrentio, Comet, Mediafusion, Knightcrawler)
        if let bustRange = rawTitle.range(of: #"(?:👤|👥)\s*(\d+)"#, options: .regularExpression) {
            let matchedStr = String(rawTitle[bustRange])
            let digits = matchedStr.filter { $0.isNumber }
            if let num = Int(digits) { return num }
        }

        // Priority 2: Match explicit seeds / seeders / peers keywords (avoiding false matches like [1080p] or [2024])
        let pattern = #"(?:\b(?:seeds?|seeders?|peers?)\s*[:/]\s*|\bS:\s*)(\d+)|\b(\d+)\s*(?:seeds?|seeders?|peers?)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: rawTitle, range: NSRange(rawTitle.startIndex..., in: rawTitle)) {
            if match.range(at: 1).location != NSNotFound, let range = Range(match.range(at: 1), in: rawTitle) {
                return Int(rawTitle[range])
            }
            if match.range(at: 2).location != NSNotFound, let range = Range(match.range(at: 2), in: rawTitle) {
                return Int(rawTitle[range])
            }
        }
        return nil
    }

    private static func extractFileName(from rawTitle: String) -> String {
        let lines = rawTitle.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let providerKeywords = ["torrentio", "comet", "knightcrawler", "mediafusion", "zilean", "cyberflix", "piratebay", "stremio", "elfhosted", "strem.fun"]
        let releaseKeywords = ["2160p", "1080p", "720p", "480p", "remux", "bluray", "bdrip", "web-dl", "webdl", "webrip", "hevc", "x265", "x264", "h.264", "h.265", "dvdrip"]

        // 1. Look for line with video file extension (.mkv, .mp4, .avi, .ts)
        for line in lines {
            let lower = line.lowercased()
            if lower.contains(".mkv") || lower.contains(".mp4") || lower.contains(".avi") || lower.contains(".ts") {
                return cleanRawLine(line)
            }
        }

        // 2. Look for line with typical release resolution/codec keywords
        for line in lines {
            let lower = line.lowercased()
            let isAddonOnly = providerKeywords.contains { lower.contains($0) } && !releaseKeywords.contains { lower.contains($0) }
            let isShortRes = lower == "4k" || lower == "1080p" || lower == "720p" || lower == "uhd" || lower == "fhd" || lower == "sd"
            let isStatsOnly = lower.contains("💾") || lower.contains("👤") || lower.hasPrefix("seeds:") || lower.hasPrefix("peers:")

            if !isAddonOnly && !isShortRes && !isStatsOnly {
                if releaseKeywords.contains(where: { lower.contains($0) }) {
                    return cleanRawLine(line)
                }
            }
        }

        // 3. Fallback: longest candidate line that doesn't start with emoji or pure addon header
        let candidates = lines.filter { line in
            let lower = line.lowercased()
            return !lower.contains("💾") && !lower.contains("👤") && !providerKeywords.contains(where: { lower == $0 || lower == "[\($0)]" })
        }

        if let best = candidates.max(by: { $0.count < $1.count }) {
            return cleanRawLine(best)
        }

        return cleanRawLine(rawTitle)
    }

    private static func cleanRawLine(_ line: String) -> String {
        var str = line
        let prefixesToRemove = [
            "[RD+] Torrentio", "[RD+] Comet", "[RD+] Knightcrawler", "[RD+] Cyberflix", "[RD+] MediaFusion",
            "[RD☁️] Meteor", "[RD🌩️] Meteor", "[P2P☁️] Meteor", "[P2P🌩️] Meteor",
            "[Torrentio]", "[Comet]", "[Knightcrawler]", "[Cyberflix]", "[MediaFusion]", "[Meteor]", "[Knaben]", "[Storz]", "[StremThru]",
            "Torrentio", "Comet", "Knightcrawler", "Cyberflix", "MediaFusion", "Meteor", "Knaben", "Storz", "StremThru", "PirateBay",
            "[Torrent]", "Torrent:", "Torrent", "[P2P]", "P2P:", "P2P"
        ]
        for p in prefixesToRemove {
            if str.hasPrefix(p) {
                str = String(str.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return str.trimmingCharacters(in: CharacterSet(charactersIn: " -|/\\ \n\r\t"))
    }
}

struct MediaItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String?
    let posterURL: URL?
    let backdropURL: URL?
    let releaseDate: Date?
    let rating: Double?
    let type: MediaType
    let imdbID: String?
    let voteCount: Int?

    var resolvedIMDbID: String? {
        if let imdb = imdbID, imdb.hasPrefix("tt") { return imdb }
        if id.hasPrefix("tt") { return id }
        if let pStr = posterURL?.absoluteString, let range = pStr.range(of: "tt\\d{7,8}", options: .regularExpression) {
            return String(pStr[range])
        }
        return nil
    }

    var initialLogoURL: URL? {
        if let imdb = resolvedIMDbID, !imdb.isEmpty {
            return URL(string: "https://images.metahub.space/logo/medium/\(imdb)/img.png")
        }
        return nil
    }

    var posterUrl: URL? {
        if let imdb = resolvedIMDbID, !imdb.isEmpty {
            return URL(string: "https://btttr.cc/poster-rq/imdb/poster-default/\(imdb).jpg?rs=IM")
        }
        if let pURL = posterURL {
            let pStr = pURL.absoluteString
            if pStr.contains("btttr.cc/poster/") {
                let updated = pStr.replacingOccurrences(of: "btttr.cc/poster/", with: "btttr.cc/poster-rq/").replacingOccurrences(of: "?tag=none", with: "?rs=IM")
                return URL(string: updated)
            }
            return pURL
        }
        return nil
    }
    var backdropUrl: URL? {
        if let bURL = backdropURL {
            let str = bURL.absoluteString
            if str.contains("image.tmdb.org/t/p/w1280") {
                return URL(string: str.replacingOccurrences(of: "/t/p/w1280", with: "/t/p/original"))
            } else if str.contains("image.tmdb.org/t/p/w500") {
                return URL(string: str.replacingOccurrences(of: "/t/p/w500", with: "/t/p/original"))
            }
            return bURL
        }
        if let imdb = resolvedIMDbID, !imdb.isEmpty {
            return URL(string: "https://images.metahub.space/background/original/\(imdb)/img.jpg")
        }
        return nil
    }

    enum MediaType: String, Codable {
        case movie
        case series
    }

    init(id: String, title: String, description: String?, posterUrl: URL? = nil, backdropUrl: URL? = nil, releaseDate: Date?, rating: Double?, type: MediaType, imdbID: String? = nil, posterURL: URL? = nil, backdropURL: URL? = nil, voteCount: Int? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.posterURL = posterURL ?? posterUrl
        self.backdropURL = backdropURL ?? backdropUrl
        self.releaseDate = releaseDate
        self.rating = rating
        self.type = type
        self.imdbID = imdbID
        self.voteCount = voteCount
    }
}

struct Series: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let posterURL: URL?
    let backdropURL: URL?
    let releaseDate: Date?

    var posterUrl: URL? {
        if id.hasPrefix("tt") {
            return URL(string: "https://btttr.cc/poster-rq/imdb/poster-default/\(id).jpg?rs=IM")
        }
        if let pURL = posterURL {
            let pStr = pURL.absoluteString
            if let range = pStr.range(of: "tt\\d{7,8}", options: .regularExpression) {
                let imdb = String(pStr[range])
                return URL(string: "https://btttr.cc/poster-rq/imdb/poster-default/\(imdb).jpg?rs=IM")
            }
            if pStr.contains("btttr.cc/poster/") {
                let updated = pStr.replacingOccurrences(of: "btttr.cc/poster/", with: "btttr.cc/poster-rq/").replacingOccurrences(of: "?tag=none", with: "?rs=IM")
                return URL(string: updated)
            }
            return pURL
        }
        return nil
    }
    var backdropUrl: URL? { backdropURL }
}

struct Season: Identifiable, Codable {
    let id: String
    let seasonNumber: Int
    var episodes: [Episode]
}

struct Episode: Identifiable, Codable {
    let id: String
    let episodeNumber: Int
    let title: String
    let description: String?
    let duration: TimeInterval?
    var streamLinks: [StreamLink]?
}

struct StreamLink: Codable {
    let id: String
    let url: URL
    let quality: String
    let codec: String?
}

struct RealDebridUser: Codable {
    let id: Int
    let username: String
    let email: String?
    let points: Int?
    let type: String // "premium" or "free"
    let expiration: String?
}

struct RealDebridTorrentItem: Identifiable, Codable {
    let id: String
    let filename: String
    let hash: String
    let bytes: Int64?
    let status: String
    let progress: Double?
    let links: [String]?
    let ended: String?
}

struct TVEpisodeItem: Identifiable, Codable {
    let id: Int
    let episodeNumber: Int
    let name: String
    let overview: String?
    let stillPath: String?
    let voteAverage: Double?
    let runtime: Int?

    var stillURL: URL? {
        guard let path = stillPath, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

// MARK: - Cast, Crew & Credits Models
struct CastMember: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?

    var profileURL: URL? {
        guard let path = profilePath, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: "https://image.tmdb.org/t/p/w300\(path)")
    }
}

struct CrewMember: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?

    var profileURL: URL? {
        guard let path = profilePath, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: "https://image.tmdb.org/t/p/w300\(path)")
    }
}

struct MediaCredits: Codable {
    let directors: [CrewMember]
    let cast: [CastMember]
}
