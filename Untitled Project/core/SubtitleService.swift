import Foundation

struct SubtitleCue: Identifiable {
    let id: Int
    let startTime: Double
    let endTime: Double
    let text: String
}

class SubtitleService {
    static let shared = SubtitleService()

    /// Fetches subtitles from Stremio OpenSubtitles v3 for a given IMDb ID and media type
    func fetchSubtitles(imdbID: String, type: MediaItem.MediaType, season: Int? = nil, episode: Int? = nil, preferredLang: String = Config.preferredSubtitleLanguage) async -> [SubtitleTrack] {
        let mediaType = (type == .series) ? "series" : "movie"
        let targetID: String
        if type == .series {
            let s = season ?? 1
            let e = episode ?? 1
            targetID = "\(imdbID):\(s):\(e)"
        } else {
            targetID = imdbID
        }

        let urlString = "https://opensubtitles-v3.strem.io/subtitles/\(mediaType)/\(targetID).json"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4.5
        request.setValue("Stremio/4.4.168 (macOS; x86_64)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return []
            }

            struct RawSubItem: Decodable {
                let id: String?
                let lang: String?
                let url: String?
            }
            struct RawSubResponse: Decodable {
                let subtitles: [RawSubItem]?
            }

            let decoded = try JSONDecoder().decode(RawSubResponse.self, from: data)
            guard let rawSubs = decoded.subtitles else { return [] }

            let tracks = rawSubs.compactMap { sub -> SubtitleTrack? in
                guard let subURLStr = sub.url, let subURL = URL(string: subURLStr), let lang = sub.lang else {
                    return nil
                }
                let cleanLang = lang.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let label = Self.languageName(for: cleanLang)
                return SubtitleTrack(
                    id: sub.id ?? UUID().uuidString,
                    displayName: label,
                    option: nil,
                    externalURL: subURL
                )
            }

            // Sort with preferred language first, then English, then alphabetical
            return tracks.sorted { s1, s2 in
                let n1 = s1.displayName.lowercased()
                let n2 = s2.displayName.lowercased()
                let pref = Self.languageName(for: preferredLang).lowercased()

                if n1.contains(pref) && !n2.contains(pref) { return true }
                if !n1.contains(pref) && n2.contains(pref) { return false }
                if n1.contains("english") && !n2.contains("english") { return true }
                if !n1.contains("english") && n2.contains("english") { return false }
                return s1.displayName < s2.displayName
            }
        } catch {
            return []
        }
    }

    /// Downloads and parses SRT / VTT subtitle tracks into structured cues
    func loadCues(from url: URL) async -> [SubtitleCue] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }

        // Try decoding as UTF-8 or ISO Latin
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return parseSRTOrVTT(text)
    }

    /// Parses SRT or WebVTT string content into time-indexed SubtitleCues
    func parseSRTOrVTT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")

        var index = 0
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            guard !lines.isEmpty else { continue }

            var timeLineIndex = -1
            for (idx, line) in lines.enumerated() {
                if line.contains("-->") {
                    timeLineIndex = idx
                    break
                }
            }

            guard timeLineIndex >= 0 else { continue }
            let timeLine = lines[timeLineIndex]
            let parts = timeLine.components(separatedBy: "-->")
            guard parts.count == 2 else { continue }

            let startSec = parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces))
            let endSec = parseTimestamp(parts[1].trimmingCharacters(in: .whitespaces))

            guard startSec >= 0 && endSec > startSec else { continue }

            let textLines = lines.suffix(from: timeLineIndex + 1)
            let cleanedText = textLines.joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanedText.isEmpty {
                cues.append(SubtitleCue(id: index, startTime: startSec, endTime: endSec, text: cleanedText))
                index += 1
            }
        }

        return cues
    }

    private func parseTimestamp(_ str: String) -> Double {
        // e.g. "00:01:23,456" or "01:23.456"
        let clean = str.components(separatedBy: " ").first ?? str
        let parts = clean.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")

        if parts.count == 3 {
            guard let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) else { return -1 }
            return (h * 3600) + (m * 60) + s
        } else if parts.count == 2 {
            guard let m = Double(parts[0]), let s = Double(parts[1]) else { return -1 }
            return (m * 60) + s
        }
        return -1
    }

    static func languageName(for code: String) -> String {
        let codeLower = code.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch codeLower {
        case "en", "eng": return "English"
        case "fr", "fre", "fra": return "French"
        case "es", "spa": return "Spanish"
        case "de", "ger", "deu": return "German"
        case "it", "ita": return "Italian"
        case "tr", "tur": return "Turkish"
        case "pt", "por": return "Portuguese"
        case "nl", "dut", "nld": return "Dutch"
        case "ru", "rus": return "Russian"
        case "ar", "ara": return "Arabic"
        case "ja", "jpn": return "Japanese"
        case "ko", "kor": return "Korean"
        case "zh", "chi", "zho": return "Chinese"
        case "pl", "pol": return "Polish"
        case "sv", "swe": return "Swedish"
        case "da", "dan": return "Danish"
        case "no", "nor": return "Norwegian"
        case "fi", "fin": return "Finnish"
        case "el", "gre", "ell": return "Greek"
        case "hi", "hin": return "Hindi"
        default:
            return Locale.current.localizedString(forLanguageCode: codeLower)?.capitalized ?? code.uppercased()
        }
    }
}
