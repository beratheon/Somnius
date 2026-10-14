import Foundation
import Combine

// MARK: - Curated Catalog Preset Model
struct CuratedCatalogPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: String // "Letterboxd & Acclaimed", "Studios & Vaults", "Cult & Thrillers", "TMDB Live", "Streaming & TV", "Decades & World Cinema"
    let source: String   // "Letterboxd", "Criterion", "A24", "TMDB", "HBO", "Studio Ghibli", "IMDb"
    let icon: String
    let type: String     // "movie" or "series"
    let endpointPath: String?
    let genres: [Int]
    let keywordIDs: [Int]
    let sampleTitles: [String]
}

// MARK: - Genre and Filter Tag Models
struct GenreTag: Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String
}

struct DecadeFilter: Identifiable, Hashable {
    let id: String
    let name: String
    let minYear: Int?
    let maxYear: Int?
}

struct KeywordSuggestion: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
}

// MARK: - Catalog Discovery Service
@MainActor
class CatalogDiscoveryService: ObservableObject {
    static let shared = CatalogDiscoveryService()

    private let tmdb = TMDBService()

    // MARK: - All Supported Genre Tags
    let availableGenres: [GenreTag] = [
        GenreTag(id: 878, name: "Sci-Fi", icon: "sparkles"),
        GenreTag(id: 28, name: "Action", icon: "bolt.fill"),
        GenreTag(id: 53, name: "Thriller", icon: "waveform.path.ecg"),
        GenreTag(id: 27, name: "Horror", icon: "flame.fill"),
        GenreTag(id: 9648, name: "Mystery", icon: "magnifyingglass"),
        GenreTag(id: 80, name: "Crime", icon: "shield.lefthalf.filled"),
        GenreTag(id: 18, name: "Drama", icon: "theatermasks.fill"),
        GenreTag(id: 35, name: "Comedy", icon: "face.smiling.fill"),
        GenreTag(id: 16, name: "Animation", icon: "wand.and.stars"),
        GenreTag(id: 14, name: "Fantasy", icon: "moon.stars.fill"),
        GenreTag(id: 12, name: "Adventure", icon: "map.fill"),
        GenreTag(id: 10749, name: "Romance", icon: "heart.fill"),
        GenreTag(id: 99, name: "Documentary", icon: "video.fill"),
        GenreTag(id: 10752, name: "War", icon: "flag.fill"),
        GenreTag(id: 36, name: "History", icon: "clock.arrow.circlepath"),
        GenreTag(id: 37, name: "Western", icon: "sun.haze.fill")
    ]

    // MARK: - All Decade Filters
    let availableDecades: [DecadeFilter] = [
        DecadeFilter(id: "all", name: "All Eras", minYear: nil, maxYear: nil),
        DecadeFilter(id: "2020s", name: "2020s (Current)", minYear: 2020, maxYear: 2029),
        DecadeFilter(id: "2010s", name: "2010s", minYear: 2010, maxYear: 2019),
        DecadeFilter(id: "2000s", name: "2000s", minYear: 2000, maxYear: 2009),
        DecadeFilter(id: "1990s", name: "1990s", minYear: 1990, maxYear: 1999),
        DecadeFilter(id: "1980s", name: "1980s", minYear: 1980, maxYear: 1989),
        DecadeFilter(id: "1970s", name: "1970s", minYear: 1970, maxYear: 1979),
        DecadeFilter(id: "classic", name: "Golden Era (Pre-1970)", minYear: 1920, maxYear: 1969)
    ]

