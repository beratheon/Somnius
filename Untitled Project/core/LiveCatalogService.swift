import Foundation
import Combine

// MARK: - Live Catalog Model
struct LiveCatalog: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let type: String // "movie" or "series"
    let endpointPath: String?
    let mergedSources: [String]?
    let category: String
    var items: [MediaItem]
    var lastUpdated: Date?
    var isEnabled: Bool

    init(id: String, name: String, type: String, endpointPath: String? = nil, mergedSources: [String]? = nil, category: String, items: [MediaItem] = [], lastUpdated: Date? = nil, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.type = type
        self.endpointPath = endpointPath
        self.mergedSources = mergedSources
        self.category = category
        self.items = items
        self.lastUpdated = lastUpdated
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, endpointPath, mergedSources, category, items, lastUpdated, isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.endpointPath = try container.decodeIfPresent(String.self, forKey: .endpointPath)
        self.mergedSources = try container.decodeIfPresent([String].self, forKey: .mergedSources)
        self.category = try container.decode(String.self, forKey: .category)
        self.items = (try? container.decode([MediaItem].self, forKey: .items)) ?? []
        self.lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        self.isEnabled = (try? container.decode(Bool.self, forKey: .isEnabled)) ?? true
    }

    static func == (lhs: LiveCatalog, rhs: LiveCatalog) -> Bool {
        lhs.id == rhs.id && lhs.items.count == rhs.items.count && lhs.lastUpdated == rhs.lastUpdated && lhs.isEnabled == rhs.isEnabled
    }
}

// MARK: - Stremio / BetterPosters Meta Models
struct StremioCatalogResponse: Codable {
    let metas: [StremioMetaItem]?
}

struct StremioMetaItem: Codable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let thumbnail: String?
    let logo: String?
    let description: String?
    let releaseInfo: String?
    let year: String?
    let imdbRating: String?
    let genres: [String]?

    enum CodingKeys: String, CodingKey {
        case id, type, name, poster, background, thumbnail, logo, description, releaseInfo, year, imdbRating, genres
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = (try? container.decode(String.self, forKey: .type)) ?? "movie"
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        self.poster = try? container.decodeIfPresent(String.self, forKey: .poster)
        self.background = try? container.decodeIfPresent(String.self, forKey: .background)
        self.thumbnail = try? container.decodeIfPresent(String.self, forKey: .thumbnail)
        self.logo = try? container.decodeIfPresent(String.self, forKey: .logo)
        self.description = try? container.decodeIfPresent(String.self, forKey: .description)
        self.genres = try? container.decodeIfPresent([String].self, forKey: .genres)

        // Flexible releaseInfo
        if let relStr = try? container.decodeIfPresent(String.self, forKey: .releaseInfo) {
            self.releaseInfo = relStr
        } else if let relInt = try? container.decodeIfPresent(Int.self, forKey: .releaseInfo) {
            self.releaseInfo = String(relInt)
        } else {
            self.releaseInfo = nil
        }

        // Flexible year (can be Int or String)
        if let yStr = try? container.decodeIfPresent(String.self, forKey: .year) {
            self.year = yStr
        } else if let yInt = try? container.decodeIfPresent(Int.self, forKey: .year) {
            self.year = String(yInt)
        } else {
            self.year = nil
        }

        // Flexible imdbRating (can be Double, Float, Int, or String)
        if let rStr = try? container.decodeIfPresent(String.self, forKey: .imdbRating) {
            self.imdbRating = rStr
        } else if let rDouble = try? container.decodeIfPresent(Double.self, forKey: .imdbRating) {
            self.imdbRating = String(format: "%.1f", rDouble)
        } else if let rInt = try? container.decodeIfPresent(Int.self, forKey: .imdbRating) {
            self.imdbRating = String(rInt)
        } else {
            self.imdbRating = nil
        }
    }

    func toMediaItem() -> MediaItem {
        let cleanYear = year ?? releaseInfo ?? ""
        var relDate: Date? = nil
        if let y = Int(cleanYear.prefix(4)) {
            var comps = DateComponents()
            comps.year = y
            comps.month = 1
            comps.day = 1
            relDate = Calendar.current.date(from: comps)
        }

        let pUrl = poster.flatMap { URL(string: $0) }
        let bgUrl = (background ?? thumbnail).flatMap { URL(string: $0) }
        let rat = imdbRating.flatMap { Double($0) }
        let mType: MediaItem.MediaType = (type.lowercased() == "series") ? .series : .movie
        let imdbId = id.hasPrefix("tt") ? id : nil

        return MediaItem(
            id: id,
            title: name,
            description: description,
            releaseDate: relDate,
            rating: rat,
            type: mType,
            imdbID: imdbId,
            posterURL: pUrl,
            backdropURL: bgUrl
        )
    }
}

