import Foundation

struct CuratedCollection: Identifiable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let items: [MediaItem]
}

class LetterboxdService {
    static let shared = LetterboxdService()

    /// Returns high priority Letterboxd & IMDb top curated collections
    func fetchCuratedCollections() async -> [CuratedCollection] {
        let tmdb = TMDBService()

        async let topRated = tmdb.fetchTopRatedCatalog(page: 1)
        async let topRated2 = tmdb.fetchTopRatedCatalog(page: 2)
        async let actionFilms = tmdb.fetchActionCatalog()
        async let trendingSeries = tmdb.fetchPopularSeries()

        let letterboxdTop = await topRated + topRated2
        let a24Vault = await actionFilms
        let topTV = await trendingSeries

        return [
            CuratedCollection(
                id: "letterboxd_top250",
                title: "Letterboxd Top Masterpieces",
                description: "Highest community rated feature films of all time",
                iconName: "star.fill",
                items: Array(letterboxdTop.prefix(15))
            ),
            CuratedCollection(
                id: "a24_classics",
                title: "Cinematic Action & Thrillers",
                description: "High-octane blockbusters & critically acclaimed thrillers",
                iconName: "flame.fill",
                items: Array(a24Vault.prefix(15))
            ),
            CuratedCollection(
                id: "top_tv_masterpieces",
                title: "IMDb Top Series & Shows",
                description: "Highest rated TV series, Miniseries & Anime",
                iconName: "tv.fill",
                items: Array(topTV.prefix(15))
            )
        ]
    }
}