    // MARK: - Popular Keyword Suggestions
    let keywordChips: [KeywordSuggestion] = [
        KeywordSuggestion(id: "time_loop", label: "Time Loop", icon: "arrow.triangle.2.circlepath"),
        KeywordSuggestion(id: "cyberpunk", label: "Cyberpunk", icon: "cpu"),
        KeywordSuggestion(id: "heist", label: "Heist", icon: "briefcase.fill"),
        KeywordSuggestion(id: "space", label: "Deep Space", icon: "moon.fill"),
        KeywordSuggestion(id: "ai", label: "AI & Androids", icon: "sparkles"),
        KeywordSuggestion(id: "revenge", label: "Revenge", icon: "cross.fill"),
        KeywordSuggestion(id: "serial_killer", label: "Serial Killer", icon: "eye.fill"),
        KeywordSuggestion(id: "parallel_universe", label: "Multiverse", icon: "circle.hexagongrid.fill"),
        KeywordSuggestion(id: "dystopia", label: "Dystopia", icon: "building.2.crop.list"),
        KeywordSuggestion(id: "neo_noir", label: "Neo-Noir", icon: "cloud.rain.fill"),
        KeywordSuggestion(id: "alien", label: "Alien Invasion", icon: "antenna.radiowaves.left.and.right"),
        KeywordSuggestion(id: "supernatural", label: "Supernatural", icon: "wand.and.stars.inverse")
    ]

