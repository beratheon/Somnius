import Foundation

struct MediaItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String?
    let posterUrl: URL?
    let backdropUrl: URL?
    let releaseDate: Date?
    let rating: Double?
    let type: MediaType
    let imdbID: String?

    enum MediaType: String, Codable {
        case movie
        case series
    }

    init(id: String, title: String, description: String?, posterUrl: URL?, backdropUrl: URL?, releaseDate: Date?, rating: Double?, type: MediaType, imdbID: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.posterUrl = posterUrl
        self.backdropUrl = backdropUrl
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
    let posterUrl: URL?
    let backdropUrl: URL?
    let releaseDate: Date?
    let rating: Double?
    var seasons: [Season]

    enum MediaType: String, Codable {
        case series
    }
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
