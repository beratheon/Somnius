import Foundation

/// Service for querying the official IntroDB API (https://api.introdb.app)
/// to retrieve automated Skip Intro, Recap, Outro/Credits, and Post-Credits boundaries for TV shows and films,
/// as well as submitting segment timestamps via POST /submit.
public final class IntroDBService: @unchecked Sendable {
    public static let shared = IntroDBService()
    
    public static let baseURL = "https://api.introdb.app"
    
    public struct SegmentRange: Sendable, Equatable {
        public let start: Double
        public let end: Double
        public let confidence: Double?
        public let submissionCount: Int?
        
        public init(start: Double, end: Double, confidence: Double? = nil, submissionCount: Int? = nil) {
            self.start = start
            self.end = end
            self.confidence = confidence
            self.submissionCount = submissionCount
        }
    }
    
    public struct MediaTimestamps: Sendable {
        public let intro: SegmentRange?
        public let recap: SegmentRange?
        public let outro: SegmentRange?
        public let postCredits: SegmentRange?
        public let creditsStart: Double?
        
        public init(
            intro: SegmentRange? = nil,
            recap: SegmentRange? = nil,
            outro: SegmentRange? = nil,
            postCredits: SegmentRange? = nil,
            creditsStart: Double? = nil
        ) {
            self.intro = intro
            self.recap = recap
            self.outro = outro
            self.postCredits = postCredits
            self.creditsStart = creditsStart ?? outro?.start
        }
    }
    
    // Official IntroDB API (`https://api.introdb.app`) models per OpenAPI 3.1.0 spec
    private struct APISegmentTimestamp: Decodable {
        let start_sec: Double?
        let end_sec: Double?
        let start_ms: Int?
        let end_ms: Int?
        let confidence: Double?
        let submission_count: Int?
        let updated_at: String?
        
        func toSegmentRange() -> SegmentRange? {
            let startSec: Double
            if let s = start_sec {
                startSec = max(0, s)
            } else if let sms = start_ms {
                startSec = max(0, Double(sms) / 1000.0)
            } else {
                startSec = 0
            }
            
            let endSec: Double
            if let e = end_sec {
                endSec = e
            } else if let ems = end_ms {
                endSec = Double(ems) / 1000.0
            } else {
                return nil
            }
            
            guard endSec > startSec else { return nil }
            return SegmentRange(
                start: startSec,
                end: endSec,
                confidence: confidence,
                submissionCount: submission_count
            )
        }
    }
    
    private struct APISegmentsResponse: Decodable {
        let imdb_id: String?
        let media_type: String?
        let is_movie: Bool?
        let season: Int?
        let episode: Int?
        let intro: APISegmentTimestamp?
        let recap: APISegmentTimestamp?
        let outro: APISegmentTimestamp?
        let post_credits: APISegmentTimestamp?
    }
    
    private struct APISingleSegmentResponse: Decodable {
        let imdb_id: String?
        let season: Int?
        let episode: Int?
        let start_sec: Double?
        let end_sec: Double?
        let start_ms: Int?
        let end_ms: Int?
        let confidence: Double?
        let submission_count: Int?
        
        func toSegmentRange() -> SegmentRange? {
            let ts = APISegmentTimestamp(
                start_sec: start_sec,
                end_sec: end_sec,
                start_ms: start_ms,
                end_ms: end_ms,
                confidence: confidence,
                submission_count: submission_count,
                updated_at: nil
            )
            return ts.toSegmentRange()
        }
    }
    
    public struct SubmitSegmentRequest: Encodable {
        public let imdb_id: String
        public let segment_type: String // "intro", "recap", "outro", "post_credits"
        public let season: Int?
        public let episode: Int?
        public let start_sec: Double
        public let end_sec: Double
    }
    
    private var cache: [String: MediaTimestamps] = [:]
    private let cacheLock = NSLock()
    
    private init() {}
    