    // MARK: - Wide Curated Preset Catalog Library
    let curatedPresets: [CuratedCatalogPreset] = [
        // 1. Letterboxd & High Acclaim
        CuratedCatalogPreset(
            id: "preset.letterboxd.top250",
            title: "Letterboxd Top 250",
            subtitle: "The definitive community-ranked masterpieces of all time",
            category: "Letterboxd & Acclaimed",
            source: "Letterboxd",
            icon: "star.fill",
            type: "movie",
            endpointPath: "catalog/movie/trakt-pub%3Ajustin--imdb-top-rated-movies.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Parasite", "The Godfather", "Spirited Away", "12 Angry Men", "Harakiri"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.criterion",
            title: "The Criterion Collection",
            subtitle: "Essential world cinema, avant-garde visions & art-house icons",
            category: "Letterboxd & Acclaimed",
            source: "Criterion",
            icon: "film.stack.fill",
            type: "movie",
            endpointPath: nil,
            genres: [18, 9648],
            keywordIDs: [],
            sampleTitles: ["Seven Samurai", "8½", "Persona", "In the Mood for Love", "Stalker"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.a24",
            title: "A24 Vault & Modern Cinema",
            subtitle: "Radical indies, elevated dread & boundary-pushing cinema",
            category: "Letterboxd & Acclaimed",
            source: "A24",
            icon: "flame.fill",
            type: "movie",
            endpointPath: "catalog/movie/trakt-pub%3Afidel-cb--a24.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Everything Everywhere All at Once", "Hereditary", "Past Lives", "Uncut Gems"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.palme_dor",
            title: "Cannes Palme d'Or Laureates",
            subtitle: "Groundbreaking international festival masterworks",
            category: "Letterboxd & Acclaimed",
            source: "Cannes",
            icon: "laurel.leading",
            type: "movie",
            endpointPath: nil,
            genres: [18],
            keywordIDs: [],
            sampleTitles: ["Anatomy of a Fall", "Triangle of Sadness", "Shoplifters", "Blue Is the Warmest Color"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.oscars",
            title: "Oscar Best Picture Winners",
            subtitle: "Every Academy Award-winning flagship production",
            category: "Letterboxd & Acclaimed",
            source: "Academy",
            icon: "trophy.fill",
            type: "movie",
            endpointPath: nil,
            genres: [18],
            keywordIDs: [],
            sampleTitles: ["Oppenheimer", "Spotlight", "Moonlight", "No Country for Old Men", "Gladiator"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.1001_movies",
            title: "1001 Movies You Must See",
            subtitle: "The ultimate bucket list of essential viewing across film history",
            category: "Letterboxd & Acclaimed",
            source: "Letterboxd",
            icon: "list.bullet.rectangle.fill",
            type: "movie",
            endpointPath: "catalog/movie/trakt-pub%3Acaptainnapalm--1001-greatest-movies-of-all-time.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Citizen Kane", "Casablanca", "Taxi Driver", "Apocalypse Now", "Goodfellas"]
        ),

        // 2. Mindfuck, Cult & Thrillers
        CuratedCatalogPreset(
            id: "preset.letterboxd.mindfuck",
            title: "Mindfuck & Psychological",
            subtitle: "Unreliable narrators, reality-bending twists & fractured identities",
            category: "Cult & Thrillers",
            source: "Letterboxd",
            icon: "waveform.path.badge.plus",
            type: "movie",
            endpointPath: "catalog/movie/trakt-pub%3Abenfranklin--best-mindfucks.json",
            genres: [9648, 53],
            keywordIDs: [],
            sampleTitles: ["Fight Club", "Memento", "Coherence", "Shutter Island", "The Prestige"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.cyberpunk",
            title: "Cyberpunk & Synthetic Futures",
            subtitle: "Dystopian mega-cities, rogue AI, high tech and low life",
            category: "Cult & Thrillers",
            source: "Letterboxd",
            icon: "cpu.fill",
            type: "movie",
            endpointPath: nil,
            genres: [878, 28],
            keywordIDs: [4565],
            sampleTitles: ["Blade Runner 2049", "The Matrix", "Akira", "Ghost in the Shell", "Upgrade"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.neon_noir",
            title: "Neon Noir & Night Thrillers",
            subtitle: "Rain-slicked pavement, synthwave scores & morally ambiguous antiheroes",
            category: "Cult & Thrillers",
            source: "Letterboxd",
            icon: "cloud.moon.rain.fill",
            type: "movie",
            endpointPath: nil,
            genres: [80, 53],
            keywordIDs: [],
            sampleTitles: ["Drive", "Nightcrawler", "Collateral", "The Batman", "Thief"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.modern_horror",
            title: "Modern Horror Renaissance",
            subtitle: "Atmospheric folk dread, psychological terror & auteur nightmares",
            category: "Cult & Thrillers",
            source: "Letterboxd",
            icon: "eye.trianglebadge.exclamationmark.fill",
            type: "movie",
            endpointPath: "catalog/movie/mdblist-pub%3A91009.json",
            genres: [27],
            keywordIDs: [],
            sampleTitles: ["Hereditary", "The Witch", "Midsommar", "It Follows", "The Lighthouse"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.underrated",
            title: "Underrated Hidden Gems",
            subtitle: "Brilliant overlooked masterworks you may have never heard of",
            category: "Cult & Thrillers",
            source: "Letterboxd",
            icon: "sparkle.magnifyingglass",
            type: "movie",
            endpointPath: "catalog/movie/trakt-pub%3A_aenema--great-movies-you-may-have-never-heard-of.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Incendies", "Coherence", "The Fall", "Victoria", "Burning"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.shut_up_watch",
            title: "Shut Up, And Watch",
            subtitle: "Pulse-pounding thrills where you cannot look away for a single second",
            category: "Cult & Thrillers",
            source: "Letterboxd",
            icon: "play.circle.fill",
            type: "movie",
            endpointPath: "catalog/movie/trakt-pub%3Acanconfirm--shut-up-and-watch.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Sicario", "Prisoners", "Whiplash", "Green Room", "Mad Max: Fury Road"]
        ),

        // 3. Studios & World Cinema
        CuratedCatalogPreset(
            id: "preset.letterboxd.ghibli",
            title: "Studio Ghibli Complete World",
            subtitle: "Miyazaki & Takahata's timeless hand-drawn enchanted fairy tales",
            category: "Studios & Vaults",
            source: "Studio Ghibli",
            icon: "leaf.fill",
            type: "movie",
            endpointPath: nil,
            genres: [16, 14],
            keywordIDs: [],
            sampleTitles: ["Spirited Away", "Princess Mononoke", "My Neighbor Totoro", "Howl's Moving Castle"]
        ),
        CuratedCatalogPreset(
            id: "preset.cinema.korean_wave",
            title: "Korean Cinema Golden Wave",
            subtitle: "Uncompromising thrillers, blistering revenge & razor-sharp social satire",
            category: "Studios & Vaults",
            source: "World Cinema",
            icon: "globe.asia.australia.fill",
            type: "movie",
            endpointPath: nil,
            genres: [53, 18],
            keywordIDs: [],
            sampleTitles: ["Parasite", "Oldboy", "Memories of Murder", "The Handmaiden", "I Saw the Devil"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.tarantino",
            title: "Tarantino Universe & Homages",
            subtitle: "Sharp dialogue, eclectic soundtracks & bloody cinematic ecstasy",
            category: "Studios & Vaults",
            source: "Letterboxd",
            icon: "flame.circle.fill",
            type: "movie",
            endpointPath: nil,
            genres: [80, 28],
            keywordIDs: [],
            sampleTitles: ["Pulp Fiction", "Inglourious Basterds", "Django Unchained", "Reservoir Dogs", "Kill Bill"]
        ),
        CuratedCatalogPreset(
            id: "preset.letterboxd.space_odysseys",
            title: "Deep Space & Cosmic Odysseys",
            subtitle: "The vast sublime silence of the universe and gravitational mysteries",
            category: "Studios & Vaults",
            source: "Letterboxd",
            icon: "sparkles.rectangle.stack.fill",
            type: "movie",
            endpointPath: nil,
            genres: [878],
            keywordIDs: [9882],
            sampleTitles: ["Interstellar", "2001: A Space Odyssey", "Arrival", "Solaris", "The Martian"]
        ),

        // 4. TMDB Live & Box Office
        CuratedCatalogPreset(
            id: "preset.tmdb.in_theaters",
            title: "In Theaters & Box Office",
            subtitle: "Current top theatrical releases and global box office sensations",
            category: "TMDB Live",
            source: "TMDB",
            icon: "film.fill",
            type: "movie",
            endpointPath: "catalog/movie/tmdb-today.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Dune: Part Two", "Deadpool & Wolverine", "Inside Out 2", "Civil War"]
        ),
        CuratedCatalogPreset(
            id: "preset.tmdb.trending_week",
            title: "Trending Movies This Week",
            subtitle: "The most watched and actively streamed feature films right now",
            category: "TMDB Live",
            source: "TMDB",
            icon: "chart.line.uptrend.xyaxis",
            type: "movie",
            endpointPath: "catalog/movie/tmdb-latest.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Furiosa", "Challengers", "Alien: Romulus", "Twisters"]
        ),
        CuratedCatalogPreset(
            id: "preset.tmdb.top_rated",
            title: "TMDB All-Time Top Rated",
            subtitle: "Global crowd-sourced ratings from millions of international cinephiles",
            category: "TMDB Live",
            source: "TMDB",
            icon: "rosette",
            type: "movie",
            endpointPath: "catalog/movie/mdblist-pub%3A2236.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["The Shawshank Redemption", "The Godfather", "Schindler's List"]
        ),
        CuratedCatalogPreset(
            id: "preset.tmdb.action_adrenaline",
            title: "Action & Pure Adrenaline",
            subtitle: "Jaw-dropping stunts, martial arts choreography & explosive spectacles",
            category: "TMDB Live",
            source: "TMDB",
            icon: "bolt.badge.clock.fill",
            type: "movie",
            endpointPath: nil,
            genres: [28, 53],
            keywordIDs: [],
            sampleTitles: ["John Wick: Chapter 4", "Mission: Impossible", "Top Gun: Maverick", "The Raid"]
        ),
        CuratedCatalogPreset(
            id: "preset.tmdb.animation_masterpieces",
            title: "Animation & Pixar Wonders",
            subtitle: "Heartwarming storytelling, technical brilliance & whimsical imagination",
            category: "TMDB Live",
            source: "TMDB",
            icon: "wand.and.stars",
            type: "movie",
            endpointPath: nil,
            genres: [16, 10751],
            keywordIDs: [],
            sampleTitles: ["Spider-Man: Across the Spider-Verse", "WALL-E", "Coco", "Ratatouille"]
        ),
        CuratedCatalogPreset(
            id: "preset.tmdb.standup_comedy",
            title: "Stand-Up Comedy & Specials",
            subtitle: "Acclaimed comedy concerts, laugh-out-loud routines & specials",
            category: "TMDB Live",
            source: "TMDB",
            icon: "mic.fill",
            type: "movie",
            endpointPath: "catalog/movie/mdblist-pub%3A100442.json",
            genres: [35],
            keywordIDs: [],
            sampleTitles: ["Dave Chappelle", "Bill Burr", "John Mulaney", "Ali Wong"]
        ),

        // 5. Streaming Networks & Prestige TV
        CuratedCatalogPreset(
            id: "preset.tv.hbo_prestige",
            title: "HBO & Max Prestige TV",
            subtitle: "Golden era television from the most acclaimed studio in history",
            category: "Streaming & TV",
            source: "HBO",
            icon: "crown.fill",
            type: "series",
            endpointPath: "catalog/series/mdblist-pub%3A3086.json",
            genres: [18],
            keywordIDs: [],
            sampleTitles: ["Succession", "The Sopranos", "The Wire", "True Detective", "The Last of Us"]
        ),
        CuratedCatalogPreset(
            id: "preset.tv.apple_plus",
            title: "Apple TV+ Award Winners",
            subtitle: "Lavish sci-fi epics, witty comedies & premium production designs",
            category: "Streaming & TV",
            source: "Apple TV+",
            icon: "applelogo",
            type: "series",
            endpointPath: nil,
            genres: [18, 878],
            keywordIDs: [],
            sampleTitles: ["Severance", "Ted Lasso", "Slow Horses", "Silo", "Foundation"]
        ),
        CuratedCatalogPreset(
            id: "preset.tv.netflix_global",
            title: "Netflix Global Hits",
            subtitle: "Cultural phenomena, binge-worthy thrillers & mind-bending sci-fi",
            category: "Streaming & TV",
            source: "Netflix",
            icon: "play.tv.fill",
            type: "series",
            endpointPath: nil,
            genres: [18, 9648],
            keywordIDs: [],
            sampleTitles: ["Stranger Things", "Black Mirror", "Dark", "Mindhunter", "Squid Game"]
        ),
        CuratedCatalogPreset(
            id: "preset.tv.true_crime",
            title: "True Crime Documentaries",
            subtitle: "Unsolved mysteries, forensic investigations & stranger-than-fiction cases",
            category: "Streaming & TV",
            source: "Documentary",
            icon: "doc.text.magnifyingglass",
            type: "series",
            endpointPath: "catalog/movie/trakt-pub%3Alish408--true-crime-documentary-series-film.json",
            genres: [99, 80],
            keywordIDs: [],
            sampleTitles: ["The Jinx", "Making a Murderer", "Wild Wild Country", "Tiger King"]
        ),

        // 6. Decades of Cinema
        CuratedCatalogPreset(
            id: "preset.cinema.90s",
            title: "90s Golden Blockbusters",
            subtitle: "Peak practical effects, legendary directors & timeless indie icons",
            category: "Decades & World Cinema",
            source: "Cinema 90s",
            icon: "sparkles.tv.fill",
            type: "movie",
            endpointPath: "catalog/movie/mdblist-pub%3A91300.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Jurassic Park", "The Matrix", "Pulp Fiction", "Fight Club", "The Truman Show"]
        ),
        CuratedCatalogPreset(
            id: "preset.cinema.80s",
            title: "80s Synth & Neon Classics",
            subtitle: "Amblin adventure, analog synthesizers, creature features & neon grit",
            category: "Decades & World Cinema",
            source: "Cinema 80s",
            icon: "cassette.fill",
            type: "movie",
            endpointPath: "catalog/movie/mdblist-pub%3A91301.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Back to the Future", "Blade Runner", "The Thing", "Aliens", "Die Hard"]
        ),
        CuratedCatalogPreset(
            id: "preset.cinema.70s",
            title: "70s American New Wave",
            subtitle: "Gritty realism, political paranoia, antiheroes & unvarnished truth",
            category: "Decades & World Cinema",
            source: "Cinema 70s",
            icon: "camera.filters",
            type: "movie",
            endpointPath: "catalog/movie/mdblist-pub%3A127962.json",
            genres: [],
            keywordIDs: [],
            sampleTitles: ["Taxi Driver", "The Godfather", "Apocalypse Now", "Chinatown", "Network"]
        )
    ]

    // MARK: - Category & Keyword Mixer Implementation
    func mixCategories(
        genres: [Int],
        keywordQuery: String,
        decade: DecadeFilter?,
        sortBy: String = "popularity.desc",
        type: String = "movie"
    ) async -> [MediaItem] {
        let mediaType: MediaItem.MediaType = (type == "series") ? .series : .movie
        var kwIDs: [Int] = []

        let cleanKW = keywordQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKW.isEmpty {
            kwIDs = await tmdb.searchKeywordIDs(query: cleanKW)
        }

        // Fetch page 1 and page 2 for deep catalog
        async let page1 = tmdb.discoverMedia(
            type: mediaType,
            genres: genres,
            keywordIDs: kwIDs,
            yearMin: decade?.minYear,
            yearMax: decade?.maxYear,
            sortBy: sortBy,
            page: 1
        )
        async let page2 = tmdb.discoverMedia(
            type: mediaType,
            genres: genres,
            keywordIDs: kwIDs,
            yearMin: decade?.minYear,
            yearMax: decade?.maxYear,
            sortBy: sortBy,
            page: 2
        )

        let combined = await (page1 + page2)
        var seen = Set<String>()
        var unique: [MediaItem] = []
        for item in combined {
            if !seen.contains(item.id) {
                seen.insert(item.id)
                unique.append(item)
            }
        }
        return unique
    }

    // MARK: - Populate Catalog Preset into LiveCatalog
    func activatePreset(_ preset: CuratedCatalogPreset) async -> LiveCatalog {
        var items: [MediaItem] = []

        // 1. If it has a stream/endpoint path, fetch directly
        if let path = preset.endpointPath {
            // First check if live catalog already has cached items for it
            if let existing = LiveCatalogService.shared.catalogs.first(where: { $0.id == preset.id }), !existing.items.isEmpty {
                items = existing.items
            }
        }

        // 2. If items still empty, query TMDB for preset's sample or genres
        if items.isEmpty {
            if !preset.sampleTitles.isEmpty {
                let mType: MediaItem.MediaType = (preset.type == "series") ? .series : .movie
                await withTaskGroup(of: MediaItem?.self) { group in
                    for title in preset.sampleTitles {
                        group.addTask {
                            return await self.tmdb.searchSingleMedia(title: title, type: mType)
                        }
                    }
                    for await res in group {
                        if let res = res { items.append(res) }
                    }
                }
            }

            // Augment with discover if needed
            if items.count < 10 {
                let mType: MediaItem.MediaType = (preset.type == "series") ? .series : .movie
                let discoverRes = await tmdb.discoverMedia(
                    type: mType,
                    genres: preset.genres,
                    keywordIDs: preset.keywordIDs,
                    sortBy: "vote_average.desc"
                )
                for item in discoverRes {
                    if !items.contains(where: { $0.id == item.id }) {
                        items.append(item)
                    }
                    if items.count >= 20 { break }
                }
            }
        }

        return LiveCatalog(
            id: preset.id,
            name: preset.title,
            type: preset.type,
            endpointPath: preset.endpointPath,
            category: preset.category,
            items: items,
            lastUpdated: Date(),
            isEnabled: true
        )
    }
}
