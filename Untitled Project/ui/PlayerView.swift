import SwiftUI
import AVKit
import Combine

#if os(macOS)
import AppKit
#endif

// MARK: - Backward-compatible Hover Modifier for Timeline
private struct TimelineHoverModifier: ViewModifier {
    let width: CGFloat
    let onHoverChange: (Bool, Double) -> Void

    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            content.onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let frac = max(0.0, min(1.0, Double(location.x / width)))
                    onHoverChange(true, frac)
                case .ended:
                    onHoverChange(false, 0.0)
                }
            }
        } else {
            content.onHover { isOver in
                onHoverChange(isOver, 0.5)
            }
        }
        #else
        content
        #endif
    }
}

// MARK: - Streaming Scrubber Bar with Hover Tooltip & Buffer Indicator
struct StreamingScrubberBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let bufferedFraction: Double
    var previewBackdrops: [URL] = []
    var capturedFrames: [Int: NSImage] = [:]
    var fallbackURL: URL? = nil
    var onSeek: (Double) -> Void
    var onScrubbingChanged: (Bool) -> Void
    var onHovering: (() -> Void)? = nil

    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragTime: Double = 0
    @State private var hoverFraction: Double = 0

    var body: some View {
        GeometryReader { geo in
            let width = max(1.0, geo.size.width)
            let total = max(duration, 1.0)
            let current = isDragging ? dragTime : currentTime
            let progressFraction = min(1.0, max(0.0, current / total))
            let bufferWidth = width * CGFloat(min(1.0, max(0.0, bufferedFraction)))
            let playedWidth = width * CGFloat(progressFraction)

            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: isHovering || isDragging ? 6 : 3)

                // Buffered Progress Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: bufferWidth, height: isHovering || isDragging ? 6 : 3)

                // Played Progress Track (Clean white)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: playedWidth, height: isHovering || isDragging ? 6 : 3)

                // Scrubbing Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: isHovering || isDragging ? 14 : 0, height: isHovering || isDragging ? 14 : 0)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    .offset(x: max(0, min(width - 14, playedWidth - 7)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .overlay(alignment: .topLeading) {
                // Hover / Scrub Time Tooltip Preview Rectangle (Isolated in overlay so baseline never moves)
                if isHovering || isDragging {
                    let previewTime = isDragging ? dragTime : (hoverFraction * total)
                    let frac = min(1.0, max(0.0, previewTime / total))
                    let cardWidth: CGFloat = 144
                    let cardHeight: CGFloat = 100
                    let halfWidth = cardWidth / 2.0
                    let targetX = (isDragging ? playedWidth : width * CGFloat(hoverFraction))
                    let clampedX = max(halfWidth + 4, min(width - halfWidth - 4, targetX)) - halfWidth

                    // 1. Closest real video frame captured from playback
                    let targetSec = Int(previewTime)
                    let capturedImage: NSImage? = {
                        guard !capturedFrames.isEmpty else { return nil }
                        if let exact = capturedFrames[targetSec] { return exact }
                        if let nearest = capturedFrames.keys.min(by: { abs($0 - targetSec) < abs($1 - targetSec) }),
                           abs(nearest - targetSec) <= 45 {
                            return capturedFrames[nearest]
                        }
                        return nil
                    }()

                    // 2. TMDB Scene Still Image mapped to timeline percentage
                    let sceneURL: URL? = {
                        if !previewBackdrops.isEmpty {
                            let idx = min(previewBackdrops.count - 1, max(0, Int(frac * Double(previewBackdrops.count))))
                            return previewBackdrops[idx]
                        }
                        return fallbackURL
                    }()

                    VStack(spacing: 0) {
                        // 16:9 Scene Preview Thumbnail
                        ZStack {
                            if let img = capturedImage {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                                    .frame(width: cardWidth, height: 75)
                                    .clipped()
                            } else if let u = sceneURL {
                                CachedImage(url: u, maxPixel: 600)
                                    .aspectRatio(16/9, contentMode: .fill)
                                    .frame(width: cardWidth, height: 75)
                                    .clipped()
                            } else {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.black.opacity(0.65)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(width: cardWidth, height: 75)
                            }

                            // Subtle bottom vignette over the image
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 24)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                        .frame(width: cardWidth, height: 75)
                        .clipped()

                        // Time & Percentage Footer Bar
                        HStack(spacing: 4) {
                            Text(formatTime(previewTime))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(frac * 100))%")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 25)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.85), radius: 12, x: 0, y: 4)
                    .offset(x: clampedX, y: -cardHeight - 12)
                    .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onScrubbingChanged(true)
                        }
                        let frac = max(0.0, min(1.0, value.location.x / width))
                        dragTime = frac * total
                    }
                    .onEnded { value in
                        let frac = max(0.0, min(1.0, value.location.x / width))
                        let finalTime = frac * total
                        isDragging = false
                        onScrubbingChanged(false)
                        onSeek(finalTime)
                    }
            )
            #if os(macOS)
            .modifier(TimelineHoverModifier(width: width) { hovering, frac in
                isHovering = hovering
                if hovering {
                    hoverFraction = frac
                    onHovering?()
                }
            })
            #endif
        }
        .frame(height: 18)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}


struct AudioTrackItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let languageCode: String
    let languageName: String
    let formatDetails: String?
    let isSurround: Bool
    let isOriginal: Bool
    let isDubbed: Bool
    let trackID: Int32?

    init(
        id: String = UUID().uuidString,
        displayName: String,
        languageCode: String = "en",
        languageName: String = "English",
        formatDetails: String? = nil,
        isSurround: Bool = false,
        isOriginal: Bool = true,
        isDubbed: Bool = false,
        trackID: Int32? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.languageCode = languageCode
        self.languageName = languageName
        self.formatDetails = formatDetails
        self.isSurround = isSurround
        self.isOriginal = isOriginal
        self.isDubbed = isDubbed
        self.trackID = trackID
    }

    static func == (lhs: AudioTrackItem, rhs: AudioTrackItem) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct SubtitleTrack: Identifiable, Hashable {
    let id: String
    let displayName: String
    let trackID: Int32?
    let option: AVMediaSelectionOption?
    let externalURL: URL?

    init(id: String = UUID().uuidString, displayName: String, trackID: Int32? = nil, option: AVMediaSelectionOption? = nil, externalURL: URL? = nil) {
        self.id = id
        self.displayName = displayName
        self.trackID = trackID
        self.option = option
        self.externalURL = externalURL
    }

    static func == (lhs: SubtitleTrack, rhs: SubtitleTrack) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#if os(macOS)
// MARK: - Center-Fitted High Performance Video Host
final class CenteredVideoContainerView: NSView {
    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        for subview in subviews {
            subview.frame = bounds
        }
    }
}

struct CenteredMPVVideoHost: NSViewRepresentable {
    let engine: MPVPlayerEngine
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let container = CenteredVideoContainerView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.autoresizingMask = [.width, .height]

        let videoView = engine.videoView
        if videoView.superview != container {
            videoView.removeFromSuperview()
            videoView.frame = container.bounds
            videoView.autoresizingMask = [.width, .height]
            container.addSubview(videoView)
        }

        engine.attachView()
        videoView.updateLayerGeometry()
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let videoView = engine.videoView
        if videoView.superview != nsView {
            videoView.removeFromSuperview()
            videoView.frame = nsView.bounds
            videoView.autoresizingMask = [.width, .height]
            nsView.addSubview(videoView)
        }
        if videoView.frame != nsView.bounds && nsView.bounds.width > 0 && nsView.bounds.height > 0 {
            videoView.frame = nsView.bounds
        }
        videoView.updateLayerGeometry()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        MPVPlayerEngine.shared.videoView.removeFromSuperview()
        MPVPlayerEngine.shared.shutdown()
    }
}
#endif

final class InteractionClock {
    var lastInteractionTime: TimeInterval = 0
}

struct PlayerPiPButton: View {
    @ObservedObject var engine = KSPlayerEngine.shared
    var onAction: () -> Void

    var body: some View {
        Button(action: onAction) {
            Image(systemName: engine.isPipActive ? "pip.exit" : "pip.enter")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .help("Picture-in-Picture")
    }
}

struct PlayerBookmarkButton: View {
    let mediaItem: MediaItem
    @ObservedObject var watchlistManager = WatchlistManager.shared
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: watchlistManager.isWatchlisted(id: mediaItem.id) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}

struct PlayerAudioSyncControls: View {
    @ObservedObject var engine = KSPlayerEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lip-Sync Audio Delay")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%+.0f ms", engine.audioDelay * 1000))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(SoftTone.mist.color)
            }

            Slider(
                value: Binding(
                    get: { engine.audioDelay },
                    set: { engine.setAudioDelay($0) }
                ),
                in: -3.0...3.0,
                step: 0.05
            )
            .tint(SoftTone.mist.color)

            HStack {
                Text("-3.0s")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                Spacer()
                Button("Reset (0 ms)") {
                    engine.setAudioDelay(0.0)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)
                .buttonStyle(.plain)
                Spacer()
                Text("+3.0s")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }

            Divider().background(Color.white.opacity(0.1))

            // PAL speedup correction toggle
            Toggle(isOn: Binding(
                get: { engine.palSpeedupEnabled },
                set: { engine.setPALSpeedup($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAL 25fps Speedup Fix")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Pitch-corrects European 25fps broadcasts to 23.976fps")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SoftTone.sage.color))
        }
    }
}

struct PlayerView: View {
    var streamURL: URL?
    @State var mediaItem: MediaItem?
    var currentSeason: Int? = nil
    var currentEpisode: Int? = nil
    var initialLinks: [AggregatedLink] = []
    var onDismiss: () -> Void
    var onReturnHome: (() -> Void)? = nil
    var onSelectRecommendation: ((MediaItem) -> Void)? = nil

    init(
        streamURL: URL?,
        mediaItem: MediaItem?,
        currentSeason: Int? = nil,
        currentEpisode: Int? = nil,
        initialLinks: [AggregatedLink] = [],
        onDismiss: @escaping () -> Void,
        onReturnHome: (() -> Void)? = nil,
        onSelectRecommendation: ((MediaItem) -> Void)? = nil
    ) {
        self.streamURL = streamURL
        self._mediaItem = State(initialValue: mediaItem)
        self.currentSeason = currentSeason
        self.currentEpisode = currentEpisode
        self.initialLinks = initialLinks
        self.onDismiss = onDismiss
        self.onReturnHome = onReturnHome
        self.onSelectRecommendation = onSelectRecommendation
    }

    @ObservedObject private var ksEngine = KSPlayerEngine.shared
    private let watchlistManager = WatchlistManager.shared
    @State private var interactionClock = InteractionClock()
    @State private var activeStreamURL: URL? = nil
    @State private var currentActiveLinkID: String? = nil
    @State private var failedLinkIDs: Set<String> = []
    @State private var failedStreamURLs: Set<String> = []
    @State private var isSkippingFakeStream: Bool = false

    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var bufferedSeconds: Double = 0
    @State private var bufferedFraction: Double = 0
    @State private var previewBackdrops: [URL] = []
    @State private var capturedFrames: [Int: NSImage] = [:]
    @State private var lastSnapshotTime: Double = -999

    // Buffer stall detection & recovery
    @State private var isBuffering: Bool = true
    @State private var selectedScaleMode: VideoScaleMode = .fit
    @State private var stallSecondsCount: Double = 0
    @State private var stallTimer: Timer? = nil
    @State private var cancellables = Set<AnyCancellable>()

    // Video playback controls
    @State private var playbackSpeed: Double = 1.0

    // Auto-hide controls & cursor state
    @State private var showControls: Bool = true
    @State private var hideControlsWorkItem: DispatchWorkItem? = nil

    // Transient play/pause pulse animation
    @State private var showPlayPausePulse: Bool = false
    @State private var isMuted: Bool = false
    @State private var volume: Double = 1.0

    // Resume playback prompt
    @State private var resumeTimeAvailable: Double? = nil
    @State private var showResumeBanner: Bool = false
    @State private var toastMessage: String? = nil
    @State private var isPlayerTornDown: Bool = false

    // Playback error detection
    @State private var playbackError: String? = nil
    @State private var showPlaybackErrorSheet: Bool = false
    @ObservedObject private var adManager = AdPlacementManager.shared

    // Next episode auto-play countdown & pre-caching
    @State private var showNextEpisodeCard: Bool = false
    @State private var nextEpisodeCountdown: Int = 10
    @State private var countdownTimer: Timer? = nil
    @State private var prefetchedNextEpisodeURL: URL? = nil
    @State private var isPrefetchingNextEpisode: Bool = false
    @State private var precacheTask: Task<Void, Never>? = nil

    // Subtitles & Audio Tracks
    @State private var subtitles: [SubtitleTrack] = []
    @State private var selectedSubtitle: SubtitleTrack?
    @State private var subtitlesEnabled: Bool = true
    @State private var subtitleCues: [SubtitleCue] = []
    @State private var currentSubtitleText: String? = nil
    @State private var subtitleOffsetSeconds: Double = 0.0
    @State private var subtitleFontSize: CGFloat = Config.subtitleFontSizePreference
    @State private var subtitleColor: Color = {
        switch Config.subtitleColorPreference.lowercased() {
        case "white": return .white
        case "cyan": return Color(red: 0.52, green: 0.76, blue: 0.91)
        default: return Color(red: 1.0, green: 0.98, blue: 0.44)
        }
    }()
    @State private var subtitleVerticalOffset: Double = Config.subtitleVerticalPosition
    @State private var subtitleHorizontalOffset: Double = Config.subtitleHorizontalPosition
    @State private var isLoadingSubtitles: Bool = false

    @State private var audioTracks: [AudioTrackItem] = []
    @State private var selectedAudioTrack: AudioTrackItem?
    @State private var audioSubtitleTab: Int = 1

    // Source start banner & confirmation modal
    @State private var showSourceStartBanner: Bool = false
    @State private var showQuitConfirmationModal: Bool = false

    // Movie credits shelf & TV next episode & IntroDB segments
    @State private var showMovieCreditsShelf: Bool = false
    @State private var didDismissCreditsShelf: Bool = false
    @State private var didDismissNextEpisodeCardForCurrentEp: Bool = false
    @State private var movieRecommendations: [MediaItem] = []
    @State private var showSkipIntroButton: Bool = false
    @State private var skipButtonLabel: String = "Skip Intro"
    @State private var introStartTimestamp: Double? = nil
    @State private var introEndTimestamp: Double? = nil
    @State private var recapStartTimestamp: Double? = nil
    @State private var recapEndTimestamp: Double? = nil
    @State private var creditsStartTime: Double? = nil

    // Enhanced Subtitle & Audio Drawers (Screenshots 2, 3, 4)
    @State private var showAudioSubtitleDrawer: Bool = false
    @State private var showSubtitleStylingToolbar: Bool = false
    @State private var selectedSubtitleLanguage: String? = nil
    @State private var subtitleTrackFilter: String = "All"
    @State private var subtitleFontName: String = "Inter"
    @State private var subtitleFPS: Double = 23.976
    @State private var subtitleIsBold: Bool = false