    /// Extracts a valid IMDb ID (`tt1234567`) or resolves one via TMDB if only a TMDB ID was supplied.
    private func resolveIMDbID(imdbID: String?, tmdbID: String?, isSeries: Bool) async -> String? {
        if let raw = imdbID?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            if let range = raw.range(of: "tt\\d{7,9}", options: .regularExpression) {
                return String(raw[range])
            }
            if raw.hasPrefix("tt") {
                return raw
            }
        }
        if let rawTmdb = tmdbID?.trimmingCharacters(in: .whitespacesAndNewlines), !rawTmdb.isEmpty {
            if let range = rawTmdb.range(of: "tt\\d{7,9}", options: .regularExpression) {
                return String(rawTmdb[range])
            }
            let stripped = rawTmdb
                .replacingOccurrences(of: "tmdb:", with: "")
                .replacingOccurrences(of: "tvdb:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty {
                let details = await TMDBService().fetchMediaLogoAndDetails(
                    id: stripped,
                    type: isSeries ? .series : .movie
                )
                if let resolved = details.imdbID, resolved.hasPrefix("tt") {
                    return resolved
                }
            }
        }
        return nil
    }
    
    /// Fetches all segment timestamps (`intro`, `recap`, `outro`, `post_credits`) from `https://api.introdb.app/segments`
    /// with fallback to `/intro` and `/outro`.
    public func fetchTimestamps(
        imdbID: String?,
        tmdbID: String?,
        season: Int?,
        episode: Int?,
        durationSeconds: Double? = nil
    ) async -> MediaTimestamps {
        let isTV = (season ?? 0) > 0 && (episode ?? 0) > 0
        guard let cleanIMDb = await resolveIMDbID(imdbID: imdbID, tmdbID: tmdbID, isSeries: isTV) else {
            return MediaTimestamps()
        }
        
        let cacheKey = "\(cleanIMDb)_s\(season ?? 0)_e\(episode ?? 0)"
        
        cacheLock.lock()
        if let existing = cache[cacheKey],
           (existing.intro != nil || existing.recap != nil || existing.outro != nil || existing.postCredits != nil || existing.creditsStart != nil) {
            cacheLock.unlock()
            return existing
        }
        cacheLock.unlock()
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "imdb_id", value: cleanIMDb)
        ]
        if let s = season, let e = episode, s > 0, e > 0 {
            queryItems.append(URLQueryItem(name: "season", value: "\(s)"))
            queryItems.append(URLQueryItem(name: "episode", value: "\(e)"))
        } else {
            queryItems.append(URLQueryItem(name: "is_movie", value: "true"))
        }
        
        // 1. Primary endpoint: GET https://api.introdb.app/segments
        if var comps = URLComponents(string: "\(Self.baseURL)/segments") {
            comps.queryItems = queryItems
            if let url = comps.url {
                var req = URLRequest(url: url)
                req.timeoutInterval = 6.0
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                req.setValue("Somnius/2.0 (macOS; IntroDB Official API)", forHTTPHeaderField: "User-Agent")
                
                if let (data, response) = try? await URLSession.shared.data(for: req),
                   let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let decoded = try? JSONDecoder().decode(APISegmentsResponse.self, from: data) {
                    let introRange = decoded.intro?.toSegmentRange()
                    let recapRange = decoded.recap?.toSegmentRange()
                    let outroRange = decoded.outro?.toSegmentRange()
                    let postCreditsRange = decoded.post_credits?.toSegmentRange()
                    let credStart = outroRange?.start ?? postCreditsRange?.start
                    
                    let result = MediaTimestamps(
                        intro: introRange,
                        recap: recapRange,
                        outro: outroRange,
                        postCredits: postCreditsRange,
                        creditsStart: credStart
                    )
                    if introRange != nil || recapRange != nil || outroRange != nil || postCreditsRange != nil {
                        cacheLock.lock()
                        cache[cacheKey] = result
                        cacheLock.unlock()
                        print("✅ [IntroDBService] Resolved segments via api.introdb.app/segments for \(cacheKey): intro=\(String(describing: introRange)), recap=\(String(describing: recapRange)), outro=\(String(describing: outroRange)), postCredits=\(String(describing: postCreditsRange))")
                        return result
                    }
                }
            }
        }
        
        // 2. Fallback to individual `/intro` and `/outro` endpoints on api.introdb.app
        var fallbackIntro: SegmentRange? = nil
        var fallbackOutro: SegmentRange? = nil
        
        if isTV {
            if var introComps = URLComponents(string: "\(Self.baseURL)/intro") {
                introComps.queryItems = [
                    URLQueryItem(name: "imdb_id", value: cleanIMDb),
                    URLQueryItem(name: "season", value: "\(season ?? 1)"),
                    URLQueryItem(name: "episode", value: "\(episode ?? 1)")
                ]
                if let url = introComps.url {
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 5.0
                    req.setValue("application/json", forHTTPHeaderField: "Accept")
                    if let (data, resp) = try? await URLSession.shared.data(for: req),
                       let http = resp as? HTTPURLResponse, http.statusCode == 200,
                       let decoded = try? JSONDecoder().decode(APISingleSegmentResponse.self, from: data) {
                        fallbackIntro = decoded.toSegmentRange()
                    }
                }
            }
        }
        
        if var outroComps = URLComponents(string: "\(Self.baseURL)/outro") {
            outroComps.queryItems = queryItems
            if let url = outroComps.url {
                var req = URLRequest(url: url)
                req.timeoutInterval = 5.0
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   let http = resp as? HTTPURLResponse, http.statusCode == 200,
                   let decoded = try? JSONDecoder().decode(APISingleSegmentResponse.self, from: data) {
                    fallbackOutro = decoded.toSegmentRange()
                }
            }
        }
        
        if fallbackIntro != nil || fallbackOutro != nil {
            let result = MediaTimestamps(
                intro: fallbackIntro,
                recap: nil,
                outro: fallbackOutro,
                postCredits: nil,
                creditsStart: fallbackOutro?.start
            )
            cacheLock.lock()
            cache[cacheKey] = result
            cacheLock.unlock()
            print("✅ [IntroDBService] Resolved segments via fallback endpoints for \(cacheKey): intro=\(String(describing: fallbackIntro)), outro=\(String(describing: fallbackOutro))")
            return result
        }
        
        return MediaTimestamps()
    }
    
    /// Submits a segment timestamp (`intro`, `recap`, `outro`, `post_credits`) to `POST https://api.introdb.app/submit`.
    public func submitSegment(
        imdbID: String,
        segmentType: String,
        season: Int? = nil,
        episode: Int? = nil,
        startSec: Double,
        endSec: Double,
        apiKey: String? = nil
    ) async -> Bool {
        guard let url = URL(string: "\(Self.baseURL)/submit") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 6.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = apiKey, !key.isEmpty {
            req.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        
        let payload = SubmitSegmentRequest(
            imdb_id: imdbID,
            segment_type: segmentType,
            season: season,
            episode: episode,
            start_sec: startSec,
            end_sec: endSec
        )
        
        guard let body = try? JSONEncoder().encode(payload) else { return false }
        req.httpBody = body
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return true
            }
        } catch {
            return false
        }
        return false
    }
}