// MARK: - Live Catalog Synchronization Service
@MainActor
class LiveCatalogService: ObservableObject {
    static let shared = LiveCatalogService()

    private let baseURL = "https://btttr.cc/rVttc9u4Ef4rGH-4l2k4ISmJkvxNduJL2jjx-OUyN51OB5YgizVF6vjiVL25_94FQJogFgSgtN_k5T6L3cViASzWf5ytaU2z4qk6O__7WUZrVtXB_uxN97OCn3WxoUdBlL84bV3s0_xJENufgrNk-aajv_7BvxyKQ5PRUnzofkvZB8FKn-vg0Dye_6up6jQPgnS_eQzgY1CCHptgX7ykrPLhrF-Cald8G_I-snxb0vw544BHYWKab7bN-nnIt6aHmqZ5Tg802wdBFIZR8FSy1itCh6DYBjTLgjrdswE2S6vdNFwEQV02LFiX8D3YFOtmz_KaluA1VnL4Ns32A9w_KcvZngZyoG6UY9EEe_D1jr6wIGcvrAx2jJYbGN5iGa3AA0UeUKlEVRflUTMwXxf5Ni3BumrX1EFzCGi-Cb7Rer0bcG7TDcuC9WMQ0HgKX8DLYKH8FkdLRJpGoUaKwmixiDTiJFwkWNrMBI0xVCfF8USXNgmXE0zSdQNZC8w1G3igygv6HATtQqCHQ8Z4dBlCcYQTx-GQMWf1Nkv_7ZbYMboE0j39D8z-QcSeU-qA2yUa1ksqI9jC5BJSQUqgMm-MKtccutQiF0K948uvtIndPRawVjz82DGO6tnmN5DEg6JLWVIRWGCgS9BUfIHx5IPXjE2KGPN_FdKloDwoi7pmIKzY07owG21Rw09A67VNWuXs6PZuy2dx7sFjbQy4xscUbH7hjlitYzutVZisgtxRqXJ1oobZLUQJL4lw3lrMMWmJsxtOxSiLAwnl0yjUszOQDFxIiShEqkZokwAS0iuKUOqPYgMJ5fkI7VRAwtrHSPtJgoGh7sJ5PEVsnKYPwGn6CJymO4jTdA9xmmHcue42TtP9BjQ0x0vYDfUxOE0fA2hTA3aq28tpur2cptvLaYYxZrodnKb7ZTmJIxMN2TGJZ0gXoCFdgIbkzaZTPaI4TQ-pZRJiHwANjZtESzRGgtfvMkkS5AOgId8nC-wroOl8cELFhkRREqEIFERdRVhDcYQ4Y8MECKI-A4KoTzMnxugsyIlIeU5EynOiPg2CqM-DIKKTIyeaLIpNFsUmi2KTRROTRROTRRPDQJMZHggCAXMCEXFOl3O01gURBRdEA1p0cJRGgQQ0FKxRHKGgjmIc1EDD7l2EMzyPQERqJ_MJSu4gEk04p6H55mBEjJIQZThBNFloGAZtPwvIjrqKQENeXCQ47XGa7sVFkqCA5DQTn24Ip-HAW4QotwpvI85ZOJ-iGAOiIewXOKcJommuYxy3QETpOTJkkRBSNprCSRjN8Mws0D2O0xAYcrYhscwh-SI0jGOg4dUxwWkbaFibSYi2BljqyOZpEiLGaBLNIRv_A6ispmfnfyinQ3sJBFhzumdn52cfr99dnJP74kBuOQO5fj1owsfHsz_fuGW-HsTHpd7_Su66Yy6Wayus9DIv4AO5VisuWNKppZdeOmclv7SsrRdIsSWrLCP3bZUGj5edUK7px7oHZnLJmcm7npncCWbyA7lqqzt4vNPLPP2owrjOst-KhlzTI_kAEPKZQ8gHDiFftj5zZCwRKVPFv5MiJ5Tc3z68J3f3X25_G5sxWy2pF3kH38jD4Q1Z5RvytbvvYnnDilOPX4md4BWgLiNRiOo5P8kQ0EK2Qiheq-pRH4qyLMrOvT_1oX9VFnsSwXGP1AWsCLhN_9yK3Osi21qXEiggJZ6Fr1JTWFajaFEUUxS6-OIwgFfMev7LYs82R6sB914GxAYDhCJD_ZE-ojLXQz_LcpXDBl66Gw7XL916x8g3xp7HHQabAx5wkAFNIHXa34k7_F_sWoo6oRKKooxAbkQCcAAHU9QNhjUcrc5pNRAU5SvOALGuCX30EqpnfSTTkvOtRUwk0jg3XhJHdDRFl91oQ5kIW67OrL-uhrqSXbS31krBFUm8HhRjXZJG1PLWBFVtsaiOw8dzowXeXuxDy9KntJbnZx99tcIb0pan12t6SkQOi3SjAt0e_Y76spoiAfxjBXrDmDcS3HkozUXOfLjjW_dfAWzZZ93l4e9TRe4U_y9Nxkvdfh6B0W8FEDa-vsR9mg6jxXIvT5yogbHajmLNuJH4CByJXdMuOOYhVL4fbt-nbB6mKv-YNA9Tx14DNJEn5viRhwOLUD_Dx6aYizthftFDhFmSn06jSZOLOiFj4jcNsyik1fBsGKrnyTZUL7IGrq1HcssyBreU0XOeeCMxnSzHD4aLuQK4uLh0ne0WS4X_Q5M1LsBSvRs8_M3JPlXYx8PWdMRNdM0cCP680yPelRDwFl5V-mpdp0VuYVadKu8oFmZ1ysQFe5zXcHuzMA9uZbsyzTJmY1cD7yu1cMYxMs8xrfzFSnO1EzFFpjoh6nzerdPgKnVCEt35DgR_L9MHscztYLWkr10pJm75yNazD68P5Ie21DKmmXyP6-HqovECq54Y5mIvuBry-g7mJUBdBn3K9YKinOSPnasr6oZCZBZNDueZrKlOkaIutRtG18X6-QT4IEeu4qkvVL5x-s05ijf5GOo75yb4NDphzo0Cpl5zboTO_ObciE1OnXOjlKX3nJvgMzXw7GvdCB-st9GQwVDxwtlDP15d2ljV6PoEe171BCcSC2CmTsuK17SbMqfkJl3XTWnVapYM_PGNfEpzRi5TXjq2wVRjPtFnBkevkpH3OVyaeVWd16lH4eIpXN304L7Gv5LA253i5fwUEXgRi4d21Qi1mu9UQDzJe6INY_PH-x4NB839rmiq8SlOhgfUu0NRbPk4sIyKjVVP_vyvLJjhndVtJu8U8IUb7FwM1tt926DrPzxvQPDGo_HbZgXFbzV_L3g4EPvpsO1ncE0v-QkWzHiBW_Y_nCQEWyD7JXoh8rBkHzjWko36cORGqrnnigKq8kGpWfm22NN87aFlrAbHKk_3lB_wPXDRQMd9mnmoODg-rzYv4BDIjR44NdG0J2I3SE0t8t7iATIcpN0gNTqumypde2DU6OiuKB4wNTTGgsoYwrEaHtfHCnYJjxmbqOEBVyMPhBoYXxkfx8PvE9Ud7cXKBeINNoozxNXKgRH9N8N49z41to06fmg8BbKjR8nj1tOXwxDZCfRdwvAOITqIelkfc4DRcr3jj3LvaPmcs6qCTf2KUb5aTT0HmrjBXf3umcHBgHSXZdVJRqw6P3It9WFuhfJeJrxNDh56Rzc50fSEwR7XddkbNQa1D9v2UBnAapuBbfS24couwaGEbM_CIi49ak-yjcuAVV-nbeDpONhuuOwLG9PajpXtYxgrtz-IcDfcFC2vcKfZkcln7RblirbINN0t1j6wbHJTdp2xKq8JOVjTY0VdpK_slxsCvd7gZVOdGejQVbTeDZEj7wpGrD6q-YXDoHAy2Js51K9FQfb7mZHOxT-4iren29fThEf2CS1w--CyzxCh7w7Ht52Et6uqolWVugKzbU_0lOX2ieFW6LUNtM2PY2DnwLHBHyckYtlQaZXgTA6mvOSlvmzSHGy9dXDH-Aaw4Sc4e8m9befEY6OuBYPWi6UJ6RnFsj_UArebLTtJMZw3UFXOCRMdpybw3AmWnakm7MILa6ooRMulF9akcxyGXljTVMVw4vPBmuYpDmM3VnTYGrEz1xzJRlwjNnFhZb9ujxUbfEZWdU3XzxV5Sz7zEzFQYGei_KLDae9z3pUJ8cfI16LM8HH5T_7P0JybS66LA1BpUxfAcCiLpxIO22fnvE0TALzWck-fXgm_NzRL66NK4u-tv7C8ZCrhFi7x-VNHoU-sI2xpVnGeouTKFGX6lOY0A53-Cw"