    // Popovers & Drawers
    @State private var showAudioPopover: Bool = false
    @State private var showSubtitlePopover: Bool = false
    @State private var showEnginePopover: Bool = false

    // TV Show Episodes Drawer State
    @State private var showEpisodesDrawer: Bool = false
    @State private var playingSeasonNumber: Int = 1
    @State private var playingEpisodeNumber: Int = 1
    @State private var selectedSeasonNumber: Int = 1
    @State private var totalSeasonsCount: Int = 1
    @State private var episodesList: [TVEpisodeItem] = []
    @State private var isLoadingEpisodes: Bool = false
    @State private var isSwitchingEpisode: Bool = false
    @State private var switchingEpisodeTitle: String = ""

    // In-Player Stream Sources & Quality Switcher Drawer
    @State private var showSourcesDrawer: Bool = false
    @State private var availableStreamLinks: [AggregatedLink] = []
    @State private var isLoadingSources: Bool = false

    // Periodic history save tracking
    @State private var lastHistorySaveTime: Date = Date()
    @State private var keyEventMonitor: Any? = nil
    @State private var mouseEventMonitor: Any? = nil

    private let tmdbService = TMDBService()
    private let aggregatorService = AggregatorService()
    private let subtitleService = SubtitleService.shared

    private var isPlayerLoadingOrStalled: Bool {
        if isSwitchingEpisode { return false }
        if showSourcesDrawer || showPlaybackErrorSheet || playbackError != nil { return false }
        if currentTime == 0 && (!isPlaying || isBuffering) { return true }
        if isBuffering && (currentTime == 0 || stallSecondsCount > 2) { return true }
        return false
    }

    private var playerLoadingTitle: String {
        mediaItem?.title ?? "Media Stream"
    }

    private var playerLoadingSubtitle: String {
        if isSwitchingEpisode {
            return switchingEpisodeTitle
        }
        if mediaItem?.type == .series && playingSeasonNumber > 0 && playingEpisodeNumber > 0 {
            return "Season \(playingSeasonNumber), Episode \(playingEpisodeNumber)"
        }
        if stallSecondsCount > 2 {
            return "Buffering media stream..."
        }
        return "Loading media stream..."
    }

    private var currentSourceName: String {
        if let link = availableStreamLinks.first(where: { $0.id == currentActiveLinkID }) {
            return link.title
        }
        return "High-Speed Stream"
    }

    private var activeResolutionBadge: String? {
        if let link = availableStreamLinks.first(where: { $0.id == currentActiveLinkID }) {
            let q = (link.resolutionBadge.isEmpty ? link.quality : link.resolutionBadge).uppercased()
            if q.contains("4K") || q.contains("2160") || q.contains("UHD") { return "UHD" }
            if q.contains("1440") || q.contains("2K") { return "1440P" }
            if q.contains("1080") || q.contains("FHD") { return "FHD" }
            if q.contains("720") || q.contains("HD") { return "HD" }
            if q.contains("480") || q.contains("SD") { return "SD" }
            if !q.isEmpty { return q }
        }
        return nil
    }

    private var activeHDRBadge: String? {
        if let link = availableStreamLinks.first(where: { $0.id == currentActiveLinkID }) {
            if let h = link.hdrTag, !h.isEmpty {
                let u = h.uppercased()
                if u.contains("DV") || u.contains("VISION") { return "DV" }
                if u.contains("HDR10+") { return "HDR10+" }
                if u.contains("HDR") { return "HDR" }
                return h
            }
        }
        if ksEngine.hdrAvailable {
            return "HDR"
        }
        return nil
    }

