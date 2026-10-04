import Foundation

struct AggregatedLink: Identifiable, Codable {
    let id: String
    let title: String
    let rawTitle: String
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

    init(id: String = UUID().uuidString, title: String, rawTitle: String, url: URL?, infoHash: String?, quality: String, resolutionBadge: String, hdrTag: String?, audioTag: String?, codecTag: String?, source: String, score: Int, isCached: Bool, isBestInCategory: Bool = false) {
        self.id = id
        self.title = title
        self.rawTitle = rawTitle
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
    }

    static func cleanQuality(from title: String) -> String {
        let upper = title.uppercased()
        if upper.contains("2160P") || upper.contains("4K") || upper.contains("UHD") { return "4K" }
        if upper.contains("1080P") || upper.contains("FHD") { return "FHD" }
        if upper.contains("720P") || upper.contains("HD") { return "HD" }
        return "SD"
    }

    static func checkIsCached(url: URL?, title: String) -> Bool {
        let upper = title.uppercased()
        if upper.contains("[RD+]") || upper.contains("RD+") || upper.contains("⚡") || upper.contains("REALDEBRID") || upper.contains("CACHED") {
            return true
        }
        if let urlStr = url?.absoluteString.lowercased() {
            if urlStr.contains("realdebrid") || urlStr.contains("strem.fun") || urlStr.contains("stremthru") || urlStr.contains("comet") || urlStr.contains("elfhosted") {
                return true
            }
        }
        return true
    }
}

struct StreamParser {
    static func parse(rawTitle: String, source: String, url: URL?, infoHash: String?) -> AggregatedLink? {
        let upper = rawTitle.uppercased()

        // 0. Filter out invalid addon configuration error messages
        let invalidKeywords = ["CONFIGURATION IS INVALID", "FAULTY MEDIAFUSION", "DELETE ONLY THE FAULTY", "INVALID ADD-ON", "RECONFIGURE IT", "ERROR.MP4"]
        for bad in invalidKeywords {
            if upper.contains(bad) {
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

        if upper.contains("2160P") || upper.contains("4K") || upper.contains("UHD") {
            quality = "4K"
            if upper.contains("REMUX") {
                resBadge = "4K Remux"
                baseScore = 100
            } else if upper.contains("BLURAY") || upper.contains("BDREMUX") {
                resBadge = "4K BluRay"
                baseScore = 90
            } else if upper.contains("WEB-DL") || upper.contains("WEBDL") {
                resBadge = "4K Web-DL"
                baseScore = 80
            } else {
                resBadge = "4K UHD"
                baseScore = 75
            }
        } else if upper.contains("1080P") || upper.contains("FHD") {
            quality = "FHD"
            if upper.contains("REMUX") {
                resBadge = "1080p Remux"
                baseScore = 70
            } else if upper.contains("BLURAY") || upper.contains("BDRIP") {
                resBadge = "1080p BluRay"
                baseScore = 65
            } else if upper.contains("WEB-DL") || upper.contains("WEBDL") {
                resBadge = "1080p Web-DL"
                baseScore = 60
            } else {
                resBadge = "1080p FHD"
                baseScore = 55
            }
        } else if upper.contains("720P") || upper.contains("HD") {
            quality = "HD"
            resBadge = "720p HD"
            baseScore = 30
        }

        // 3. HDR / Dolby Vision Tag
        var hdrTag: String? = nil
        if upper.contains("DV") || upper.contains("DOLBY VISION") || upper.contains("DOLBY-VISION") {
            hdrTag = "Dolby Vision"
            baseScore += 12
        } else if upper.contains("HDR10+") || upper.contains("HDR10PLUS") {
            hdrTag = "HDR10+"
            baseScore += 10
        } else if upper.contains("HDR") {
            hdrTag = "HDR10"
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
        } else if upper.contains("5.1") {
            audioTag = "5.1 Surround"
            baseScore += 4
        } else if upper.contains("7.1") {
            audioTag = "7.1 Surround"
            baseScore += 5
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

        // Construct magnet URL if URL is nil and infoHash is present
        var finalURL = url
        if finalURL == nil, let hash = infoHash, !hash.isEmpty {
            let encodedTitle = rawTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            finalURL = URL(string: "magnet:?xt=urn:btih:\(hash)&dn=\(encodedTitle)")
        }

        // 6. Check RealDebrid Cached
        let isCached = AggregatedLink.checkIsCached(url: finalURL, title: rawTitle)
        if isCached {
            baseScore += 40
        }

        // 7. Clean title
        let clean = cleanTorrentTitle(rawTitle)

        return AggregatedLink(
            title: clean,
            rawTitle: rawTitle,
            url: finalURL,
            infoHash: infoHash,
            quality: quality,
            resolutionBadge: resBadge,
            hdrTag: hdrTag,
            audioTag: audioTag,
            codecTag: codecTag,
            source: source,
            score: baseScore,
            isCached: isCached
        )
    }

    private static func cleanTorrentTitle(_ title: String) -> String {
        var result = title
        result = result.replacingOccurrences(of: ".", with: " ")
        result = result.replacingOccurrences(of: "_", with: " ")

        let components = result.components(separatedBy: " ")
        var cleanedWords: [String] = []

        let stopWords: Set<String> = [
            "2160p", "1080p", "720p", "480p", "4k", "uhd", "fhd", "hdr", "bluray", "remux",
            "web-dl", "webdl", "webrip", "x265", "x264", "hevc", "avc", "dts", "atmos",
            "truehd", "aac", "dual", "multi", "rd+", "realdebrid", "torrentio", "comet"
        ]

        for word in components {
            let lower = word.lowercased()
            if stopWords.contains(lower) {
                break
            }
            cleanedWords.append(word)
        }

        let cleaned = cleanedWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? title : cleaned
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

    var posterUrl: URL? { posterURL }
    var backdropUrl: URL? { backdropURL }

    enum MediaType: String, Codable {
        case movie
        case series
    }

    init(id: String, title: String, description: String?, posterUrl: URL? = nil, backdropUrl: URL? = nil, releaseDate: Date?, rating: Double?, type: MediaType, imdbID: String? = nil, posterURL: URL? = nil, backdropURL: URL? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.posterURL = posterURL ?? posterUrl
        self.backdropURL = backdropURL ?? backdropUrl
        self.releaseDate = releaseDate
        self.rating = rating
        self.type = type
        self.imdbID = imdbID
    }
}

struct Series: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let posterURL: URL?
    let backdropURL: URL?
    let releaseDate: Date?

    var posterUrl: URL? { posterURL }
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
        stillPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
    }
}
