import Foundation
import Combine

// MARK: - Gemini AI Catalog Generator Service
@MainActor
class GeminiCatalogService: ObservableObject {
    static let shared = GeminiCatalogService()

    @Published var isGenerating: Bool = false
    @Published var lastGeneratedCatalog: LiveCatalog? = nil
    @Published var statusMessage: String? = nil

    private let tmdb = TMDBService()

    struct GeminiMovieEntry: Codable {
        let title: String
        let year: Int?
    }

    struct GeminiCatalogResponse: Codable {
        let title: String
        let description: String
        let type: String? // "movie" or "series"
        let movies: [GeminiMovieEntry]
    }

    /// Curates a custom cinema catalog given a user's free-form prompt
    func curateCatalog(from prompt: String, customApiKey: String? = nil) async throws -> LiveCatalog {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw NSError(domain: "GeminiCatalogService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please enter a description or vibe for your category."])
        }

        isGenerating = true
        statusMessage = "Consulting Gemini AI cinema mind..."
        defer {
            isGenerating = false
        }

        let key = customApiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ?
                  customApiKey!.trimmingCharacters(in: .whitespacesAndNewlines) :
                  Config.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        var parsedResult: GeminiCatalogResponse? = nil

        if !key.isEmpty {
            do {
                parsedResult = try await callGeminiAPI(prompt: trimmedPrompt, apiKey: key)
            } catch {
                print("[GeminiCatalogService] Gemini API call failed: \(error.localizedDescription). Falling back to smart heuristic curation.")
            }
        }

        // If no API key or API call failed, run smart semantic fallback curation
        if parsedResult == nil {
            parsedResult = await smartSemanticFallback(prompt: trimmedPrompt)
        }

        guard let curation = parsedResult, !curation.movies.isEmpty else {
            throw NSError(domain: "GeminiCatalogService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not generate movies for this category. Please try different keywords."])
        }

        statusMessage = "Resolving high-res posters & metadata for \(curation.title)..."

        // Concurrently resolve TMDB metadata
        let isSeries = (curation.type?.lowercased() == "series" || curation.type?.lowercased() == "tv")
        let mediaType: MediaItem.MediaType = isSeries ? .series : .movie

        var resolvedItems: [MediaItem] = []
        await withTaskGroup(of: MediaItem?.self) { group in
            for m in curation.movies.prefix(25) {
                group.addTask {
                    return await self.tmdb.searchSingleMedia(title: m.title, year: m.year, type: mediaType)
                }
            }
            for await item in group {
                if let item = item {
                    resolvedItems.append(item)
                }
            }
        }

        // Fallback: If title lookups resolved fewer than 3 items, augment with TMDB discover
        if resolvedItems.count < 4 {
            let backupItems = await tmdb.discoverMedia(
                type: mediaType,
                sortBy: "vote_average.desc"
            )
            for b in backupItems {
                if !resolvedItems.contains(where: { $0.id == b.id }) {
                    resolvedItems.append(b)
                }
                if resolvedItems.count >= 15 { break }
            }
        }

        let catID = "gemini.ai.\(UUID().uuidString.prefix(8).lowercased())"
        let finalCatalog = LiveCatalog(
            id: catID,
            name: curation.title,
            type: isSeries ? "series" : "movie",
            endpointPath: nil,
            category: "Gemini AI Curated",
            items: resolvedItems,
            lastUpdated: Date(),
            isEnabled: true
        )

        self.lastGeneratedCatalog = finalCatalog
        self.statusMessage = nil
        return finalCatalog
    }

    // MARK: - Direct Google Gemini REST API Call
    private func callGeminiAPI(prompt: String, apiKey: String) async throws -> GeminiCatalogResponse {
        let models = ["gemini-2.5-flash", "gemini-1.5-flash", "gemini-flash-latest"]
        var lastError: Error?

        for model in models {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15.0

            let systemInstruction = """
            You are a master cinema curator and film historian for the cinephile movie app Somnius.
            The user wants a curated movie or TV show category based on this prompt: "\(prompt)".

            Return ONLY valid JSON matching this exact structure:
            {
              "title": "A short, evocative, stylish category title (e.g. 'Neon-Drenched Neo-Noir' or 'Rainy 90s Paranoia')",
              "description": "A vivid 1-sentence description capturing the mood, atmosphere, and visual aesthetic",
              "type": "movie",
              "movies": [
                {"title": "Exact Movie Title", "year": 2017}
              ]
            }
            Include 16 to 22 real, acclaimed, highly-rated films or series that strictly match the requested theme.
            """

            let requestBody: [String: Any] = [
                "contents": [
                    [
                        "parts": [
                            ["text": systemInstruction]
                        ]
                    ]
                ],
                "generationConfig": [
                    "responseMimeType": "application/json",
                    "temperature": 0.4
                ]
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else { continue }
            request.httpBody = jsonData

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                    struct GeminiPayload: Decodable {
                        struct Candidate: Decodable {
                            struct Content: Decodable {
                                struct Part: Decodable {
                                    let text: String?
                                }
                                let parts: [Part]?
                            }
                            let content: Content?
                        }
                        let candidates: [Candidate]?
                    }

                    let decoded = try JSONDecoder().decode(GeminiPayload.self, from: data)
                    guard let rawText = decoded.candidates?.first?.content?.parts?.first?.text else {
                        throw NSError(domain: "GeminiCatalogService", code: 422, userInfo: [NSLocalizedDescriptionKey: "Empty response from Gemini."])
                    }

                    // Clean code fence if present
                    var cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.hasPrefix("```json") {
                        cleaned = String(cleaned.dropFirst(7))
                    } else if cleaned.hasPrefix("```") {
                        cleaned = String(cleaned.dropFirst(3))
                    }
                    if cleaned.hasSuffix("```") {
                        cleaned = String(cleaned.dropLast(3))
                    }
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

                    if let parsedData = cleaned.data(using: .utf8),
                       let catalogResponse = try? JSONDecoder().decode(GeminiCatalogResponse.self, from: parsedData) {
                        return catalogResponse
                    }
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? NSError(domain: "GeminiCatalogService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to communicate with Gemini API."])
    }

    // MARK: - Smart Semantic Fallback Curation (Zero API Key Requirement)
    private func smartSemanticFallback(prompt: String) async -> GeminiCatalogResponse {
        let lower = prompt.lowercased()

        // 1. Cyberpunk / Sci-Fi
        if lower.contains("cyberpunk") || lower.contains("blade runner") || lower.contains("matrix") || lower.contains("futuristic") || lower.contains("synth") {
            return GeminiCatalogResponse(
                title: "Cyberpunk & Neon Visions",
                description: "Dystopian megalopolises, artificial consciousness, and rain-soaked neon aesthetics.",
                type: "movie",
                movies: [
                    GeminiMovieEntry(title: "Blade Runner 2049", year: 2017),
                    GeminiMovieEntry(title: "The Matrix", year: 1999),
                    GeminiMovieEntry(title: "Akira", year: 1988),
                    GeminiMovieEntry(title: "Ghost in the Shell", year: 1995),
                    GeminiMovieEntry(title: "Upgrade", year: 2018),
                    GeminiMovieEntry(title: "Dark City", year: 1998),
                    GeminiMovieEntry(title: "Children of Men", year: 2006),
                    GeminiMovieEntry(title: "Dredd", year: 2012),
                    GeminiMovieEntry(title: "Alita: Battle Angel", year: 2019),
                    GeminiMovieEntry(title: "RoboCop", year: 1987),
                    GeminiMovieEntry(title: "Minority Report", year: 2002),
                    GeminiMovieEntry(title: "Ex Machina", year: 2014),
                    GeminiMovieEntry(title: "Tron: Legacy", year: 2010),
                    GeminiMovieEntry(title: "Total Recall", year: 1990),
                    GeminiMovieEntry(title: "Her", year: 2013)
                ]
            )
        }

        // 2. Mindfuck / Psychological Thrillers / Time Loop
        if lower.contains("time") || lower.contains("loop") || lower.contains("psychological") || lower.contains("mindfuck") || lower.contains("twist") || lower.contains("puzzle") {
            return GeminiCatalogResponse(
                title: "Mind-Bending Temporal Puzzles",
                description: "Paradoxical time loops, fractured identities, and labyrinthine psychological mysteries.",
                type: "movie",
                movies: [
                    GeminiMovieEntry(title: "Memento", year: 2000),
                    GeminiMovieEntry(title: "Coherence", year: 2013),
                    GeminiMovieEntry(title: "Predestination", year: 2014),
                    GeminiMovieEntry(title: "Primer", year: 2004),
                    GeminiMovieEntry(title: "Shutter Island", year: 2010),
                    GeminiMovieEntry(title: "The Prestige", year: 2006),
                    GeminiMovieEntry(title: "Edge of Tomorrow", year: 2014),
                    GeminiMovieEntry(title: "Source Code", year: 2011),
                    GeminiMovieEntry(title: "Donnie Darko", year: 2001),
                    GeminiMovieEntry(title: "Fight Club", year: 1999),
                    GeminiMovieEntry(title: "Arrival", year: 2016),
                    GeminiMovieEntry(title: "Enemy", year: 2013),
                    GeminiMovieEntry(title: "Triangle", year: 2009),
                    GeminiMovieEntry(title: "12 Monkeys", year: 1995),
                    GeminiMovieEntry(title: "Palm Springs", year: 2020)
                ]
            )
        }

        // 3. Neon Noir / Crime / Rainy Aesthetic
        if lower.contains("noir") || lower.contains("rain") || lower.contains("drive") || lower.contains("detective") || lower.contains("crime") || lower.contains("night") {
            return GeminiCatalogResponse(
                title: "Rain-Slicked Midnight Noir",
                description: "Hypnotic synth scores, brooding loners, and cigarette smoke under sodium vapor streetlights.",
                type: "movie",
                movies: [
                    GeminiMovieEntry(title: "Drive", year: 2011),
                    GeminiMovieEntry(title: "Nightcrawler", year: 2014),
                    GeminiMovieEntry(title: "Taxi Driver", year: 1976),
                    GeminiMovieEntry(title: "Se7en", year: 1995),
                    GeminiMovieEntry(title: "Heat", year: 1995),
                    GeminiMovieEntry(title: "Collateral", year: 2004),
                    GeminiMovieEntry(title: "The Batman", year: 2022),
                    GeminiMovieEntry(title: "Thief", year: 1981),
                    GeminiMovieEntry(title: "Memories of Murder", year: 2003),
                    GeminiMovieEntry(title: "Zodiac", year: 2007),
                    GeminiMovieEntry(title: "Chinatown", year: 1974),
                    GeminiMovieEntry(title: "L.A. Confidential", year: 1997),
                    GeminiMovieEntry(title: "Sicario", year: 2015),
                    GeminiMovieEntry(title: "Prisoners", year: 2013),
                    GeminiMovieEntry(title: "Only God Forgives", year: 2013)
                ]
            )
        }

        // 4. Horror Renaissance / A24 / Atmospheric Dread
        if lower.contains("horror") || lower.contains("a24") || lower.contains("creepy") || lower.contains("dread") || lower.contains("disturbing") || lower.contains("witch") {
            return GeminiCatalogResponse(
                title: "Elevated Folk & Atmospheric Horror",
                description: "Slow-burn psychological dread, pagan folklore, and deeply unsettling auteur nightmares.",
                type: "movie",
                movies: [
                    GeminiMovieEntry(title: "Hereditary", year: 2018),
                    GeminiMovieEntry(title: "The Witch", year: 2015),
                    GeminiMovieEntry(title: "Midsommar", year: 2019),
                    GeminiMovieEntry(title: "The Lighthouse", year: 2019),
                    GeminiMovieEntry(title: "It Follows", year: 2014),
                    GeminiMovieEntry(title: "The Babadook", year: 2014),
                    GeminiMovieEntry(title: "Talk to Me", year: 2022),
                    GeminiMovieEntry(title: "Get Out", year: 2017),
                    GeminiMovieEntry(title: "The Wailing", year: 2016),
                    GeminiMovieEntry(title: "Smile", year: 2022),
                    GeminiMovieEntry(title: "Pearl", year: 2022),
                    GeminiMovieEntry(title: "X", year: 2022),
                    GeminiMovieEntry(title: "The Shining", year: 1980),
                    GeminiMovieEntry(title: "Barbarian", year: 2022),
                    GeminiMovieEntry(title: "Saint Maud", year: 2019)
                ]
            )
        }

        // 5. Cosmic & Deep Space Odysseys
        if lower.contains("space") || lower.contains("cosmic") || lower.contains("alien") || lower.contains("astronaut") || lower.contains("planet") {
            return GeminiCatalogResponse(
                title: "Cosmic Horizons & Deep Space",
                description: "Sublime interstellar journeys, ancient extraterrestrial mysteries, and gravitational wonders.",
                type: "movie",
                movies: [
                    GeminiMovieEntry(title: "Interstellar", year: 2014),
                    GeminiMovieEntry(title: "2001: A Space Odyssey", year: 1968),
                    GeminiMovieEntry(title: "Arrival", year: 2016),
                    GeminiMovieEntry(title: "Alien", year: 1979),
                    GeminiMovieEntry(title: "The Martian", year: 2015),
                    GeminiMovieEntry(title: "Solaris", year: 1972),
                    GeminiMovieEntry(title: "Contact", year: 1997),
                    GeminiMovieEntry(title: "Gravity", year: 2013),
                    GeminiMovieEntry(title: "Ad Astra", year: 2019),
                    GeminiMovieEntry(title: "First Man", year: 2018),
                    GeminiMovieEntry(title: "Moon", year: 2009),
                    GeminiMovieEntry(title: "Sunshine", year: 2007),
                    GeminiMovieEntry(title: "Apollo 13", year: 1995),
                    GeminiMovieEntry(title: "Aliens", year: 1986),
                    GeminiMovieEntry(title: "Dune", year: 2021)
                ]
            )
        }

        // 6. Cozy / Anime / Ghibli / Whimsical
        if lower.contains("cozy") || lower.contains("ghibli") || lower.contains("anime") || lower.contains("whimsical") || lower.contains("warm") || lower.contains("heartwarming") {
            return GeminiCatalogResponse(
                title: "Cozy Nostalgia & Wonder",
                description: "Lush hand-drawn landscapes, gentle magic, and comforting rainy-afternoon cinema.",
                type: "movie",
                movies: [
                    GeminiMovieEntry(title: "Spirited Away", year: 2001),
                    GeminiMovieEntry(title: "My Neighbor Totoro", year: 1988),
                    GeminiMovieEntry(title: "Kiki's Delivery Service", year: 1989),
                    GeminiMovieEntry(title: "Howl's Moving Castle", year: 2004),
                    GeminiMovieEntry(title: "Your Name.", year: 2016),
                    GeminiMovieEntry(title: "A Silent Voice: The Movie", year: 2016),
                    GeminiMovieEntry(title: "Whisper of the Heart", year: 1995),
                    GeminiMovieEntry(title: "Amélie", year: 2001),
                    GeminiMovieEntry(title: "The Grand Budapest Hotel", year: 2014),
                    GeminiMovieEntry(title: "Princess Mononoke", year: 1997),
                    GeminiMovieEntry(title: "Weathering with You", year: 2019),
                    GeminiMovieEntry(title: "Ponyo", year: 2008),
                    GeminiMovieEntry(title: "Fantastic Mr. Fox", year: 2009),
                    GeminiMovieEntry(title: "Paddington 2", year: 2017),
                    GeminiMovieEntry(title: "Suzume", year: 2022)
                ]
            )
        }

        // Default Universal Cinema Selection
        let cleanWords = prompt.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
            .prefix(3)
            .map { $0.capitalized }
            .joined(separator: " ")

        let fallbackTitle = cleanWords.isEmpty ? "Curated Cinema Selection" : "\(cleanWords) Cinema"

        return GeminiCatalogResponse(
            title: fallbackTitle,
            description: "A tailored collection of visually stunning, critically acclaimed films matching '\(prompt)'.",
            type: "movie",
            movies: [
                GeminiMovieEntry(title: "Oppenheimer", year: 2023),
                GeminiMovieEntry(title: "Parasite", year: 2019),
                GeminiMovieEntry(title: "Everything Everywhere All at Once", year: 2022),
                GeminiMovieEntry(title: "No Country for Old Men", year: 2007),
                GeminiMovieEntry(title: "There Will Be Blood", year: 2007),
                GeminiMovieEntry(title: "Whiplash", year: 2014),
                GeminiMovieEntry(title: "Mad Max: Fury Road", year: 2015),
                GeminiMovieEntry(title: "The Departed", year: 2006),
                GeminiMovieEntry(title: "Inglourious Basterds", year: 2009),
                GeminiMovieEntry(title: "Interstellar", year: 2014),
                GeminiMovieEntry(title: "Inception", year: 2010),
                GeminiMovieEntry(title: "Spirited Away", year: 2001),
                GeminiMovieEntry(title: "Pulp Fiction", year: 1994),
                GeminiMovieEntry(title: "The Dark Knight", year: 2008),
                GeminiMovieEntry(title: "Goodfellas", year: 1990)
            ]
        )
    }
}