    private func normalizeLanguageCode(_ raw: String?) -> String {
        guard let input = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return "en"
        }
        switch input {
        case "eng", "en": return "en"
        case "tur", "tr": return "tr"
        case "spa", "es": return "es"
        case "fra", "fre", "fr": return "fr"
        case "deu", "ger", "de": return "de"
        case "ita", "it": return "it"
        case "jpn", "ja": return "ja"
        case "kor", "ko": return "ko"
        case "zho", "chi", "zh": return "zh"
        case "por", "pt": return "pt"
        case "rus", "ru": return "ru"
        case "ara", "ar": return "ar"
        case "hin", "hi": return "hi"
        case "nld", "dut", "nl": return "nl"
        case "swe", "sv": return "sv"
        case "nor", "no": return "no"
        case "dan", "da": return "da"
        case "fin", "fi": return "fi"
        case "pol", "pl": return "pl"
        case "ell", "gre", "el": return "el"
        case "ukr", "uk": return "uk"
        case "ces", "cze", "cs": return "cs"
        case "hun", "hu": return "hu"
        case "ron", "rum", "ro": return "ro"
        case "tha", "th": return "th"
        case "vie", "vi": return "vi"
        case "ind", "id": return "id"
        case "heb", "he": return "he"
        default:
            if input.count == 2 { return input }
            return "en"
        }
    }

    private func languageDisplayName(for codeOrName: String?) -> String? {
        guard let input = codeOrName?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return nil
        }
        let lower = input.lowercased()
        
        switch lower {
        case "en", "eng": return "English"
        case "tr", "tur": return "Turkish"
        case "es", "spa": return "Spanish"
        case "fr", "fra", "fre": return "French"
        case "de", "deu", "ger": return "German"
        case "it", "ita": return "Italian"
        case "ja", "jpn": return "Japanese"
        case "ko", "kor": return "Korean"
        case "zh", "chi", "zho": return "Chinese"
        case "pt", "por": return "Portuguese"
        case "ru", "rus": return "Russian"
        case "ar", "ara": return "Arabic"
        case "hi", "hin": return "Hindi"
        case "nl", "dut", "nld": return "Dutch"
        case "sv", "swe": return "Swedish"
        case "no", "nor": return "Norwegian"
        case "da", "dan": return "Danish"
        case "fi", "fin": return "Finnish"
        case "pl", "pol": return "Polish"
        case "el", "gre", "ell": return "Greek"
        case "uk", "ukr": return "Ukrainian"
        case "cs", "ces", "cze": return "Czech"
        case "hu", "hun": return "Hungarian"
        case "ro", "ron", "rum": return "Romanian"
        case "th", "tha": return "Thai"
        case "vi", "vie": return "Vietnamese"
        case "id", "ind": return "Indonesian"
        case "he", "heb": return "Hebrew"
        default: break
        }
        
        let clean = lower.replacingOccurrences(of: "[^a-z0-9çğışöüáéíóúñàèìòùâêîôûäëïöü]", with: " ", options: .regularExpression)
        let tokens = Set(clean.split(separator: " ").map(String.init))
        
        if tokens.contains("english") || tokens.contains("eng") || tokens.contains("en") { return "English" }
        if tokens.contains("turkish") || tokens.contains("türkçe") || tokens.contains("turkce") || tokens.contains("tur") || tokens.contains("tr") { return "Turkish" }
        if tokens.contains("spanish") || tokens.contains("español") || tokens.contains("espanol") || tokens.contains("castellano") || tokens.contains("latino") || tokens.contains("spa") || tokens.contains("es") { return "Spanish" }
        if tokens.contains("french") || tokens.contains("français") || tokens.contains("francais") || tokens.contains("fra") || tokens.contains("fre") || tokens.contains("fr") { return "French" }
        if tokens.contains("german") || tokens.contains("deutsch") || tokens.contains("ger") || tokens.contains("deu") || tokens.contains("de") { return "German" }
        if tokens.contains("italian") || tokens.contains("italiano") || tokens.contains("ita") || tokens.contains("it") { return "Italian" }
        if tokens.contains("japanese") || tokens.contains("jpn") || tokens.contains("ja") { return "Japanese" }
        if tokens.contains("korean") || tokens.contains("kor") || tokens.contains("ko") { return "Korean" }
        if tokens.contains("chinese") || tokens.contains("mandarin") || tokens.contains("cantonese") || tokens.contains("chi") || tokens.contains("zho") || tokens.contains("zh") { return "Chinese" }
        if tokens.contains("portuguese") || tokens.contains("português") || tokens.contains("portugues") || tokens.contains("por") || tokens.contains("pt") { return "Portuguese" }
        if tokens.contains("russian") || tokens.contains("rus") || tokens.contains("ru") { return "Russian" }
        if tokens.contains("arabic") || tokens.contains("ara") || tokens.contains("ar") { return "Arabic" }
        if tokens.contains("hindi") || tokens.contains("hin") || tokens.contains("hi") { return "Hindi" }
        if tokens.contains("dutch") || tokens.contains("nederlands") || tokens.contains("dut") || tokens.contains("nld") || tokens.contains("nl") { return "Dutch" }
        if tokens.contains("swedish") || tokens.contains("svenska") || tokens.contains("swe") || tokens.contains("sv") { return "Swedish" }
        if tokens.contains("norwegian") || tokens.contains("norsk") || tokens.contains("nor") || tokens.contains("no") { return "Norwegian" }
        if tokens.contains("danish") || tokens.contains("dansk") || tokens.contains("dan") || tokens.contains("da") { return "Danish" }
        if tokens.contains("finnish") || tokens.contains("suomi") || tokens.contains("fin") || tokens.contains("fi") { return "Finnish" }
        if tokens.contains("polish") || tokens.contains("polski") || tokens.contains("pol") || tokens.contains("pl") { return "Polish" }
        if tokens.contains("greek") || tokens.contains("ellinika") || tokens.contains("gre") || tokens.contains("ell") || tokens.contains("el") { return "Greek" }
        
        if let loc = Locale(identifier: "en").localizedString(forLanguageCode: lower), !loc.isEmpty {
            return loc.capitalized
        }
        return nil
    }

    private func languageFlag(for lang: String?) -> String {
        guard let input = lang?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return "🌐"
        }
        let lower = input.lowercased()
        
        switch lower {
        case "en", "eng", "english": return "🇺🇸"
        case "tr", "tur", "turkish", "türkçe", "turkce": return "🇹🇷"
        case "es", "spa", "spanish", "español", "espanol", "castellano", "latino": return "🇪🇸"
        case "fr", "fra", "fre", "french", "français", "francais": return "🇫🇷"
        case "de", "deu", "ger", "german", "deutsch": return "🇩🇪"
        case "it", "ita", "italian", "italiano": return "🇮🇹"
        case "ja", "jpn", "japanese": return "🇯🇵"
        case "ko", "kor", "korean": return "🇰🇷"
        case "zh", "chi", "zho", "chinese", "mandarin", "cantonese": return "🇨🇳"
        case "pt", "por", "portuguese", "português", "portugues": return "🇧🇷"
        case "ru", "rus", "russian": return "🇷🇺"
        case "ar", "ara", "arabic": return "🇸🇦"
        case "hi", "hin", "hindi": return "🇮🇳"
        case "nl", "dut", "nld", "dutch", "nederlands": return "🇳🇱"
        case "sv", "swe", "swedish", "svenska": return "🇸🇪"
        case "no", "nor", "norwegian", "norsk": return "🇳🇴"
        case "da", "dan", "danish", "dansk": return "🇩🇰"
        case "fi", "fin", "finnish", "suomi": return "🇫🇮"
        case "pl", "pol", "polish", "polski": return "🇵🇱"
        case "el", "gre", "ell", "greek": return "🇬🇷"
        default: break
        }
        
        let clean = lower.replacingOccurrences(of: "[^a-z0-9çğışöüáéíóúñàèìòùâêîôûäëïöü]", with: " ", options: .regularExpression)
        let tokens = Set(clean.split(separator: " ").map(String.init))
        
        if tokens.contains("en") || tokens.contains("eng") || tokens.contains("english") { return "🇺🇸" }
        if tokens.contains("tr") || tokens.contains("tur") || tokens.contains("turkish") || tokens.contains("türkçe") || tokens.contains("turkce") { return "🇹🇷" }
        if tokens.contains("es") || tokens.contains("spa") || tokens.contains("spanish") || tokens.contains("español") || tokens.contains("espanol") { return "🇪🇸" }
        if tokens.contains("fr") || tokens.contains("fra") || tokens.contains("fre") || tokens.contains("french") || tokens.contains("français") { return "🇫🇷" }
        if tokens.contains("de") || tokens.contains("deu") || tokens.contains("ger") || tokens.contains("german") || tokens.contains("deutsch") { return "🇩🇪" }
        if tokens.contains("it") || tokens.contains("ita") || tokens.contains("italian") || tokens.contains("italiano") { return "🇮🇹" }
        if tokens.contains("ja") || tokens.contains("jpn") || tokens.contains("japanese") { return "🇯🇵" }
        if tokens.contains("ko") || tokens.contains("kor") || tokens.contains("korean") { return "🇰🇷" }
        if tokens.contains("zh") || tokens.contains("chi") || tokens.contains("zho") || tokens.contains("chinese") { return "🇨🇳" }
        if tokens.contains("pt") || tokens.contains("por") || tokens.contains("portuguese") || tokens.contains("português") { return "🇧🇷" }
        if tokens.contains("ru") || tokens.contains("rus") || tokens.contains("russian") { return "🇷🇺" }
        if tokens.contains("ar") || tokens.contains("ara") || tokens.contains("arabic") { return "🇸🇦" }
        if tokens.contains("hi") || tokens.contains("hin") || tokens.contains("hindi") { return "🇮🇳" }
        if tokens.contains("nl") || tokens.contains("nld") || tokens.contains("dut") || tokens.contains("dutch") { return "🇳🇱" }
        if tokens.contains("sv") || tokens.contains("swe") || tokens.contains("swedish") { return "🇸🇪" }
        if tokens.contains("no") || tokens.contains("nor") || tokens.contains("norwegian") { return "🇳🇴" }
        if tokens.contains("da") || tokens.contains("dan") || tokens.contains("danish") { return "🇩🇰" }
        if tokens.contains("fi") || tokens.contains("fin") || tokens.contains("finnish") { return "🇫🇮" }
        if tokens.contains("pl") || tokens.contains("pol") || tokens.contains("polish") { return "🇵🇱" }
        if tokens.contains("el") || tokens.contains("ell") || tokens.contains("gre") || tokens.contains("greek") { return "🇬🇷" }
        
        return "🌐"
    }

    private func resolveAudioTrack(from track: MPVTrackInfo, isPrimary: Bool) -> AudioTrackItem {
        let origLang = normalizeLanguageCode(mediaItem?.originalLanguage ?? "en")
        
        var detectedCode: String? = nil
        var detectedName: String? = nil
        
        if let lang = track.language, !lang.isEmpty, lang.lowercased() != "und" {
            detectedCode = normalizeLanguageCode(lang)
            detectedName = languageDisplayName(for: lang)
        }
        
        if detectedName == nil {
            if let nameLang = languageDisplayName(for: track.name) {
                detectedName = nameLang
                detectedCode = normalizeLanguageCode(nameLang)
            }
        }
        
        let isOrig: Bool
        if let code = detectedCode {
            isOrig = (code == origLang || (code == "en" && origLang == "en"))
        } else {
            detectedCode = origLang
            detectedName = languageDisplayName(for: origLang) ?? "English"
            isOrig = true
        }
        
        let finalCode = detectedCode ?? "en"
        let finalName = detectedName ?? (languageDisplayName(for: finalCode) ?? "English")
        let isDubbed = !isOrig
        
        var formatString: String? = nil
        let lowerName = track.name.lowercased()
        let hasCodecInName = lowerName.contains("truehd") || lowerName.contains("atmos") || lowerName.contains("dts") || lowerName.contains("ac-3") || lowerName.contains("ac3") || lowerName.contains("eac3") || lowerName.contains("aac") || lowerName.contains("flac") || lowerName.contains("opus") || lowerName.contains("5.1") || lowerName.contains("7.1")
        
        if hasCodecInName {
            var cleanFormat = track.name
            for word in ["English", "english", "ENG", "eng", "Turkish", "turkish", "TUR", "tur", "Spanish", "French", "German", "Italian", "Japanese"] {
                cleanFormat = cleanFormat.replacingOccurrences(of: word, with: "")
            }
            cleanFormat = cleanFormat.trimmingCharacters(in: CharacterSet(charactersIn: "-•[]() "))
            if !cleanFormat.isEmpty {
                formatString = cleanFormat
            }
        } else {
            var parts: [String] = []
            if let codec = track.codec, !codec.isEmpty {
                parts.append(codec.uppercased())
            }
            if let chan = track.channels, !chan.isEmpty {
                parts.append(chan)
            }
            if !parts.isEmpty {
                formatString = parts.joined(separator: " ")
            }
        }
        
        let fullSearch = (track.name + " " + (track.channels ?? "") + " " + (track.codec ?? "")).lowercased()
        let isSurround = fullSearch.contains("5.1") || fullSearch.contains("7.1") || fullSearch.contains("surround") || fullSearch.contains("atmos")
        
        return AudioTrackItem(
            id: "\(track.id)",
            displayName: track.name,
            languageCode: finalCode,
            languageName: finalName,
            formatDetails: formatString,
            isSurround: isSurround,
            isOriginal: isOrig || track.isOriginal,
            isDubbed: isDubbed,
            trackID: track.id
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 1. High Performance libmpv Engine (Apple Silicon VideoToolbox & XDR/EDR)
            if let url = activeStreamURL ?? streamURL {
                CenteredMPVVideoHost(
                    engine: ksEngine,
                    url: url
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                }
            }

            // 2. Active Buffer / Loading Overlay Spinner (Dead-Center Window Overlay)
            if isPlayerLoadingOrStalled {
                ZStack {
                    Color.black.opacity(currentTime > 0 ? 0.40 : 0.90).ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.3)

                        VStack(spacing: 6) {
                            Text(playerLoadingTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            Text(playerLoadingSubtitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SoftTone.mist.color)
                                .multilineTextAlignment(.center)
                        }

                        // Quick actions while buffering
                        HStack(spacing: 12) {
                            Button(action: {
                                exitPlayer()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Cancel")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                userInteracted()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSourcesDrawer = true
                                }
                                if availableStreamLinks.isEmpty {
                                    loadAvailableSources()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Sources")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(SoftTone.sage.color.opacity(0.20))
                                .foregroundColor(SoftTone.sage.color)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)

                        // [SDK Integration Point]: Non-intrusive sponsor banner during stream buffering
                        if let ad = adManager.activePlayerLoadingAd, adManager.isAdsEnabled {
                            AdBannerCardView(ad: ad, placement: .playerLoading)
                                .frame(maxWidth: 420)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.85), radius: 30, x: 0, y: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(100)
                .onAppear {
                    // Request sponsor ad during initial stream loading
                    if currentTime == 0 {
                        Task { await adManager.maybeShowAd(for: .playerLoading) }
                    }
                }
                .onDisappear {
                    // Immediately dismiss sponsor ad when playback starts
                    adManager.dismissAd(for: .playerLoading)
                }
            }

            // 3. Single Movable On-Screen Subtitle Overlay (Supports Horizontal & Vertical Bar Positioning)
            if subtitlesEnabled && selectedSubtitle != nil, let text = currentSubtitleText, !text.isEmpty {
                GeometryReader { geo in
                    let horizShift = CGFloat(subtitleHorizontalOffset / 100.0) * (geo.size.width * 0.42)
                    let baseBottom = CGFloat(subtitleVerticalOffset)
                    let activeBottom = showControls ? max(baseBottom, 115.0) : baseBottom

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(text)
                                .font(
                                    subtitleFontName == "SF Pro" || subtitleFontName == "Inter"
                                        ? .system(size: subtitleFontSize, weight: subtitleIsBold ? .heavy : .semibold, design: .default)
                                        : .custom(subtitleFontName, size: subtitleFontSize).weight(subtitleIsBold ? .heavy : .semibold)
                                )
                                .foregroundColor(subtitleColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 7)
                                .background(Color.black.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                                .offset(x: horizShift)
                            Spacer()
                        }
                        .padding(.bottom, activeBottom)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(150)
            }

            // 4. User interaction overlay
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture(count: 2) {
                    userInteracted()
                    #if os(macOS)
                    if let window = NSApp.keyWindow {
                        window.toggleFullScreen(nil)
                    }
                    #endif
                }
                .onTapGesture(count: 1) {
                    userInteracted()
                    if currentTime > 0 || isPlaying {
                        togglePlayPause()
                    }
                }
                #if os(macOS)
                .onHover { isHovered in
                    if isHovered && !showControls {
                        userInteracted()
                    }
                }
                #endif

            // Bottom Duration Bar Proximity Hover Zone (Makes bar visible when cursor approaches bottom without clicking)
            VStack {
                Spacer()
                Color.clear
                    .frame(height: 140)
                    .contentShape(Rectangle())
                    #if os(macOS)
                    .onHover { isHovered in
                        if isHovered {
                            userInteracted()
                        }
                    }
                    #endif
            }
            .ignoresSafeArea()

            // 5. Center Play/Pause Pulse Icon (Synchronized with bottom-left play/pause control)
            if showPlayPausePulse {
                Image(systemName: isPlaying ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.88))
                    .shadow(color: .black.opacity(0.75), radius: 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .allowsHitTesting(false)
                    .zIndex(210)
            }

            // 6. Episode Switching Spinner
            if isSwitchingEpisode {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        Text(switchingEpisodeTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .transition(.opacity)
                .zIndex(340)
            }

            // 7. Resume Playback Banner Toast
            if showResumeBanner, let rTime = resumeTimeAvailable {
                VStack {
                    HStack(spacing: 14) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Resume Playback?")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("You left off at \(formatTime(rTime))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Button("Resume") {
                            seekTo(rTime)
                            showResumeBanner = false
                            showToast("Resumed at \(formatTime(rTime))")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)

                        Button("Start Over") {
                            seekTo(0)
                            showResumeBanner = false
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.92))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .frame(maxWidth: 420)
                    .padding(.top, 95)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(310)
            }

            // 8. Next Episode Binge Countdown Card (2x Bigger & Positioned Higher Above Controls)
            if showNextEpisodeCard && mediaItem?.type == .series {
                let nextEpItem = episodesList.first(where: { $0.episodeNumber == playingEpisodeNumber + 1 })
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles.tv.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(SoftTone.sand.color)
                                    Text("UP NEXT")
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .tracking(1.6)
                                        .foregroundColor(SoftTone.sand.color)
                                }
                                Spacer()
                                Button(action: cancelNextEpisodeCountdown) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }

                            HStack(spacing: 14) {
                                if let still = nextEpItem?.stillURL ?? mediaItem?.backdropUrl {
                                    CachedImage(url: still, maxPixel: 360)
                                        .frame(width: 132, height: 76)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Season \(playingSeasonNumber) • Episode \(playingEpisodeNumber + 1)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.68))

                                    Text(nextEpItem?.name ?? "Episode \(playingEpisodeNumber + 1)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                }
                            }

                            HStack(spacing: 14) {
                                Button(action: playNextEpisodeNow) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Play Next in \(nextEpisodeCountdown)s")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 11)
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .clipShape(Capsule())
                                    .shadow(color: .white.opacity(0.28), radius: 10)
                                }
                                .buttonStyle(.plain)
                                .shiningRise(isWhitePlay: true)

                                Button(action: cancelNextEpisodeCountdown) {
                                    Text("Cancel")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(24)
                        .frame(width: 460)
                        .background(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1.2)
                        )
                        .shadow(color: .black.opacity(0.85), radius: 28, x: 0, y: 12)
                        .padding(.trailing, 34)
                        .padding(.bottom, showControls ? 132 : 56)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(320)
            }

            // 9. Playback Error Sheet with Dual Engine & External Fallback
            if showPlaybackErrorSheet {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(SoftTone.sand.color)

                        VStack(spacing: 6) {
                            Text("Playback Notice")
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Text(playbackError ?? "This stream couldn't be played. Try again or pick another source.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 480)
                        }

                        VStack(spacing: 12) {
                            Button(action: {
                                showPlaybackErrorSheet = false
                                if let url = activeStreamURL ?? streamURL {
                                    ksEngine.loadStream(url: url, startTime: currentTime)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry Playback")
                                }
                                .font(.headline)
                                .frame(maxWidth: 380)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            // Option 1.5: Auto-try Next Working Stream
                            Button(action: {
                                if availableStreamLinks.isEmpty {
                                    loadAvailableSources()
                                }
                                autoPlayNextBestLink()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bolt.fill")
                                    Text("Auto-Play Next Working Stream")
                                }
                                .font(.headline)
                                .frame(maxWidth: 380)
                                .padding(.vertical, 12)
                                .background(SoftTone.sage.color.opacity(0.2))
                                .foregroundColor(SoftTone.sage.color)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SoftTone.sage.color.opacity(0.35), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)

                            // Option 2: Alternative Sources Drawer
                            Button(action: {
                                showPlaybackErrorSheet = false
                                ksEngine.pause()
                                self.isPlaying = false
                                self.stallTimer?.invalidate()
                                self.stallSecondsCount = 0
                                if availableStreamLinks.isEmpty {
                                    loadAvailableSources()
                                }
                                withAnimation { showSourcesDrawer = true }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "list.bullet")
                                    Text("Choose Another Source")
                                }
                                .font(.headline)
                                .frame(maxWidth: 380)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            Button("Close Player") {
                                showPlaybackErrorSheet = false
                                onDismiss()
                            }
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                        }
                    }
                    .padding(32)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .cornerRadius(20)
                }
                .transition(.opacity)
                .zIndex(350)
            }

            // 10. Floating Top & Bottom Minimalist Controls
            VStack {
                // Top Bar (Streaming Service Minimalist HUD)
                HStack(spacing: 16) {
                    Button(action: {
                        exitPlayer()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)

                    if let media = mediaItem {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(media.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                // Pastel Small Attributes (Resolution & HDR only) - Exact same pastel color as in sources
                                if let res = activeResolutionBadge {
                                    SoftBadge(text: res, tone: .mist)
                                }

                                if let hdr = activeHDRBadge {
                                    SoftBadge(text: hdr, tone: .sand)
                                }
                            }

                            if media.type == .series {
                                Text("Season \(playingSeasonNumber) · Episode \(playingEpisodeNumber)")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }

                    Spacer()

                    // Center: Currently Playing Source Banner
                    if showSourceStartBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(SoftTone.sage.color)
                                .font(.system(size: 11))
                            Text("Source:")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 11, weight: .medium))
                            Text(currentSourceName)
                                .foregroundColor(.white)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Button(action: {
                                userInteracted()
                                ksEngine.pause()
                                self.isPlaying = false
                                withAnimation { showSourcesDrawer = true }
                            }) {
                                Text("Switch")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(SoftTone.sage.color)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.80))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.6), radius: 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    // Right Controls Cluster
                    HStack(spacing: 10) {
                        // Quick Watchlist Toggle
                        if let media = mediaItem {
                            PlayerBookmarkButton(mediaItem: media) {
                                userInteracted()
                                watchlistManager.toggleWatchlist(media)
                            }
                        }

                        // TV Show Episodes Drawer Button
                        if mediaItem?.type == .series {
                            Button(action: {
                                userInteracted()
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showEpisodesDrawer.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "rectangle.grid.1x2")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Episodes")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                        }

                        // Audio & Subtitles Drawer Trigger
                        Button(action: {
                            userInteracted()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showAudioSubtitleDrawer.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: (subtitlesEnabled && selectedSubtitle != nil) ? "captions.bubble.fill" : "captions.bubble")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor((subtitlesEnabled && selectedSubtitle != nil) ? SoftTone.sage.color : .white.opacity(0.85))
                                Text("Audio & Subtitles")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)

                        // Sources & Quality Switcher Button (Pauses playback and opens sources drawer)
                        Button(action: {
                            userInteracted()
                            // Explicitly hard pause video playback to prevent background decode & GPU overhead
                            ksEngine.pause()
                            self.isPlaying = false
                            self.stallTimer?.invalidate()
                            self.stallSecondsCount = 0

                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSourcesDrawer = true
                            }
                            if availableStreamLinks.isEmpty {
                                loadAvailableSources()
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Sources")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 28)
                .padding(.top, 38)
                .padding(.bottom, 24)
                .background(
                    LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                )

                Spacer()

                // Toast Notification
                if let toast = toastMessage {
                    Text(toast)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 12)
                }

                // Bottom Control Bar
                VStack(spacing: 10) {
                    // Custom Scrubber Bar with Buffered Bar & Hover Preview
                    StreamingScrubberBar(
                        currentTime: $currentTime,
                        duration: duration,
                        bufferedFraction: bufferedFraction,
                        previewBackdrops: previewBackdrops,
                        capturedFrames: capturedFrames,
                        fallbackURL: mediaItem?.backdropUrl ?? mediaItem?.posterUrl,
                        onSeek: { targetSec in
                            seekTo(targetSec)
                        },
                        onScrubbingChanged: { _ in
                            userInteracted()
                        },
                        onHovering: {
                            userInteracted()
                        }
                    )

                    // Timestamps & Controls Row (Streaming Service Style)
                    HStack(spacing: 18) {
                        // Play / Pause Toggle (Solid white circle button - 2x bigger for instant click & visibility)
                        Button(action: {
                            userInteracted()
                            togglePlayPause()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 58, height: 58)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .white.opacity(0.28), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)

                        // Skip -10s
                        Button(action: {
                            userInteracted()
                            seekRelative(-10)
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Skip +10s
                        Button(action: {
                            userInteracted()
                            seekRelative(10)
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Next Episode Button (Series only)
                        if mediaItem?.type == .series {
                            Button(action: {
                                userInteracted()
                                playNextEpisodeNow()
                            }) {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                        }

                        // Time display (Current / Total / Remaining)
                        HStack(spacing: 5) {
                            Text(formatTime(currentTime))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)

                            Text("/")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.35))

                            Text(formatTime(duration))
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))

                            if duration > currentTime {
                                Text("(-\(formatTime(duration - currentTime)))")
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }

                        Spacer()

                        // Playback Speed Selector
                        Button(action: {
                            userInteracted()
                            cyclePlaybackSpeed()
                        }) {
                            Text(String(format: "%.2fx", playbackSpeed).replacingOccurrences(of: ".00", with: ""))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)

                        // Video Scale & Aspect Ratio Button
                        Menu {
                            ForEach(VideoScaleMode.allCases) { mode in
                                Button(action: {
                                    userInteracted()
                                    selectedScaleMode = mode
                                    ksEngine.setScaleMode(mode)
                                    showToast("Scale: \(mode.rawValue)")
                                }) {
                                    HStack {
                                        Text(mode.rawValue)
                                        if selectedScaleMode == mode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: selectedScaleMode == .fill ? "arrow.up.left.and.arrow.down.right" : "aspectratio")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedScaleMode == .fit ? .white.opacity(0.9) : .white)
                                .frame(width: 32, height: 32)
                                .background(selectedScaleMode == .fit ? Color.white.opacity(0.12) : Color.white.opacity(0.24))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        }
                        .menuStyle(.borderlessButton)
                        .buttonStyle(.plain)
                        .help("Video Scale & Aspect Ratio (Press 'A' to cycle)")

                        #if os(macOS)
                        // Picture-in-Picture Button (Isolated observed subview)
                        PlayerPiPButton {
                            userInteracted()
                            ksEngine.togglePiP()
                        }
                        #endif

                        // Volume / Mute
                        HStack(spacing: 8) {
                            Button(action: {
                                userInteracted()
                                isMuted.toggle()
                                ksEngine.toggleMute()
                            }) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : (volume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)

                            Slider(value: $volume, in: 0...1) { _ in
                                userInteracted()
                                ksEngine.setVolume(volume)
                                if isMuted && volume > 0 {
                                    isMuted = false
                                    ksEngine.isMuted = false
                                }
                            }
                            .tint(.white)
                            .frame(width: 75)
                        }

                        #if os(macOS)
                        // Fullscreen Toggle Button
                        Button(action: {
                            userInteracted()
                            if let window = NSApp.keyWindow {
                                window.toggleFullScreen(nil)
                            }
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 42)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.4), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                )
                #if os(macOS)
                .onHover { isHovered in
                    if isHovered {
                        userInteracted()
                    }
                }
                #endif
            }
            .opacity(showControls ? 1.0 : 0.0)
            .allowsHitTesting(showControls)
            .animation(.easeInOut(duration: 0.25), value: showControls)
            .zIndex(200)

            // 11. TV Show Seasons & Episodes Side Drawer
            if showEpisodesDrawer {
                episodesSideDrawer
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .transition(.move(edge: .trailing))
                    .zIndex(250)
            }

            // 12. In-Player Stream Sources & Quality Switcher (Centered Modal Window)
            if showSourcesDrawer {
                ZStack {
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSourcesDrawer = false
                            }
                        }

                    sourcesCenterModal
                        .frame(minWidth: 540, idealWidth: 640, maxWidth: 680, minHeight: 380, idealHeight: 460, maxHeight: 520)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.85), radius: 30, x: 0, y: 15)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()
                .zIndex(260)
            }

            // 13. Skip Intro / Skip Recap Floating Button (Official IntroDB API & Chapter integration)
            if showSkipIntroButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            userInteracted()
                            let targetEnd: Double?
                            if let rStart = recapStartTimestamp, let rEnd = recapEndTimestamp, currentTime >= rStart && currentTime < rEnd {
                                targetEnd = rEnd
                            } else {
                                targetEnd = introEndTimestamp ?? ksEngine.chapterIntroRange?.end
                            }
                            if let end = targetEnd {
                                seekTo(end + 0.5)
                                showSkipIntroButton = false
                                showToast(skipButtonLabel == "Skip Recap" ? "Skipped Recap" : "Skipped Intro")
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text(skipButtonLabel)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1.2))
                            .shadow(color: .black.opacity(0.75), radius: 14, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .shiningRise(isWhitePlay: true)
                        .padding(.trailing, 34)
                        .padding(.bottom, showControls ? 130 : 52)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(345)
            }

            // 14. Movie Credits "More Like This" Shelf (Netflix-Style with "Interim somnium finit?" button)
            if showMovieCreditsShelf && mediaItem?.type == .movie {
                VStack(spacing: 0) {
                    Spacer()
                    movieCreditsShelf
                        .padding(.bottom, showControls ? 152 : 56)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(345)
            }

            // 15. Enhanced Audio & Subtitles Drawer (Screenshots 2, 3, 4)
            if showAudioSubtitleDrawer {
                ZStack {
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showAudioSubtitleDrawer = false
                                showSubtitleStylingToolbar = false
                            }
                        }

                    audioSubtitleCenterModal
                        .frame(minWidth: 620, idealWidth: 740, maxWidth: 780, minHeight: 500, idealHeight: 560, maxHeight: 620)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.85), radius: 30, x: 0, y: 15)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()
                .zIndex(350)
            }

            // 16. "Interim somnium finit?" Exit Confirmation Modal
            if showQuitConfirmationModal {
                ZStack {
                    Color.black.opacity(0.70)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showQuitConfirmationModal = false }
                        }

                    quitConfirmationCenterModal
                        .frame(width: 380)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.9), radius: 35)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()
                .zIndex(360)
            }
        }
        .ignoresSafeArea()
        .onReceive(ksEngine.$currentTime) { time in
            onPlayerTick(current: time, total: ksEngine.duration)
        }
        .onReceive(ksEngine.$duration) { dur in
            if dur > 60 && abs(dur - self.duration) >= 1.0 {
                self.duration = dur
                if self.creditsStartTime == nil {
                    self.loadTimestampsAndRecommendations()
                }
            }
        }
        .onReceive(ksEngine.$isBuffering) { buf in
            self.isBuffering = buf
        }
        .onReceive(ksEngine.$isPlaying) { playing in
            self.isPlaying = playing
            if playing {
                self.syncAudioAndSubtitleTracks()
            }
        }
        .onReceive(ksEngine.$availableSubtitleTracks) { _ in
            self.syncAudioAndSubtitleTracks()
        }
        .onReceive(ksEngine.$availableAudioTracks) { _ in
            self.syncAudioAndSubtitleTracks()
        }
        .onReceive(ksEngine.$playbackError) { err in
            if let err = err {
                self.playbackError = err
                self.showPlaybackErrorSheet = true
            }
        }
        .onReceive(ksEngine.$currentScaleMode) { mode in
            self.selectedScaleMode = mode
        }
        .onAppear {
            self.selectedScaleMode = ksEngine.currentScaleMode
            self.isBuffering = true
            #if os(macOS)
            DispatchQueue.main.async {
                if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                    window.titlebarAppearsTransparent = true
                    window.styleMask.insert(.fullSizeContentView)
                }
            }
            #endif
            if let s = currentSeason { playingSeasonNumber = s; selectedSeasonNumber = s }
            if let e = currentEpisode { playingEpisodeNumber = e }
            if !initialLinks.isEmpty {
                availableStreamLinks = initialLinks
                currentActiveLinkID = initialLinks.first?.id
            } else {
                loadAvailableSources()
            }
            setupPlayer()
            setupKeyboardMonitor()
            userInteracted()
            if mediaItem?.type == .series {
                loadTVShowData()
            }
            loadSubtitlesList()
            fetchTimelinePreviews()

            if mediaItem?.originalLanguage == nil, let item = mediaItem {
                Task {
                    let details = await self.tmdbService.fetchMediaLogoAndDetails(id: item.id, imdbID: item.imdbID, type: item.type, title: item.title, year: item.releaseYear)
                    await MainActor.run {
                        if let lang = details.originalLanguage {
                            self.mediaItem?.originalLanguage = lang
                        }
                        if let resolvedIMDb = details.imdbID, self.mediaItem?.imdbID == nil {
                            self.mediaItem?.imdbID = resolvedIMDb
                        }
                        self.syncAudioAndSubtitleTracks()
                    }
                }
            }
        }
        .onDisappear {
            teardownPlayer()
            ksEngine.shutdown()
        }
    }

    // MARK: - Playback Setup & Buffer Optimization
    private func setupPlayer() {
        activeStreamURL = streamURL
        guard let url = activeStreamURL else { return }

        // Clear any leftover state from a previous session
        self.currentTime = 0
        self.duration = 0
        self.currentSubtitleText = nil
        self.subtitleCues = []
        self.selectedSubtitle = nil
        self.showSkipIntroButton = false
        self.showNextEpisodeCard = false
        self.showMovieCreditsShelf = false
        self.didDismissCreditsShelf = false
        self.didDismissNextEpisodeCardForCurrentEp = false
        self.introStartTimestamp = nil
        self.introEndTimestamp = nil
        self.recapStartTimestamp = nil
        self.recapEndTimestamp = nil
        self.creditsStartTime = nil

        // Validate that url is a playable stream scheme (http, https, file)
        guard let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https" || scheme == "file") else {
            playbackError = "Direct stream URL not available or incompatible format. Please select an alternative source."
            showPlaybackErrorSheet = true
            return
        }

        // Automatically resume from where the user left off without asking to start over
        self.showResumeBanner = false
        if let media = mediaItem {
            if let resumeSec = watchlistManager.getResumeTime(id: media.id, season: playingSeasonNumber, episode: playingEpisodeNumber) {
                resumeTimeAvailable = resumeSec
            } else {
                resumeTimeAvailable = nil
            }
        }

        let targetIMDb = mediaItem?.imdbID ?? (mediaItem?.id.hasPrefix("tt") == true ? mediaItem?.id : nil)
        let savedResume = resumeTimeAvailable ?? 0.0

        ksEngine.loadStream(url: url, startTime: savedResume, imdbID: targetIMDb)
        ksEngine.play()
        self.isPlaying = true
        DisplaySleepManager.shared.disableDisplaySleep(reason: mediaItem?.title ?? "Somnius Video Playback")
        setupStallWatchdog()

        // Show start banner indicating stream source for 6 seconds
        showSourceStartBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            withAnimation {
                self.showSourceStartBanner = false
            }
        }

        loadTimestampsAndRecommendations()
    }

    private func loadTimestampsAndRecommendations() {
        guard let media = mediaItem else { return }
        let season = media.type == .series ? playingSeasonNumber : nil
        let episode = media.type == .series ? playingEpisodeNumber : nil
        let currentDur = self.duration > 60 ? self.duration : (ksEngine.duration > 60 ? ksEngine.duration : nil)

        Task {
            var resolvedIMDb = media.imdbID ?? media.resolvedIMDbID
            if resolvedIMDb == nil || !(resolvedIMDb?.hasPrefix("tt") ?? false) {
                let details = await tmdbService.fetchMediaLogoAndDetails(id: media.id, imdbID: media.imdbID, type: media.type, title: media.title, year: media.releaseYear)
                if let imdb = details.imdbID, imdb.hasPrefix("tt") {
                    resolvedIMDb = imdb
                    await MainActor.run {
                        self.mediaItem?.imdbID = imdb
                    }
                }
            }

            let ts = await IntroDBService.shared.fetchTimestamps(
                imdbID: resolvedIMDb,
                tmdbID: media.id,
                season: season,
                episode: episode,
                durationSeconds: currentDur
            )
            await MainActor.run {
                if let intro = ts.intro {
                    self.introStartTimestamp = intro.start
                    self.introEndTimestamp = intro.end
                }
                if let recap = ts.recap {
                    self.recapStartTimestamp = recap.start
                    self.recapEndTimestamp = recap.end
                }
                if let cred = ts.creditsStart {
                    self.creditsStartTime = cred
                }
            }

            if media.type == .movie && self.movieRecommendations.isEmpty {
                var recs = await tmdbService.fetchRecommendations(id: media.id, imdbID: resolvedIMDb, type: .movie, title: media.title, year: media.releaseYear)
                if recs.isEmpty {
                    recs = await tmdbService.fetchSimilarMedia(id: media.id, imdbID: resolvedIMDb, type: .movie, title: media.title, year: media.releaseYear)
                }
                await MainActor.run {
                    self.movieRecommendations = recs
                }
            }
        }
    }

    private func setupStallWatchdog() {
        stallTimer?.invalidate()
        var lastRecordedTime: Double = -1
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                // If user intentionally paused playback after video has already started playing, don't trigger watchdog
                if !self.isPlaying && !self.isBuffering && self.currentTime > 0 {
                    return
                }
                // If currentTime is advancing, playback is completely healthy
                if self.currentTime > 0 && abs(self.currentTime - lastRecordedTime) > 0.05 {
                    lastRecordedTime = self.currentTime
                    if self.isBuffering {
                        self.isBuffering = false
                    }
                    self.stallSecondsCount = 0
                    return
                }

                // If playback is stalled (buffering or hasn't started playing within 7s)
                if self.isBuffering || self.currentTime == 0 {
                    self.stallSecondsCount += 1.0
                    if self.currentTime > 0 {
                        // Mid-playback stall
                        if self.stallSecondsCount == 4.0 {
                            print("[StallWatchdog] Soft kick after 4s")
                            self.ksEngine.play()
                        } else if self.stallSecondsCount >= 10.0 {
                            print("[StallWatchdog] Mid-playback stall (10s). Don't push hard, switching to reliable alternative...")
                            if let curr = self.currentActiveLinkID {
                                self.failedLinkIDs.insert(curr)
                            }
                            if let direct = (self.activeStreamURL ?? self.streamURL)?.absoluteString {
                                self.failedStreamURLs.insert(direct)
                            }
                            self.stallSecondsCount = 0
                            self.ksEngine.pause()
                            self.showToast("Stream stalled. Auto-switching to reliable alternative...")
                            self.autoPlayNextBestLink()
                        }
                    } else {
                        // Initial buffering before playback has started - max 7s so we don't push hard or lock player
                        if self.stallSecondsCount >= 7.0 {
                            print("[StallWatchdog] Initial buffer timeout (7s). Switching to reliable cached candidate...")
                            if let curr = self.currentActiveLinkID {
                                self.failedLinkIDs.insert(curr)
                            }
                            if let direct = (self.activeStreamURL ?? self.streamURL)?.absoluteString {
                                self.failedStreamURLs.insert(direct)
                            }
                            self.stallSecondsCount = 0
                            self.ksEngine.pause()
                            self.showToast("Source slow to start. Auto-switching to reliable cached stream...")
                            self.autoPlayNextBestLink()
                        }
                    }
                } else {
                    self.stallSecondsCount = 0
                }
            }
        }
    }

    private func attemptStallAutoRecovery() {
        stallSecondsCount = 0
        showToast(Config.isDebridMode ? "Reconnecting Debrid stream buffer..." : "Reconnecting stream buffer...")
        guard let url = activeStreamURL ?? streamURL else { return }
        let saved = currentTime
        ksEngine.loadStream(url: url, startTime: saved)
    }

    private func onPlayerTick(current: Double, total: Double) {
        guard current > 0 && !current.isNaN && !current.isInfinite else { return }

        // Throttle UI re-renders: update state every 1.0s or when significant jump/seek occurs
        let timeDiff = abs(current - self.currentTime)
        let shouldUpdateUI = timeDiff >= 1.0 || self.currentTime == 0

        if shouldUpdateUI {
            self.currentTime = current
            if abs(total - self.duration) >= 0.5 {
                self.duration = total
                
                // Anti-Fake-Hoster Detection:
                // If a stream claims to be the movie/show but duration is <= 95 seconds, it is a hoster removal/debrid error clip.
                if Config.autoPlaySkipShortClips && total > 0 && total <= 95 && !self.isSkippingFakeStream {
                    self.isSkippingFakeStream = true
                    if let curr = self.currentActiveLinkID {
                        self.failedLinkIDs.insert(curr)
                    }
                    if let direct = self.activeStreamURL?.absoluteString {
                        self.failedStreamURLs.insert(direct)
                    }
                    self.showToast("Hoster notice / expired clip detected (\(Int(total))s) — Auto-playing next stream...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.autoPlayNextBestLink()
                    }
                }
            }
            let bSec = ksEngine.bufferedTime
            if abs(bSec - self.bufferedSeconds) >= 0.5 {
                self.bufferedSeconds = bSec
            }
            let bFrac = ksEngine.bufferedFraction
            if abs(bFrac - self.bufferedFraction) >= 0.05 {
                self.bufferedFraction = bFrac
            }
            if self.isPlaying != ksEngine.isPlaying {
                self.isPlaying = ksEngine.isPlaying
            }
        }

        if current > 0 {
            if self.isBuffering {
                self.isBuffering = false
            }
            self.stallSecondsCount = 0

            // Periodic frame snapshot for timeline scrubber preview
            if self.isPlaying && current > 2 && abs(current - self.lastSnapshotTime) >= 10.0 {
                self.lastSnapshotTime = current
                let snapSec = Int(current)
                let tempDir = FileManager.default.temporaryDirectory
                let filePath = tempDir.appendingPathComponent("somnius_snap_\(snapSec).jpg").path
                ksEngine.captureSnapshot(toPath: filePath)
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35) {
                    if let img = NSImage(contentsOfFile: filePath) {
                        DispatchQueue.main.async {
                            self.capturedFrames[snapSec] = img
                        }
                    }
                    try? FileManager.default.removeItem(atPath: filePath)
                }
            }
        }

        // Strict Single-Subtitle Update (respects subtitlesEnabled and selectedSubtitle)
        if subtitlesEnabled, let sel = selectedSubtitle {
            if sel.trackID != nil {
                let embedded = ksEngine.currentEmbeddedSubtitleText
                if self.currentSubtitleText != embedded {
                    self.currentSubtitleText = embedded
                }
            } else if sel.externalURL != nil {
                updateSubtitleCue(currentSecond: current)
            }
        } else {
            if self.currentSubtitleText != nil {
                self.currentSubtitleText = nil
            }
        }

        // Auto-save history every 25 seconds while playing (and on exit) to avoid main-thread disk churn
        if self.isPlaying && current > 5 && Date().timeIntervalSince(self.lastHistorySaveTime) > 25.0 {
            self.saveCurrentHistoryProgress()
        }

        if shouldUpdateUI {
            // Zero-latency next episode pre-caching (< 75 seconds remaining)
            self.checkPrecacheNextEpisode(currentSec: current)

            // Skip Intro / Skip Recap Detection (Official IntroDB API + MKV Chapter integration)
            let introStart = self.introStartTimestamp ?? self.ksEngine.chapterIntroRange?.start
            let introEnd = self.introEndTimestamp ?? self.ksEngine.chapterIntroRange?.end
            let inRecap: Bool = {
                if let rStart = self.recapStartTimestamp, let rEnd = self.recapEndTimestamp, rEnd > rStart {
                    return current >= rStart && current < (rEnd - 1.0)
                }
                return false
            }()
            let inIntro: Bool = {
                if let start = introStart, let end = introEnd, end > start {
                    return current >= start && current < (end - 1.0)
                }
                return false
            }()

            if (inRecap || inIntro) && Config.skipIntroMode != "off" {
                let targetEnd = inRecap ? (self.recapEndTimestamp ?? 0) : (introEnd ?? 0)
                let label = inRecap ? "Skip Recap" : "Skip Intro"
                if Config.skipIntroMode == "auto" && targetEnd > current {
                    self.seekTo(targetEnd + 0.5)
                    self.showSkipIntroButton = false
                    self.showToast(inRecap ? "Skipped Recap" : "Skipped Intro")
                } else {
                    self.skipButtonLabel = label
                    if !self.showSkipIntroButton {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.showSkipIntroButton = true
                        }
                    }
                }
            } else if self.showSkipIntroButton {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.showSkipIntroButton = false
                }
            }

            // TV Show Next Episode Trigger (Before credits / before end)
            if self.mediaItem?.type == .series && self.duration > 60 {
                let cred = self.creditsStartTime ?? self.ksEngine.chapterCreditsStart
                let triggerThreshold: Double
                if let cred = cred, cred > 30 && cred < self.duration {
                    triggerThreshold = max(30, cred - 5.0)
                } else {
                    triggerThreshold = max(30, self.duration - 25.0)
                }
                if current >= triggerThreshold {
                    if !self.showNextEpisodeCard && !self.didDismissNextEpisodeCardForCurrentEp && Config.autoPlayNextEpisode {
                        self.triggerNextEpisodeCountdown()
                    }
                } else if current < triggerThreshold - 10 {
                    self.didDismissNextEpisodeCardForCurrentEp = false
                }
            }

            // Movie Credits "More Like This" Shelf (Netflix-Style)
            if self.mediaItem?.type == .movie && self.duration > 180 {
                let cred = self.creditsStartTime ?? self.ksEngine.chapterCreditsStart
                let triggerThreshold: Double
                if let cred = cred, cred > 120 && cred < self.duration {
                    triggerThreshold = cred
                } else {
                    let heuristicCreditsOffset = min(240.0, max(60.0, self.duration * 0.06))
                    triggerThreshold = max(120, self.duration - heuristicCreditsOffset)
                }
                if current >= triggerThreshold {
                    if !self.showMovieCreditsShelf && !self.didDismissCreditsShelf {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            self.showMovieCreditsShelf = true
                        }
                    }
                } else if current < triggerThreshold - 10 {
                    self.didDismissCreditsShelf = false
                }
            }
        }
    }

    private func onPlayerStateChanged(state: KSPlayerState) {
        if state == .buffering {
            // Only flag buffering if playback hasn't started or currentTime is not moving
            if !self.isPlaying || self.currentTime == 0 {
                self.isBuffering = true
            }
        } else if state == .readyToPlay || state == .bufferFinished {
            self.isBuffering = false
            self.stallSecondsCount = 0
            self.isPlaying = true
            if state == .readyToPlay {
                self.syncAudioAndSubtitleTracks()
            }
        } else if state == .paused {
            self.isPlaying = false
        } else if state == .error {
            self.isBuffering = false
            self.isPlaying = false
            print("[PlayerView] Stream error reported by engine. Auto-switching to reliable alternative...")
            if let curr = self.currentActiveLinkID {
                self.failedLinkIDs.insert(curr)
            }
            if let direct = (self.activeStreamURL ?? self.streamURL)?.absoluteString {
                self.failedStreamURLs.insert(direct)
            }
            self.ksEngine.pause()

            // If we have remaining alternative sources, seamlessly switch without breaking playback
            let remaining = self.availableStreamLinks.filter { !self.failedLinkIDs.contains($0.id) && $0.id != self.currentActiveLinkID }
            if !remaining.isEmpty {
                self.showToast("Source unavailable. Switching to reliable alternative...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.autoPlayNextBestLink()
                }
            } else {
                self.playbackError = ksEngine.playbackError ?? "Playback error"
                self.showPlaybackErrorSheet = true
            }
        }
    }

    private func syncAudioAndSubtitleTracks() {
        // Sync audio tracks with intelligent language & original voice detection
        let available = ksEngine.availableAudioTracks
        self.audioTracks = available.enumerated().map { index, track in
            resolveAudioTrack(from: track, isPrimary: index == 0)
        }
        if let activeId = ksEngine.selectedAudioTrackId {
            self.selectedAudioTrack = self.audioTracks.first { $0.trackID == activeId }
        } else if self.selectedAudioTrack == nil {
            self.selectedAudioTrack = self.audioTracks.first
        }

        // Sync subtitle tracks with OpenSubtitles external sources FIRST so OpenSubtitles is always prioritized
        let embeddedSubs = ksEngine.availableSubtitleTracks.map { track in
            SubtitleTrack(id: "embedded_\(track.id)", displayName: "\(track.name) [Embedded]", trackID: track.id, externalURL: nil)
        }
        let externalSubs = self.subtitles.filter { $0.trackID == nil }
        self.subtitles = externalSubs + embeddedSubs

        guard self.subtitlesEnabled else {
            ksEngine.selectSubtitleTrack(id: nil)
            return
        }

        // If user already has an external OpenSubtitles track selected, preserve it
        if let currentSel = self.selectedSubtitle, currentSel.externalURL != nil {
            return
        }

        // Wait for OpenSubtitles lookup before falling back to embedded container tracks
        if self.isLoadingSubtitles {
            return
        }

        if self.selectedSubtitle == nil, !self.subtitles.isEmpty {
            enableSubtitlesDefaultTrack(silent: true)
        }
    }

    private func cycleVideoGravity() {
        let next = ksEngine.cycleScaleMode()
        selectedScaleMode = next
        showToast("Scale: \(next.rawValue)")
    }

    private func cyclePlaybackSpeed() {
        let speeds = [0.75, 1.0, 1.25, 1.5, 2.0]
        if let idx = speeds.firstIndex(of: playbackSpeed) {
            let nextIdx = (idx + 1) % speeds.count
            playbackSpeed = speeds[nextIdx]
        } else {
            playbackSpeed = 1.0
        }
        ksEngine.setRate(playbackSpeed)
        showToast("Playback Speed: \(String(format: "%.2fx", playbackSpeed).replacingOccurrences(of: ".00", with: ""))")
    }

    private func checkPrecacheNextEpisode(currentSec: Double) {
        guard mediaItem?.type == .series, duration > 90, currentSec >= (duration - 75.0) else { return }
        guard prefetchedNextEpisodeURL == nil, !isPrefetchingNextEpisode else { return }
        isPrefetchingNextEpisode = true
        let nextEp = playingEpisodeNumber + 1
        guard let media = mediaItem else { return }

        precacheTask?.cancel()
        precacheTask = Task {
            if Task.isCancelled { return }
            print("[PlayerView] Pre-caching next episode S\(playingSeasonNumber) E\(nextEp)...")
            if let links = try? await aggregatorService.fetchBestLinks(
                tmdbID: media.id,
                imdbID: media.resolvedIMDbID ?? media.imdbID,
                type: .series,
                title: media.title,
                year: media.releaseYear,
                season: playingSeasonNumber,
                episode: nextEp
            ), let top = links.first {
                if Task.isCancelled { return }
                if let (resURL, _) = try? await aggregatorService.resolveStreamURLWithFallback(startingLink: top, allLinks: links) {
                    if Task.isCancelled { return }
                    await MainActor.run {
                        self.prefetchedNextEpisodeURL = resURL
                        print("[PlayerView] Successfully pre-cached stream for next episode!")
                    }
                }
            }
        }
    }

    private func saveCurrentHistoryProgress() {
        guard let media = mediaItem else { return }
        lastHistorySaveTime = Date()
        watchlistManager.recordHistory(
            item: media,
            season: playingSeasonNumber,
            episode: playingEpisodeNumber,
            progress: currentTime,
            duration: duration
        )
    }

    private func teardownPlayer() {
        guard !isPlayerTornDown else {
            ksEngine.shutdown()
            return
        }
        isPlayerTornDown = true
        precacheTask?.cancel()
        precacheTask = nil
        hideControlsWorkItem?.cancel()
        countdownTimer?.invalidate()
        stallTimer?.invalidate()
        cancellables.removeAll()
        saveCurrentHistoryProgress()
        #if os(macOS)
        if let mon = keyEventMonitor {
            NSEvent.removeMonitor(mon)
            keyEventMonitor = nil
        }
        if let mon = mouseEventMonitor {
            NSEvent.removeMonitor(mon)
            mouseEventMonitor = nil
        }
        NSCursor.unhide()
        #endif
        self.currentSubtitleText = nil
        self.subtitleCues = []
        self.currentTime = 0
        self.duration = 0
        DisplaySleepManager.shared.enableDisplaySleep()
        self.ksEngine.shutdown()
        AggregatorService.stopAndCleanAllTorrentMissions()
    }

    private func exitPlayer(returnHome: Bool = false) {
        teardownPlayer()

        #if os(macOS)
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) {
                // Exit fullscreen if active
                if window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }

                // If window size became smaller than ideal standard size (e.g. shrunk down during player use),
                // smoothly expand back to a comfortable minimum standard frame
                let currentFrame = window.frame
                if currentFrame.width < 1200 || currentFrame.height < 750 {
                    let screen = window.screen ?? NSScreen.main
                    let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                    let targetWidth = min(1400.0, screenFrame.width * 0.9)
                    let targetHeight = min(900.0, screenFrame.height * 0.9)
                    let targetX = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2.0
                    let targetY = screenFrame.origin.y + (screenFrame.height - targetHeight) / 2.0
                    let restoredFrame = NSRect(x: targetX, y: targetY, width: targetWidth, height: targetHeight)
                    window.setFrame(restoredFrame, display: true, animate: true)
                }
            }
        }
        #endif

        if returnHome, let onReturnHome = onReturnHome {
            onReturnHome()
        } else {
            onDismiss()
        }
    }

    // MARK: - In-Player Alternative Sources Drawer
    private func sourceTitle(for link: AggregatedLink, index: Int) -> String {
        let base = mediaItem?.title ?? "Source"
        if mediaItem?.type == .series && playingSeasonNumber > 0 && playingEpisodeNumber > 0 {
            return "\(base) S\(playingSeasonNumber)E\(playingEpisodeNumber) #\(index)"
        }
        return "\(base) #\(index)"
    }

    private func loadAvailableSources() {
        guard let media = mediaItem else { return }
        isLoadingSources = true
        var lastBatchTime: Date = .distantPast
        Task {
            do {
                let links = try await aggregatorService.fetchBestLinks(
                    tmdbID: media.id,
                    imdbID: media.resolvedIMDbID ?? media.imdbID,
                    type: media.type,
                    title: media.title,
                    year: media.releaseYear,
                    season: playingSeasonNumber,
                    episode: playingEpisodeNumber,
                    onBatch: { partialLinks in
                        let now = Date()
                        guard now.timeIntervalSince(lastBatchTime) >= 0.35 else { return }
                        lastBatchTime = now
                        Task { @MainActor in
                            self.availableStreamLinks = partialLinks
                        }
                    }
                )
                await MainActor.run {
                    self.availableStreamLinks = links
                    self.isLoadingSources = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSources = false
                }
            }
        }
    }

    private func switchToLink(_ link: AggregatedLink) {
        let savedTime = currentTime
        showToast("Resolving \(link.resolutionBadge)...")
        withAnimation { showSourcesDrawer = false }

        Task {
            do {
                let (newURL, _) = try await aggregatorService.resolveStreamURLWithFallback(startingLink: link, allLinks: availableStreamLinks)
                await MainActor.run {
                    self.currentActiveLinkID = link.id
                    self.activeStreamURL = newURL
                    self.isSkippingFakeStream = false
                    self.ksEngine.loadStream(url: newURL, startTime: savedTime)
                    self.ksEngine.play()
                    self.showToast("Switched to \(link.resolutionBadge) at \(formatTime(savedTime))")
                }
            } catch {
                await MainActor.run {
                    self.showToast("Failed to switch source: \(error.localizedDescription)")
                }
            }
        }
    }

    private func autoPlayNextBestLink() {
        let savedTime = currentTime
        showToast("Finding best working stream...")
        withAnimation { 
            showSourcesDrawer = false
            showPlaybackErrorSheet = false
        }

        Task {
            do {
                // If sources not loaded yet, fetch them now
                if self.availableStreamLinks.isEmpty, let media = self.mediaItem {
                    let links = (try? await self.aggregatorService.fetchBestLinks(
                        tmdbID: media.id,
                        imdbID: media.resolvedIMDbID ?? media.imdbID,
                        type: media.type,
                        title: media.title,
                        year: media.releaseYear,
                        season: self.playingSeasonNumber,
                        episode: self.playingEpisodeNumber
                    )) ?? []
                    await MainActor.run {
                        self.availableStreamLinks = links
                    }
                }

                var candidates = self.availableStreamLinks.filter { link in
                    // Filter out already failed link IDs or current link
                    if self.failedLinkIDs.contains(link.id) { return false }
                    if let cur = self.currentActiveLinkID, link.id == cur { return false }
                    if let direct = link.url?.absoluteString, self.failedStreamURLs.contains(direct) { return false }
                    return true
                }

                // If all candidate streams were filtered, fallback to remaining un-failed candidates
                if candidates.isEmpty {
                    candidates = self.availableStreamLinks.filter { link in
                        if self.failedLinkIDs.contains(link.id) { return false }
                        return true
                    }
                }

                guard let firstChoice = AggregatedLink.selectBestStream(
                    from: candidates,
                    targetTitle: self.mediaItem?.title,
                    targetYear: self.mediaItem?.releaseYear
                ) ?? candidates.first else {
                    await MainActor.run {
                        self.isBuffering = false
                        self.showToast("No playable media sources available for this title.")
                        self.isSkippingFakeStream = false
                    }
                    return
                }

                let (newURL, pickedLink) = try await self.aggregatorService.resolveStreamURLWithFallback(startingLink: firstChoice, allLinks: candidates)
                await MainActor.run {
                    guard self.mediaItem != nil else { return }
                    self.currentActiveLinkID = pickedLink.id
                    self.activeStreamURL = newURL
                    self.isSkippingFakeStream = false
                    self.ksEngine.loadStream(url: newURL, startTime: savedTime)
                    self.ksEngine.play()
                    let sz = pickedLink.sizeString != nil ? " • \(pickedLink.sizeString!)" : ""
                    self.showToast("Auto-playing \(pickedLink.resolutionBadge)\(sz)")
                }
            } catch {
                await MainActor.run {
                    self.isSkippingFakeStream = false
                    self.showToast("Auto-play failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private var sourcesCenterModal: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Select Stream Source")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(availableStreamLinks.isEmpty ? "Searching indexers…" : "\(availableStreamLinks.count) streams available • Playback paused")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                // Auto Play / Next Working Button
                Button(action: { autoPlayNextBestLink() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                        Text("Auto Play")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(SoftTone.sage.color.opacity(0.18))
                    .foregroundColor(SoftTone.sage.color)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(SoftTone.sage.color.opacity(0.35), lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                if let bestUHD = availableStreamLinks.first(where: { $0.quality == "4K" && (!Config.showOnlyCachedResults || $0.isCached) }) {
                    Button(action: { switchToLink(bestUHD) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                            Text("Best UHD")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(SoftTone.sand.color.opacity(0.18))
                        .foregroundColor(SoftTone.sand.color)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(SoftTone.sand.color.opacity(0.35), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }

                if let bestFHD = availableStreamLinks.first(where: { $0.quality == "FHD" && (!Config.showOnlyCachedResults || $0.isCached) }) {
                    Button(action: { switchToLink(bestFHD) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.circle.fill")
                            Text("Best FHD")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(SoftTone.mist.color.opacity(0.18))
                        .foregroundColor(SoftTone.mist.color)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(SoftTone.mist.color.opacity(0.35), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showSourcesDrawer = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.45))

            if isLoadingSources {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView().tint(.white).scaleEffect(1.2)
                    Text("Finding streams from decentralized indexers…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if availableStreamLinks.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 38))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No alternative streams found")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("All installed add-on indexers returned no additional playable sources.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(availableStreamLinks.enumerated()), id: \.element.id) { index, link in
                            Button(action: {
                                switchToLink(link)
                            }) {
                                HStack(alignment: .center, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack(alignment: .center, spacing: 8) {
                                            Text(sourceTitle(for: link, index: index + 1))
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)

                                            StreamAttributeRow(link: link)
                                        }
                                    }

                                    Spacer()

                                    // Download Button for this source
                                    if let media = mediaItem {
                                        Button(action: {
                                            DownloadManager.shared.startDownloadWithSource(item: media, link: link)
                                            showToast("Downloading \(link.resolutionBadge) source...")
                                        }) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(SoftTone.mist.color)
                                                .frame(width: 32, height: 32)
                                                .background(SoftTone.mist.color.opacity(0.15))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Download this source")
                                    }

                                    // Play Stream
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 30, height: 30)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subtitles Management & Sync
    private func loadSubtitlesList() {
        guard let item = mediaItem else { return }
        isLoadingSubtitles = true

        Task {
            var resolvedIMDb = item.imdbID ?? item.resolvedIMDbID ?? (item.id.hasPrefix("tt") ? item.id : nil)
            if resolvedIMDb == nil || !(resolvedIMDb?.hasPrefix("tt") ?? false) {
                let details = await tmdbService.fetchMediaLogoAndDetails(id: item.id, imdbID: item.imdbID, type: item.type, title: item.title, year: item.releaseYear)
                if let imdb = details.imdbID, imdb.hasPrefix("tt") {
                    resolvedIMDb = imdb
                    await MainActor.run {
                        self.mediaItem?.imdbID = imdb
                    }
                }
            }

            let queryID = resolvedIMDb ?? item.id
            let fetched = await subtitleService.fetchSubtitles(
                imdbID: queryID,
                type: item.type,
                season: playingSeasonNumber,
                episode: playingEpisodeNumber
            )

            await MainActor.run {
                let embeddedOnly = self.subtitles.filter { $0.trackID != nil }
                let localOnly = self.subtitles.filter { $0.id.hasPrefix("local_") }
                // Place local and OpenSubtitles external tracks FIRST before embedded container tracks
                self.subtitles = localOnly + fetched + embeddedOnly
                self.isLoadingSubtitles = false

                // Auto-select preferred OpenSubtitles language if subtitles are enabled and no external track is active
                if self.subtitlesEnabled && (self.selectedSubtitle == nil || self.selectedSubtitle?.trackID != nil) {
                    self.enableSubtitlesDefaultTrack(silent: true)
                }
            }
        }
    }

    private func enableSubtitlesDefaultTrack(silent: Bool = false) {
        subtitlesEnabled = true
        let prefName = SubtitleService.languageName(for: Config.preferredSubtitleLanguage).lowercased()
        let prefCode = Config.preferredSubtitleLanguage.lowercased()

        let externalPool = subtitles.filter { $0.trackID == nil && $0.externalURL != nil }
        let preferredExternal = externalPool.first(where: {
            let lower = $0.displayName.lowercased()
            return lower.contains(prefName) || lower.contains("(\(prefCode))")
        }) ?? externalPool.first(where: {
            $0.displayName.lowercased().contains("english")
        }) ?? externalPool.first

        let preferredAny = preferredExternal ?? subtitles.first(where: {
            let lower = $0.displayName.lowercased()
            return lower.contains(prefName) || lower.contains("(\(prefCode))")
        }) ?? subtitles.first

        if let chosen = preferredAny {
            selectSubtitleTrack(chosen, silent: silent)
        } else if !silent {
            showToast("Subtitles On — Searching OpenSubtitles...")
            loadSubtitlesList()
        }
    }

    private func selectSubtitleTrack(_ track: SubtitleTrack, silent: Bool = false) {
        subtitlesEnabled = true
        selectedSubtitle = track
        currentSubtitleText = nil
        subtitleCues = []

        if let tid = track.trackID {
            ksEngine.selectSubtitleTrack(id: tid)
            if let embedded = ksEngine.currentEmbeddedSubtitleText {
                currentSubtitleText = embedded
            }
            if !silent {
                showToast("Subtitle: \(track.displayName)")
            }
        } else if let externalURL = track.externalURL {
            ksEngine.selectSubtitleTrack(id: nil)
            if !silent {
                showToast("Loading \(track.displayName)...")
            }
            let targetTrackID = track.id
            let targetLang = subtitleLanguage(for: track).lowercased()
            Task {
                var cues = await subtitleService.loadCues(from: externalURL)
                var chosenTrack = track
                // If this specific OpenSubtitles release file returned empty, try up to 2 sibling OpenSubtitles tracks of the same language
                if cues.isEmpty {
                    let fallbacks = await MainActor.run {
                        self.subtitles.filter {
                            $0.id != targetTrackID &&
                            $0.externalURL != nil &&
                            self.subtitleLanguage(for: $0).lowercased() == targetLang
                        }.prefix(2)
                    }
                    for alt in fallbacks {
                        if let altURL = alt.externalURL {
                            let altCues = await subtitleService.loadCues(from: altURL)
                            if !altCues.isEmpty {
                                cues = altCues
                                chosenTrack = alt
                                break
                            }
                        }
                    }
                }
                await MainActor.run {
                    guard self.selectedSubtitle?.id == targetTrackID, self.subtitlesEnabled else { return }
                    self.selectedSubtitle = chosenTrack
                    self.subtitleCues = cues
                    self.updateSubtitleCue(currentSecond: self.currentTime)
                    if !silent {
                        if !cues.isEmpty {
                            self.showToast("Subtitle Active: \(chosenTrack.displayName)")
                        } else {
                            self.showToast("Subtitle file empty — try another release")
                        }
                    }
                }
            }
        }
    }

    private func disableSubtitles() {
        subtitlesEnabled = false
        selectedSubtitle = nil
        currentSubtitleText = nil
        subtitleCues = []
        ksEngine.selectSubtitleTrack(id: nil)
        showToast("Subtitles Off")
    }

    private func updateSubtitleCue(currentSecond: Double) {
        guard subtitlesEnabled, !subtitleCues.isEmpty else {
            if currentSubtitleText != nil {
                currentSubtitleText = nil
            }
            return
        }
        let adjusted = currentSecond + subtitleOffsetSeconds

        // Accurate search handling overlapping dialogue and sound cues
        let matching = subtitleCues.filter { adjusted >= $0.startTime && adjusted <= $0.endTime }
        let newText: String? = matching.isEmpty ? nil : matching.map(\.text).joined(separator: "\n")

        if currentSubtitleText != newText {
            currentSubtitleText = newText
        }
    }

    // MARK: - Keyboard Shortcuts (macOS)
    private func setupKeyboardMonitor() {
        #if os(macOS)
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 49: // Space
                self.togglePlayPause()
                return nil
            case 123: // Left Arrow
                self.seekRelative(-10)
                return nil
            case 124: // Right Arrow
                self.seekRelative(10)
                return nil
            case 126: // Up Arrow
                self.adjustVolume(by: 0.1)
                return nil
            case 125: // Down Arrow
                self.adjustVolume(by: -0.1)
                return nil
            case 46: // 'M'
                self.ksEngine.toggleMute()
                self.isMuted = self.ksEngine.isMuted
                return nil
            case 3: // 'F'
                if let window = NSApp.keyWindow {
                    window.toggleFullScreen(nil)
                }
                return nil
            case 0, 6: // 'A' or 'Z' - Cycle Aspect Ratio / Video Scale
                self.cycleVideoGravity()
                return nil
            case 8: // 'C'
                if self.subtitlesEnabled && self.selectedSubtitle != nil {
                    self.disableSubtitles()
                } else {
                    self.enableSubtitlesDefaultTrack()
                }
                return nil
            case 1: // 'S' - Sources
                self.ksEngine.pause()
                self.isPlaying = false
                self.stallTimer?.invalidate()
                self.stallSecondsCount = 0
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.showSourcesDrawer.toggle()
                }
                if self.showSourcesDrawer && self.availableStreamLinks.isEmpty {
                    self.loadAvailableSources()
                }
                return nil
            case 14: // 'E' - Episodes
                if self.mediaItem?.type == .series {
                    withAnimation { self.showEpisodesDrawer.toggle() }
                }
                return nil
            case 35: // 'P' - Picture in Picture
                self.ksEngine.togglePiP()
                return nil
            case 53: // Esc
                if let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                } else if self.showQuitConfirmationModal {
                    withAnimation { self.showQuitConfirmationModal = false }
                } else if self.showAudioSubtitleDrawer {
                    withAnimation { self.showAudioSubtitleDrawer = false }
                } else if self.showSourcesDrawer {
                    withAnimation { self.showSourcesDrawer = false }
                } else if self.showEpisodesDrawer {
                    withAnimation { self.showEpisodesDrawer = false }
                } else {
                    withAnimation { self.showQuitConfirmationModal = true }
                }
                return nil
            default:
                return event
            }
        }

        mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            self.userInteracted()
            return event
        }
        #endif
    }

    private func adjustVolume(by delta: Double) {
        userInteracted()
        let newVol = max(0, min(1.0, volume + delta))
        volume = newVol
        isMuted = newVol == 0
        ksEngine.setVolume(newVol)
        showToast("Volume: \(Int(newVol * 100))%")
    }

    // MARK: - Auto-Hide Controls & Inactivity
    private func userInteracted(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        if !force && (now - interactionClock.lastInteractionTime < 0.5) {
            return
        }
        interactionClock.lastInteractionTime = now

        if !showControls {
            showControls = true
        }
        #if os(macOS)
        NSCursor.unhide()
        #endif
        hideControlsWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            if !showEpisodesDrawer && !showSourcesDrawer && !showAudioSubtitleDrawer && !showAudioPopover && !showSubtitlePopover {
                withAnimation {
                    showControls = false
                }
                #if os(macOS)
                NSCursor.setHiddenUntilMouseMoves(true)
                #endif
            }
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: workItem)
    }

    private func togglePlayPause() {
        userInteracted()
        ksEngine.togglePlayPause()
        isPlaying = ksEngine.isPlaying

        withAnimation {
            showPlayPausePulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                showPlayPausePulse = false
            }
        }
    }

    private func seekRelative(_ seconds: Double) {
        userInteracted()
        ksEngine.seekRelative(seconds)
        currentTime = ksEngine.currentTime
    }

    private func seekTo(_ seconds: Double) {
        userInteracted()
        ksEngine.seek(to: seconds)
        currentTime = seconds
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            toastMessage = nil
        }
    }

    // MARK: - Next Episode Binge Logic
    private func triggerNextEpisodeCountdown() {
        showNextEpisodeCard = true
        nextEpisodeCountdown = 10
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if nextEpisodeCountdown > 1 {
                nextEpisodeCountdown -= 1
            } else {
                t.invalidate()
                playNextEpisodeNow()
            }
        }
    }

    private func cancelNextEpisodeCountdown() {
        countdownTimer?.invalidate()
        didDismissNextEpisodeCardForCurrentEp = true
        withAnimation(.easeInOut(duration: 0.2)) {
            showNextEpisodeCard = false
        }
    }

    private func playNextEpisodeNow() {
        countdownTimer?.invalidate()
        showNextEpisodeCard = false
        didDismissNextEpisodeCardForCurrentEp = false
        showSkipIntroButton = false
        introStartTimestamp = nil
        introEndTimestamp = nil
        creditsStartTime = nil
        currentSubtitleText = nil
        subtitleCues = []
        selectedSubtitle = nil
        subtitles = []

        // Check pre-cached link first
        if let preURL = prefetchedNextEpisodeURL {
            let nextEpNum = playingEpisodeNumber + 1
            self.playingEpisodeNumber = nextEpNum
            self.activeStreamURL = preURL
            self.prefetchedNextEpisodeURL = nil
            self.isPrefetchingNextEpisode = false
            self.ksEngine.loadStream(url: preURL, startTime: 0)
            self.ksEngine.play()
            self.isPlaying = true
            showToast("Now Playing S\(playingSeasonNumber) E\(nextEpNum)")
            loadSubtitlesList()
            loadTimestampsAndRecommendations()
            return
        }

        let nextEpNum = playingEpisodeNumber + 1
        if let match = episodesList.first(where: { $0.episodeNumber == nextEpNum }) {
            selectEpisodeToPlay(episode: match)
        } else {
            Task {
                let targetSeason = (!episodesList.isEmpty && nextEpNum > episodesList.count) ? (playingSeasonNumber + 1) : playingSeasonNumber
                let targetEpisode = (!episodesList.isEmpty && nextEpNum > episodesList.count) ? 1 : nextEpNum
                guard let media = mediaItem else { return }

                let eps = await tmdbService.fetchSeasonEpisodes(tvID: media.id, imdbID: media.imdbID, seasonNumber: targetSeason, title: media.title, year: media.releaseYear)
                if let nextEp = eps.first(where: { $0.episodeNumber == targetEpisode }) {
                    await MainActor.run {
                        self.selectedSeasonNumber = targetSeason
                        self.episodesList = eps
                        self.selectEpisodeToPlay(episode: nextEp)
                    }
                } else {
                    await MainActor.run {
                        self.playingSeasonNumber = targetSeason
                        self.playingEpisodeNumber = targetEpisode
                        self.availableStreamLinks = []
                        self.autoPlayNextBestLink()
                        self.loadSubtitlesList()
                        self.loadTimestampsAndRecommendations()
                    }
                }
            }
        }
    }

    // MARK: - Episode Switcher in Side Drawer
    private func selectEpisodeToPlay(episode: TVEpisodeItem) {
        guard let media = mediaItem else { return }
        isSwitchingEpisode = true
        switchingEpisodeTitle = "S\(selectedSeasonNumber) E\(episode.episodeNumber): \(episode.name)"
        didDismissNextEpisodeCardForCurrentEp = false
        showNextEpisodeCard = false
        showSkipIntroButton = false
        introStartTimestamp = nil
        introEndTimestamp = nil
        creditsStartTime = nil
        currentSubtitleText = nil
        subtitleCues = []
        selectedSubtitle = nil
        subtitles = []

        Task {
            do {
                let links = try await aggregatorService.fetchBestLinks(
                    tmdbID: media.id,
                    imdbID: media.resolvedIMDbID ?? media.imdbID,
                    type: .series,
                    title: media.title,
                    year: media.releaseYear,
                    season: selectedSeasonNumber,
                    episode: episode.episodeNumber
                )
                if let topLink = links.first {
                    let (resolvedURL, _) = try await aggregatorService.resolveStreamURLWithFallback(startingLink: topLink, allLinks: links)
                    await MainActor.run {
                        self.playingSeasonNumber = selectedSeasonNumber
                        self.playingEpisodeNumber = episode.episodeNumber
                        self.activeStreamURL = resolvedURL
                        self.availableStreamLinks = links
                        self.ksEngine.loadStream(url: resolvedURL, startTime: 0)
                        self.ksEngine.play()
                        self.isPlaying = true

                        self.isSwitchingEpisode = false
                        withAnimation {
                            self.showEpisodesDrawer = false
                        }
                        self.loadSubtitlesList()
                        self.loadTimestampsAndRecommendations()
                    }
                } else {
                    await MainActor.run {
                        self.isSwitchingEpisode = false
                    }
                }
            } catch {
                print("Failed to switch episode: \(error.localizedDescription)")
                await MainActor.run {
                    self.isSwitchingEpisode = false
                }
            }
        }
    }

    // MARK: - Enhanced Audio & Subtitles Center Modal (Screenshots 2, 3, 4)
    private var audioSubtitleCenterModal: some View {
        VStack(spacing: 0) {
            // Header with Tab Switcher & Close Button
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Button(action: { audioSubtitleTab = 1 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "captions.bubble.fill")
                                .font(.system(size: 12))
                            Text("Subtitles")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(audioSubtitleTab == 1 ? Color.white : Color.white.opacity(0.08))
                        .foregroundColor(audioSubtitleTab == 1 ? .black : .white.opacity(0.7))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: { audioSubtitleTab = 0 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12))
                            Text("Audio & Sync")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(audioSubtitleTab == 0 ? Color.white : Color.white.opacity(0.08))
                        .foregroundColor(audioSubtitleTab == 0 ? .black : .white.opacity(0.7))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if audioSubtitleTab == 1 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSubtitleStylingToolbar.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.below.rectangle")
                                .font(.system(size: 12))
                            Text("Appearance & Position")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showSubtitleStylingToolbar ? SoftTone.sage.color.opacity(0.25) : Color.white.opacity(0.08))
                        .foregroundColor(showSubtitleStylingToolbar ? SoftTone.sage.color : .white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAudioSubtitleDrawer = false
                        showSubtitleStylingToolbar = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.45))

            // Subtitle Appearance Floating Toolbar (Screenshot 1)
            if audioSubtitleTab == 1 && showSubtitleStylingToolbar {
                subtitleStylingToolbar
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.35))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Main Content Area
            if audioSubtitleTab == 1 {
                // Subtitles 2-Column View (Screenshot 2)
                subtitlesTwoColumnView
            } else {
                // Audio & Sync View (Screenshot 3)
                audioTracksAndSyncView
            }
        }
    }

    // MARK: - Subtitles 2-Column View
    private var subtitlesTwoColumnView: some View {
        let isSubOn = subtitlesEnabled
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left Column: Master Toggle & Languages List
                VStack(alignment: .leading, spacing: 12) {
                    // Master Subtitles Toggle
                    Button(action: {
                        if isSubOn {
                            disableSubtitles()
                        } else {
                            enableSubtitlesDefaultTrack()
                        }
                    }) {
                        HStack {
                            Image(systemName: isSubOn ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSubOn ? SoftTone.sage.color : .gray)
                            Text(isSubOn ? "Subtitles: On" : "Subtitles: Off")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(isSubOn ? 0.14 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSubOn ? SoftTone.sage.color.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text("LANGUAGES")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(1.1)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                    // Scrollable Languages List
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            // "All" filter
                            Button(action: { selectedSubtitleLanguage = nil }) {
                                HStack {
                                    Text("🌐 All Languages")
                                        .font(.system(size: 12.5, weight: selectedSubtitleLanguage == nil ? .bold : .medium))
                                    Spacer()
                                    Text("\(subtitles.count)")
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(selectedSubtitleLanguage == nil ? Color.white.opacity(0.14) : Color.clear)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            let langs = distinctSubtitleLanguages()
                            ForEach(langs, id: \.self) { lang in
                                let count = subtitles.filter { subtitleLanguage(for: $0).lowercased() == lang.lowercased() }.count
                                Button(action: { selectedSubtitleLanguage = lang }) {
                                    HStack {
                                        Text("\(languageFlag(for: lang)) \(lang.capitalized)")
                                            .font(.system(size: 12.5, weight: selectedSubtitleLanguage == lang ? .bold : .medium))
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(count)")
                                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(selectedSubtitleLanguage == lang ? Color.white.opacity(0.14) : Color.clear)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(width: 200)
                .background(Color.white.opacity(0.02))

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                // Right Column: Filter Pills, Track List & Sync Stepper
                VStack(alignment: .leading, spacing: 10) {
                    // Filter Pills
                    HStack(spacing: 8) {
                        ForEach(["All", "External", "Embedded"], id: \.self) { filter in
                            Button(action: { subtitleTrackFilter = filter }) {
                                Text(filter == "External" ? "OpenSubtitles" : filter)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .background(subtitleTrackFilter == filter ? Color.white : Color.white.opacity(0.08))
                                    .foregroundColor(subtitleTrackFilter == filter ? .black : .white.opacity(0.7))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if isLoadingSubtitles {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                                .padding(.leading, 4)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    // Track List
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            // Explicit "Off (No Subtitles)" option at the top
                            let isOffSelected = !subtitlesEnabled || selectedSubtitle == nil
                            Button(action: {
                                disableSubtitles()
                            }) {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: isOffSelected ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(isOffSelected ? SoftTone.sage.color : .white.opacity(0.4))
                                        .font(.system(size: 13))
                                    Text("Off (Disable Subtitles)")
                                        .font(.system(size: 12.5, weight: isOffSelected ? .bold : .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isOffSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isOffSelected ? SoftTone.sage.color.opacity(0.45) : Color.clear, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            let filtered = filteredSubtitles()
                            if filtered.isEmpty {
                                VStack(spacing: 8) {
                                    Spacer()
                                    Text(isLoadingSubtitles ? "Searching OpenSubtitles..." : "No subtitles match this filter.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                }
                                .padding(.top, 30)
                            } else {
                                ForEach(filtered) { track in
                                    let isSelected = subtitlesEnabled && selectedSubtitle?.id == track.id
                                    Button(action: {
                                        selectSubtitleTrack(track)
                                    }) {
                                        HStack(alignment: .center, spacing: 12) {
                                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                                .foregroundColor(isSelected ? SoftTone.sage.color : .white.opacity(0.4))
                                                .font(.system(size: 13))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(track.displayName)
                                                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)

                                                HStack(spacing: 6) {
                                                    if track.trackID != nil {
                                                        Text("EMBEDDED")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(SoftTone.mist.color)
                                                            .padding(.horizontal, 4.5)
                                                            .padding(.vertical, 1.5)
                                                            .background(SoftTone.mist.color.opacity(0.18))
                                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                                    } else {
                                                        Text("OPENSUBTITLES")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(SoftTone.sand.color)
                                                            .padding(.horizontal, 4.5)
                                                            .padding(.vertical, 1.5)
                                                            .background(SoftTone.sand.color.opacity(0.18))
                                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                                    }
                                                }
                                            }

                                            Spacer()

                                            // Sync delay stepper on selected track
                                            if isSelected {
                                                HStack(spacing: 4) {
                                                    Button(action: {
                                                        subtitleOffsetSeconds -= 0.1
                                                        ksEngine.setSubtitleDelay(subtitleOffsetSeconds)
                                                    }) {
                                                        Text("-0.1s")
                                                            .font(.system(size: 10, weight: .semibold))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 3)
                                                            .background(Color.white.opacity(0.1))
                                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                                    }
                                                    .buttonStyle(.plain)

                                                    Text(String(format: "%+.1fs", subtitleOffsetSeconds))
                                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                                        .foregroundColor(SoftTone.sand.color)
                                                        .frame(width: 44)

                                                    Button(action: {
                                                        subtitleOffsetSeconds += 0.1
                                                        ksEngine.setSubtitleDelay(subtitleOffsetSeconds)
                                                    }) {
                                                        Text("+0.1s")
                                                            .font(.system(size: 10, weight: .semibold))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 3)
                                                            .background(Color.white.opacity(0.1))
                                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.03))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(isSelected ? SoftTone.sage.color.opacity(0.45) : Color.clear, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Always-visible Subtitle Position Sliders (Vertical & Horizontal)
            HStack(spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(SoftTone.mist.color)
                    Text("Vertical")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Slider(
                        value: Binding(
                            get: { subtitleVerticalOffset },
                            set: { newVal in
                                subtitleVerticalOffset = newVal
                                Config.subtitleVerticalPosition = newVal
                            }
                        ),
                        in: 15...320,
                        step: 2
                    )
                    .tint(SoftTone.mist.color)
                    .frame(width: 120)
                    Text("\(Int(subtitleVerticalOffset))pt")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 34, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(SoftTone.sand.color)
                    Text("Horizontal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Slider(
                        value: Binding(
                            get: { subtitleHorizontalOffset },
                            set: { newVal in
                                subtitleHorizontalOffset = newVal
                                Config.subtitleHorizontalPosition = newVal
                            }
                        ),
                        in: -45...45,
                        step: 1
                    )
                    .tint(SoftTone.sand.color)
                    .frame(width: 120)
                    Text(String(format: "%+.0f%%", subtitleHorizontalOffset))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 34, alignment: .trailing)
                }

                Button(action: {
                    subtitleVerticalOffset = 55.0
                    subtitleHorizontalOffset = 0.0
                    Config.subtitleVerticalPosition = 55.0
                    Config.subtitleHorizontalPosition = 0.0
                }) {
                    Text("Center")
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white.opacity(0.85))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.28))

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Bottom Action Bar: Find more, Load file
            HStack(spacing: 12) {
                Button(action: {
                    loadSubtitlesList()
                    showToast("Searching open subtitles catalog...")
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                        Text("Find More Subtitles")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                #if os(macOS)
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.title = "Load Subtitle File"
                    panel.prompt = "Load"
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    if panel.runModal() == .OK, let fileURL = panel.url {
                        let localTrack = SubtitleTrack(
                            id: "local_\(fileURL.lastPathComponent)",
                            displayName: "\(fileURL.lastPathComponent) [Local File]",
                            trackID: nil,
                            externalURL: fileURL
                        )
                        self.subtitles.removeAll { $0.id == localTrack.id }
                        self.subtitles.insert(localTrack, at: 0)
                        self.selectSubtitleTrack(localTrack)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11, weight: .bold))
                        Text("Load file...")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                #endif

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(Color.black.opacity(0.35))
        }
    }

    // MARK: - Floating Subtitle Styling Toolbar (Screenshot 1)
    private var subtitleStylingToolbar: some View {
        HStack(spacing: 14) {
            // Font dropdown
            Menu {
                ForEach(["Inter", "SF Pro", "Arial", "Trebuchet MS", "Menlo", "Georgia"], id: \.self) { font in
                    Button(font) {
                        subtitleFontName = font
                        ksEngine.setSubtitleFont(font)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(subtitleFontName)
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.12))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            // Size: [A-] 32 [A+]
            HStack(spacing: 6) {
                Button(action: {
                    subtitleFontSize = max(16, subtitleFontSize - 2)
                    Config.subtitleFontSizePreference = subtitleFontSize
                    ksEngine.setSubtitleFontSize(Double(subtitleFontSize))
                }) {
                    Text("A-")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Text("\(Int(subtitleFontSize))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 22)

                Button(action: {
                    subtitleFontSize = min(60, subtitleFontSize + 2)
                    Config.subtitleFontSizePreference = subtitleFontSize
                    ksEngine.setSubtitleFontSize(Double(subtitleFontSize))
                }) {
                    Text("A+")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }

            // Bold Toggle [B]
            Button(action: {
                subtitleIsBold.toggle()
                ksEngine.setSubtitleBold(subtitleIsBold)
            }) {
                Text("B")
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(subtitleIsBold ? Color.white : Color.white.opacity(0.12))
                    .foregroundColor(subtitleIsBold ? .black : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            // 8 Color Circles
            HStack(spacing: 5) {
                let palette: [(Color, String)] = [
                    (Color.white, "#FFFFFF"),
                    (Color(red: 1.0, green: 0.98, blue: 0.44), "#FFFA70"),
                    (Color(red: 0.96, green: 0.76, blue: 0.47), "#F6C177"),
                    (Color(red: 0.65, green: 0.82, blue: 0.54), "#A6D189"),
                    (Color(red: 0.52, green: 0.76, blue: 0.91), "#85C1E9"),
                    (Color(red: 0.92, green: 0.44, blue: 0.57), "#EB6F92"),
                    (Color(red: 0.77, green: 0.65, blue: 0.91), "#C4A7E7"),
                    (Color(red: 0.69, green: 0.69, blue: 0.69), "#B0B0B0")
                ]
                ForEach(palette, id: \.1) { item in
                    Circle()
                        .fill(item.0)
                        .frame(width: 15, height: 15)
                        .overlay(Circle().stroke(Color.white, lineWidth: subtitleColor == item.0 ? 2 : 0))
                        .onTapGesture {
                            subtitleColor = item.0
                            ksEngine.setSubtitleColor(item.1)
                        }
                }
            }

            // FPS Selector: [23.976 fps]
            Menu {
                ForEach([23.976, 24.0, 25.0, 29.97, 30.0], id: \.self) { fps in
                    Button(String(format: "%.3f fps", fps)) {
                        subtitleFPS = fps
                        ksEngine.setSubtitleFPS(fps)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(format: "%.3f fps", subtitleFPS))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Audio Tracks & Lip Sync View (Screenshot 3)
    private var audioTracksAndSyncView: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if audioTracks.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Text("No alternative audio streams detected.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(audioTracks) { track in
                            let isSelected = selectedAudioTrack?.id == track.id
                            Button(action: {
                                selectedAudioTrack = track
                                if let tid = track.trackID {
                                    ksEngine.selectAudioTrack(id: tid)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Text(languageFlag(for: track.languageCode))
                                        .font(.system(size: 20))

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(track.languageName)
                                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                                .foregroundColor(.white)

                                            if let format = track.formatDetails, !format.isEmpty {
                                                Text("•")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.4))
                                                Text(format)
                                                    .font(.system(size: 12, weight: .regular))
                                                    .foregroundColor(.white.opacity(0.85))
                                            }
                                        }

                                        HStack(spacing: 6) {
                                            if track.isSurround {
                                                Text("SURROUND")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(SoftTone.mist.color)
                                                    .padding(.horizontal, 4.5)
                                                    .padding(.vertical, 1.5)
                                                    .background(SoftTone.mist.color.opacity(0.18))
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            } else {
                                                Text("STEREO")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .padding(.horizontal, 4.5)
                                                    .padding(.vertical, 1.5)
                                                    .background(Color.white.opacity(0.1))
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }

                                            if track.isOriginal {
                                                Text("ORIGINAL")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(SoftTone.sand.color)
                                                    .padding(.horizontal, 4.5)
                                                    .padding(.vertical, 1.5)
                                                    .background(SoftTone.sand.color.opacity(0.18))
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            } else if track.isDubbed {
                                                Text("DUBBED")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(SoftTone.sage.color)
                                                    .padding(.horizontal, 4.5)
                                                    .padding(.vertical, 1.5)
                                                    .background(SoftTone.sage.color.opacity(0.18))
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(isSelected ? SoftTone.sage.color : .white.opacity(0.4))
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Lip-Sync Audio Offset Stepper
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lip-Sync Audio Delay")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text("Fine-tune voice synchronization in 100ms increments")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                HStack(spacing: 6) {
                    Button(action: {
                        ksEngine.setAudioDelay(ksEngine.audioDelay - 0.1)
                    }) {
                        Text("-0.1s")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4.5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)

                    Text(String(format: "%+.1fs", ksEngine.audioDelay))
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundColor(SoftTone.sand.color)
                        .frame(width: 48)

                    Button(action: {
                        ksEngine.setAudioDelay(ksEngine.audioDelay + 0.1)
                    }) {
                        Text("+0.1s")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4.5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)

                    Button("Reset") {
                        ksEngine.setAudioDelay(0.0)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.35))
        }
    }

    // Helper functions for distinct subtitle languages & filtering
    private func distinctSubtitleLanguages() -> [String] {
        let list = subtitles.map { subtitleLanguage(for: $0) }
        return Array(Set(list)).sorted()
    }

    private func subtitleLanguage(for track: SubtitleTrack) -> String {
        let name = track.displayName.lowercased()
        if name.contains("english") || name.contains("(en)") || name.contains("eng") { return "English" }
        if name.contains("turkish") || name.contains("türkçe") || name.contains("(tr)") || name.contains("tur") { return "Turkish" }
        if name.contains("spanish") || name.contains("español") || name.contains("(es)") || name.contains("spa") { return "Spanish" }
        if name.contains("french") || name.contains("français") || name.contains("(fr)") || name.contains("fre") { return "French" }
        if name.contains("german") || name.contains("deutsch") || name.contains("(de)") || name.contains("ger") { return "German" }
        if name.contains("italian") || name.contains("italiano") || name.contains("(it)") || name.contains("ita") { return "Italian" }
        if name.contains("japanese") || name.contains("(ja)") || name.contains("jpn") { return "Japanese" }
        if name.contains("korean") || name.contains("(ko)") || name.contains("kor") { return "Korean" }
        if name.contains("chinese") || name.contains("(zh)") || name.contains("chi") { return "Chinese" }
        if name.contains("portuguese") || name.contains("(pt)") || name.contains("por") { return "Portuguese" }
        if name.contains("russian") || name.contains("(ru)") || name.contains("rus") { return "Russian" }
        if name.contains("arabic") || name.contains("(ar)") || name.contains("ara") { return "Arabic" }
        return "Other"
    }

    private func filteredSubtitles() -> [SubtitleTrack] {
        subtitles.filter { track in
            if let lang = selectedSubtitleLanguage {
                if subtitleLanguage(for: track).lowercased() != lang.lowercased() {
                    return false
                }
            }
            if subtitleTrackFilter == "Embedded" && track.trackID == nil {
                return false
            }
            if subtitleTrackFilter == "External" && track.trackID != nil {
                return false
            }
            return true
        }
    }

    // MARK: - Movie Credits Shelf (Netflix-Style)
    private var movieCreditsShelf: some View {
        VStack(spacing: 14) {
            // Header with dismiss
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MORE LIKE THIS")
                        .font(.caption2.bold())
                        .tracking(1.4)
                        .foregroundColor(SoftTone.sand.color)
                    Text("Continue your experience")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: {
                    didDismissCreditsShelf = true
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showMovieCreditsShelf = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)

            // Edge-to-edge horizontal row of similar movies
            if !movieRecommendations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(movieRecommendations.prefix(20)) { rec in
                            Button(action: {
                                exitPlayerAndOpenDetails(rec)
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    CachedImage(url: rec.posterUrl, fallbackURL: rec.posterURL, maxPixel: 360)
                                        .aspectRatio(2/3, contentMode: .fill)
                                        .frame(width: 112, height: 166)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.white.opacity(0.18), lineWidth: 1.0)
                                        )

                                    Text(rec.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .frame(width: 112, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .shiningRise()
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 6)
                }
                .frame(maxWidth: .infinity)
            }

            // "Interim somnium finit?" Button that pulls to main home hero screen
            Button(action: {
                exitPlayer(returnHome: true)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Interim somnium finit?")
                        .font(.system(size: 13.5, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.32), radius: 10)
            }
            .buttonStyle(.plain)
            .shiningRise(isWhitePlay: true)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0.92), Color.black.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(0.95), radius: 35, x: 0, y: -12)
    }

    private func exitPlayerAndOpenDetails(_ movie: MediaItem) {
        teardownPlayer()
        #if os(macOS)
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) {
                if window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
        }
        #endif
        if let onSelectRecommendation = onSelectRecommendation {
            onSelectRecommendation(movie)
        } else {
            self.mediaItem = movie
            onDismiss()
        }
    }

    private func switchToMovie(_ movie: MediaItem) {
        showMovieCreditsShelf = false
        didDismissCreditsShelf = false
        showSkipIntroButton = false
        ksEngine.reset()
        self.mediaItem = movie
        self.currentTime = 0
        self.duration = 0
        self.isPlaying = false
        self.isBuffering = true
        self.currentSubtitleText = nil
        self.subtitleCues = []
        self.selectedSubtitle = nil
        self.subtitles = []
        self.introStartTimestamp = nil
        self.introEndTimestamp = nil
        self.creditsStartTime = nil
        self.movieRecommendations = []
        self.availableStreamLinks.removeAll()
        self.currentActiveLinkID = nil
        self.activeStreamURL = nil
        self.capturedFrames.removeAll()
        self.previewBackdrops.removeAll()
        self.lastSnapshotTime = -999

        autoPlayNextBestLink()
        loadSubtitlesList()
        loadTimestampsAndRecommendations()
        fetchTimelinePreviews()
    }

    private func fetchTimelinePreviews() {
        guard let media = mediaItem else { return }
        Task {
            let scenes = await tmdbService.fetchSceneImages(
                id: media.id,
                imdbID: media.imdbID,
                type: media.type,
                title: media.title,
                year: media.releaseYear
            )
            await MainActor.run {
                self.previewBackdrops = scenes
            }
        }
    }

    // MARK: - "Interim somnium finit?" Exit Confirmation Modal
    private var quitConfirmationCenterModal: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 34))
                .foregroundColor(SoftTone.mist.color)

            VStack(spacing: 6) {
                Text("Interim somnium finit?")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.white)

                Text("Are you sure you want to stop playback and return to Home?")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button(action: {
                    withAnimation { showQuitConfirmationModal = false }
                }) {
                    Text("Not yet")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: {
                    showQuitConfirmationModal = false
                    exitPlayer(returnHome: true)
                }) {
                    Text("Yes")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(28)
    }

    // MARK: - Episodes Side Drawer
    private var episodesSideDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Seasons & Episodes")
                    .font(.headline.bold())
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    withAnimation {
                        showEpisodesDrawer = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color.black.opacity(0.4))

            // Season Picker Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...totalSeasonsCount, id: \.self) { sNum in
                        Button(action: {
                            selectedSeasonNumber = sNum
                            loadSeasonEpisodes(sNum)
                        }) {
                            Text("Season \(sNum)")
                                .font(.caption.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedSeasonNumber == sNum ? Color.white : Color.white.opacity(0.08))
                                .foregroundColor(selectedSeasonNumber == sNum ? .black : .white.opacity(0.7))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.white.opacity(0.04))

            Divider().background(Color.white.opacity(0.1))

            // Episodes List
            if isLoadingEpisodes {
                VStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Text("Loading Season \(selectedSeasonNumber)...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(episodesList) { ep in
                            let isCurrent = (selectedSeasonNumber == playingSeasonNumber && ep.episodeNumber == playingEpisodeNumber)

                            Button(action: {
                                selectEpisodeToPlay(episode: ep)
                            }) {
                                HStack(spacing: 12) {
                                    Text("\(ep.episodeNumber)")
                                        .font(.headline.monospacedDigit())
                                        .foregroundColor(isCurrent ? .white : .white.opacity(0.4))
                                        .frame(width: 24)

                                    if let still = ep.stillURL {
                                        CachedImage(url: still, maxPixel: 240)
                                        .frame(width: 90, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 90, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(ep.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)

                                            if isCurrent {
                                                SoftBadge(text: "Playing", tone: .sage)
                                            }
                                        }

                                        if let overview = ep.overview, !overview.isEmpty {
                                            Text(overview)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(10)
                                .background(isCurrent ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isCurrent ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 380)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.95))
        .preferredColorScheme(.dark)
        .shadow(color: .black.opacity(0.7), radius: -10, y: 0)
    }

    private func loadTVShowData() {
        guard let media = mediaItem, media.type == .series else { return }
        Task {
            let count = await tmdbService.fetchTVSeasonsCount(tvID: media.id, imdbID: media.imdbID, title: media.title, year: media.releaseYear)
            await MainActor.run {
                self.totalSeasonsCount = count
                self.loadSeasonEpisodes(selectedSeasonNumber)
            }
        }
    }

    private func loadSeasonEpisodes(_ sNum: Int) {
        guard let media = mediaItem else { return }
        isLoadingEpisodes = true
        Task {
            let eps = await tmdbService.fetchSeasonEpisodes(tvID: media.id, imdbID: media.imdbID, seasonNumber: sNum, title: media.title, year: media.releaseYear)
            await MainActor.run {
                self.episodesList = eps
                self.isLoadingEpisodes = false
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60

        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}