    @Published var catalogs: [LiveCatalog] = []
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = nil
    @Published var featuredHeroItems: [MediaItem] = []

    private let cacheKey = "Debrid_Live_Catalogs_Cache_V1"
    private let urlSession: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        self.urlSession = URLSession(configuration: config)

        self.catalogs = Self.defaultCatalogDefinitions()
        loadDiskCache()
    }

    // MARK: - Pre-configured live catalog list from export
    static func defaultCatalogDefinitions() -> [LiveCatalog] {
        return [
            // 1. Trending & Latest
            LiveCatalog(
                id: "custom.community_betterposters.movie.tmdb_latest",
                name: "Latest Movies",
                type: "movie",
                endpointPath: "catalog/movie/tmdb-latest.json",
                category: "Trending & Latest"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.series.tmdb_latest_shows",
                name: "Latest TV Shows",
                type: "series",
                endpointPath: "catalog/series/tmdb-latest-shows.json",
                category: "Trending & Latest"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_trending",
                name: "Trending Movies",
                type: "movie",
                endpointPath: "catalog/movie/trakt-trending.json",
                category: "Trending & Latest"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.series.trakt_trending",
                name: "Trending Series",
                type: "series",
                endpointPath: "catalog/series/trakt-trending.json",
                category: "Trending & Latest"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_2236",
                name: "Top Movies of the Week",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A2236.json",
                category: "Trending & Latest"
            ),

            // 2. Top 25 & IMDb Masterpieces
            LiveCatalog(
                id: "custom.community_betterposters.movie.tmdb_today",
                name: "Top 25 Movies Today",
                type: "movie",
                endpointPath: "catalog/movie/tmdb-today.json",
                category: "Top Rated & IMDb"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.series.tmdb_today_shows",
                name: "Top 25 Shows Today",
                type: "series",
                endpointPath: "catalog/series/tmdb-today-shows.json",
                category: "Top Rated & IMDb"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub_justin__imdb_top_rated_movies",
                name: "IMDb Top Rated Movies",
                type: "movie",
                endpointPath: "catalog/movie/trakt-pub%3Ajustin--imdb-top-rated-movies.json",
                category: "Top Rated & IMDb"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub_justin__imdb_top_rated_tv_shows",
                name: "IMDb Top Rated Series",
                type: "series",
                endpointPath: "catalog/movie/trakt-pub%3Ajustin--imdb-top-rated-tv-shows.json",
                category: "Top Rated & IMDb"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub_captainnapalm__1001_greatest_movies_of_all_time",
                name: "1001 Greatest Movies of All Time",
                type: "movie",
                endpointPath: "catalog/movie/trakt-pub%3Acaptainnapalm--1001-greatest-movies-of-all-time.json",
                category: "Top Rated & IMDb"
            ),

            // 3. Streaming Networks & Studios (HBO, Apple TV+, A24)
            LiveCatalog(
                id: "custom.community_betterposters.series.mdblist_pub_3086",
                name: "HBO Shows",
                type: "series",
                endpointPath: "catalog/series/mdblist-pub%3A3086.json",
                category: "Networks & Studios"
            ),
            LiveCatalog(
                id: "merged.8024ce01236c",
                name: "Top Apple TV+",
                type: "movie",
                mergedSources: [
                    "catalog/movie/trakt-pub%3Asnoak--top-apple-tv-movies.json",
                    "catalog/movie/trakt-pub%3Asnoak--top-apple-tv-shows.json"
                ],
                category: "Networks & Studios"
            ),
            LiveCatalog(
                id: "merged.d60adfdd911d",
                name: "Top HBO Max",
                type: "movie",
                mergedSources: [
                    "catalog/movie/trakt-pub%3Asnoak--top-hbo-max-movies.json",
                    "catalog/movie/trakt-pub%3Asnoak--top-hbo-max-shows.json"
                ],
                category: "Networks & Studios"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub_fidel_cb__a24",
                name: "A24 Cinema Vault",
                type: "movie",
                endpointPath: "catalog/movie/trakt-pub%3Afidel-cb--a24.json",
                category: "Networks & Studios"
            ),

            // 4. Curated Genres & Cult Favorites
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub_benfranklin__best_mindfucks",
                name: "Mindfuck & Psychological",
                type: "movie",
                endpointPath: "catalog/movie/trakt-pub%3Abenfranklin--best-mindfucks.json",
                category: "Curated & Cult"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub_canconfirm__shut_up_and_watch",
                name: "Shut Up, And Watch",
                type: "movie",
                endpointPath: "catalog/movie/trakt-pub%3Acanconfirm--shut-up-and-watch.json",
                category: "Curated & Cult"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub_lish408__true_crime_documentary_series_film",
                name: "True Crime Documentaries",
                type: "movie",
                endpointPath: "catalog/movie/trakt-pub%3Alish408--true-crime-documentary-series-film.json",
                category: "Curated & Cult"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub_benfranklin__based_on_a_true_story",
                name: "Based on a True Story",
                type: "movie",
                endpointPath: "catalog/movie/trakt-pub%3Abenfranklin--based-on-a-true-story.json",
                category: "Curated & Cult"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.trakt_pub__aenema__great_movies_you_may_have_never_heard_of",
                name: "Great Movies You May Have Never Heard Of",
                type: "movie",
                endpointPath: "catalog/movie/trakt-pub%3A_aenema--great-movies-you-may-have-never-heard-of.json",
                category: "Curated & Cult"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_100442",
                name: "Stand-Up Comedy",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A100442.json",
                category: "Curated & Cult"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_91009",
                name: "In Search of Darkness (Horror)",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A91009.json",
                category: "Curated & Cult"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_131767",
                name: "Natural Disasters & Apocalyptic",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A131767.json",
                category: "Curated & Cult"
            ),

            // 5. Decades of Cinema
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_92337",
                name: "Popular 2025 Movies",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A92337.json",
                category: "Cinema Decades"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_146004",
                name: "Popular 2026 Movies",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A146004.json",
                category: "Cinema Decades"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_91304",
                name: "Popular 2020s Movies",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A91304.json",
                category: "Cinema Decades"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_91303",
                name: "Popular 2010s Movies",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A91303.json",
                category: "Cinema Decades"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_91300",
                name: "Popular 1990s Movies",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A91300.json",
                category: "Cinema Decades"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_91301",
                name: "Popular 1980s Movies",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A91301.json",
                category: "Cinema Decades"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_127962",
                name: "Popular 1970s Movies",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A127962.json",
                category: "Cinema Decades"
            ),
            LiveCatalog(
                id: "custom.community_betterposters.movie.mdblist_pub_144321",
                name: "Popular 1960s Movies",
                type: "movie",
                endpointPath: "catalog/movie/mdblist-pub%3A144321.json",
                category: "Cinema Decades"
            )
        ]
    }

    // MARK: - Synchronize All Live Catalogs
    func syncAllCatalogs(force: Bool = false) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        var updatedCatalogs = self.catalogs

        await withTaskGroup(of: (String, [MediaItem])?.self) { group in
            for catalog in updatedCatalogs {
                let catId = catalog.id
                let path = catalog.endpointPath
                let merged = catalog.mergedSources

                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    do {
                        if let singlePath = path {
                            let items = try await self.fetchEndpoint(path: singlePath)
                            return (catId, items)
                        } else if let mergedPaths = merged {
                            let items = try await self.fetchMergedEndpoints(paths: mergedPaths)
                            return (catId, items)
                        }
                    } catch {
                        print("[LiveCatalogService] Error syncing \(catId): \(error.localizedDescription)")
                    }
                    return nil
                }
            }

            for await result in group {
                guard let (catId, items) = result, !items.isEmpty else { continue }
                if let idx = updatedCatalogs.firstIndex(where: { $0.id == catId }) {
                    updatedCatalogs[idx].items = items
                    updatedCatalogs[idx].lastUpdated = Date()
                }
            }
        }

        self.catalogs = updatedCatalogs
        self.lastSyncDate = Date()
        self.updateHeroSpotlight()
        saveDiskCache()
    }

    // MARK: - Single Endpoint Fetcher (with Auto-Pagination)
    private func fetchEndpoint(path: String, maxItems: Int = 300) async throws -> [MediaItem] {
        var allItems: [MediaItem] = []
        var skip = 0

        while true {
            let requestPath: String
            if skip == 0 {
                requestPath = path
            } else {
                // Stremio pagination: replace .json with /skip={skip}.json
                if path.hasSuffix(".json") {
                    let baseWithoutJson = String(path.dropLast(5))
                    requestPath = "\(baseWithoutJson)/skip=\(skip).json"
                } else {
                    break
                }
            }

            guard let url = URL(string: "\(baseURL)/\(requestPath)") else { break }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            guard let (data, response) = try? await urlSession.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                break
            }

            guard let decoded = try? JSONDecoder().decode(StremioCatalogResponse.self, from: data),
                  let metas = decoded.metas, !metas.isEmpty else {
                break
            }

            let pageItems = metas.map { $0.toMediaItem() }
            allItems.append(contentsOf: pageItems)

            // Stremio pages are 100 items. If fewer than 100 were returned or max reached, stop.
            if metas.count < 100 || allItems.count >= maxItems {
                break
            }
            skip += metas.count
        }

        return allItems
    }

    // MARK: - Merged Endpoints Fetcher (Interleaved)
    private func fetchMergedEndpoints(paths: [String]) async throws -> [MediaItem] {
        var sourcesItems: [[MediaItem]] = []
        for path in paths {
            if let items = try? await fetchEndpoint(path: path) {
                sourcesItems.append(items)
            }
        }
        guard !sourcesItems.isEmpty else { return [] }

        // Interleave items
        var interleaved: [MediaItem] = []
        let maxCount = sourcesItems.map { $0.count }.max() ?? 0
        var seenIds = Set<String>()

        for i in 0..<maxCount {
            for list in sourcesItems {
                if i < list.count {
                    let item = list[i]
                    if !seenIds.contains(item.id) {
                        seenIds.insert(item.id)
                        interleaved.append(item)
                    }
                }
            }
        }
        return interleaved
    }

    // MARK: - Live Search across TMDB & BetterPosters
    func searchLive(query: String) async throws -> [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 1. Run TMDB intelligent search (handles directors like Tarantino, actors, titles sorted by popularity & vote counts)
        async let tmdbTask: [MediaItem] = {
            return await TMDBService().searchMedia(query: trimmed)
        }()

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return await tmdbTask
        }

        async let moviesTask: [MediaItem] = {
            let path = "catalog/movie/bp-search/search=\(encoded).json"
            return (try? await self.fetchEndpoint(path: path)) ?? []
        }()

        async let seriesTask: [MediaItem] = {
            let path = "catalog/series/bp-search/search=\(encoded).json"
            return (try? await self.fetchEndpoint(path: path)) ?? []
        }()

        let (tmdbResults, movies, series) = await (tmdbTask, moviesTask, seriesTask)

        // Prioritize intelligent TMDB results (real director/filmography matches), followed by catalog matches
        var combined = tmdbResults + movies + series
        var seenIDs = Set<String>()
        var seenTitles = Set<String>()

        combined.removeAll { item in
            let cleanTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if seenIDs.contains(item.id) || seenTitles.contains(cleanTitle) { return true }
            seenIDs.insert(item.id)
            if !cleanTitle.isEmpty { seenTitles.insert(cleanTitle) }
            return false
        }
        return combined
    }

    private func updateHeroSpotlight() {
        // Collect top titles with backdrops and posters for hero carousel
        var heroes: [MediaItem] = []
        for cat in catalogs where cat.items.count >= 4 {
            for item in cat.items.prefix(3) {
                if item.backdropUrl != nil && item.posterUrl != nil && !heroes.contains(where: { $0.id == item.id }) {
                    heroes.append(item)
                }
            }
            if heroes.count >= 8 { break }
        }
        self.featuredHeroItems = Array(heroes.prefix(7))
    }

    // MARK: - Catalog Management (Toggle, Remove, Reorder, Import/Export)
    func toggleCatalog(id: String, isEnabled: Bool) {
        if let idx = catalogs.firstIndex(where: { $0.id == id }) {
            catalogs[idx].isEnabled = isEnabled
            updateHeroSpotlight()
            saveDiskCache()
        }
    }

    func addCatalog(_ catalog: LiveCatalog) {
        if let idx = catalogs.firstIndex(where: { $0.id == catalog.id }) {
            catalogs[idx] = catalog
        } else {
            catalogs.insert(catalog, at: 0)
        }
        updateHeroSpotlight()
        saveDiskCache()
        Task {
            await syncSingleCatalog(catalog)
        }
    }

    func syncSingleCatalog(_ catalog: LiveCatalog) async {
        guard let path = catalog.endpointPath else { return }
        do {
            let items = try await fetchEndpoint(path: path)
            if !items.isEmpty, let idx = catalogs.firstIndex(where: { $0.id == catalog.id }) {
                catalogs[idx].items = items
                catalogs[idx].lastUpdated = Date()
                updateHeroSpotlight()
                saveDiskCache()
            }
        } catch {
            print("[LiveCatalogService] Error fetching single catalog: \(error)")
        }
    }

    func removeCatalog(id: String) {
        catalogs.removeAll(where: { $0.id == id })
        updateHeroSpotlight()
        saveDiskCache()
    }

    func resetToDefaults() {
        self.catalogs = Self.defaultCatalogDefinitions()
        saveDiskCache()
        Task {
            await syncAllCatalogs(force: true)
        }
    }

    func exportCatalogsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(catalogs), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    func importCatalogs(from jsonString: String) throws -> Int {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "LiveCatalogService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format."])
        }

        if let imported = try? JSONDecoder().decode([LiveCatalog].self, from: data), !imported.isEmpty {
            for item in imported {
                if let idx = self.catalogs.firstIndex(where: { $0.id == item.id }) {
                    self.catalogs[idx] = item
                } else {
                    self.catalogs.append(item)
                }
            }
            saveDiskCache()
            Task { await syncAllCatalogs() }
            return imported.count
        }

        throw NSError(domain: "LiveCatalogService", code: 422, userInfo: [NSLocalizedDescriptionKey: "Could not parse catalogs JSON. Please ensure it is a valid catalog export format."])
    }

    // MARK: - Local Disk Cache for Instant Startup
    private func saveDiskCache() {
        do {
            let data = try JSONEncoder().encode(catalogs)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("[LiveCatalogService] Failed to cache: \(error)")
        }
    }

    private func loadDiskCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([LiveCatalog].self, from: data) {
            self.catalogs = cached
            self.updateHeroSpotlight()
        }
    }
}
