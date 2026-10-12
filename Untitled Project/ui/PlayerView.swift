import SwiftUI
import AVKit
import Combine

#if os(macOS)
import AppKit
#endif

// MARK: - Streaming Scrubber Bar with Hover Tooltip & Buffer Indicator
struct StreamingScrubberBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let bufferedFraction: Double
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

                // Hover / Scrub Time Tooltip
                if isHovering || isDragging {
                    let previewTime = isDragging ? dragTime : (hoverFraction * total)
                    VStack(spacing: 2) {
                        Text(formatTime(previewTime))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .offset(x: max(20, min(width - 50, (isDragging ? playedWidth : width * CGFloat(hoverFraction)) - 25)), y: -24)
                }
            }
            .contentShape(Rectangle())
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
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isHovering = true
                    hoverFraction = max(0.0, min(1.0, location.x / width))
                    onHovering?()
                case .ended:
                    isHovering = false
                }
            }
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
    let trackID: Int32?

    init(id: String = UUID().uuidString, displayName: String, trackID: Int32? = nil) {
        self.id = id
        self.displayName = displayName
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
        if engine.currentURL == nil {
            engine.loadStream(url: url)
        }

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
        videoView.updateLayerGeometry()
        if engine.currentURL?.absoluteString != url.absoluteString {
            engine.loadStream(url: url)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        MPVPlayerEngine.shared.videoView.removeFromSuperview()
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
    var mediaItem: MediaItem?
    var currentSeason: Int? = nil
    var currentEpisode: Int? = nil
    var initialLinks: [AggregatedLink] = []
    var onDismiss: () -> Void

    private let ksEngine = KSPlayerEngine.shared
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
    @State private var subtitleCues: [SubtitleCue] = []
    @State private var currentSubtitleText: String? = nil
    @State private var subtitleOffsetSeconds: Double = 0.0
    @State private var subtitleFontSize: CGFloat = Config.subtitleFontSizePreference
    @State private var subtitleColor: Color = Color.yellow
    @State private var isLoadingSubtitles: Bool = false

    @State private var audioTracks: [AudioTrackItem] = []
    @State private var selectedAudioTrack: AudioTrackItem?
    @State private var audioSubtitleTab: Int = 0

    // Popovers
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

            // 3. On-Screen Subtitle Text / PGS Image Overlay
            if let text = currentSubtitleText, !text.isEmpty {
                VStack {
                    Spacer()
                    Text(text)
                        .font(.system(size: subtitleFontSize, weight: .semibold, design: .default))
                        .foregroundColor(subtitleColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                        .padding(.bottom, showControls ? 110 : 45)
                }
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
            } else if let img = ksEngine.currentEmbeddedSubtitleImage {
                VStack {
                    Spacer()
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 900)
                        .padding(.bottom, showControls ? 110 : 45)
                }
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
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
                    togglePlayPause()
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

            // 5. Center Play/Pause Pulse Icon
            if showPlayPausePulse {
                Image(systemName: isPlaying ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.7), radius: 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
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
                .zIndex(300)
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

                        Button("Start Over") {
                            seekTo(0)
                            showResumeBanner = false
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.85))
                    .cornerRadius(14)
                    .frame(maxWidth: 420)
                    .padding(.top, 70)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(180)
            }

            // 8. Next Episode Binge Countdown Card
            if showNextEpisodeCard && mediaItem?.type == .series {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("UP NEXT")
                                    .font(.caption2.bold())
                                    .tracking(1.2)
                                    .foregroundColor(.white.opacity(0.55))
                                Spacer()
                                Button(action: cancelNextEpisodeCountdown) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }

                            Text("Episode \(playingEpisodeNumber + 1)")
                                .font(.headline.bold())
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                Button(action: playNextEpisodeNow) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                        Text("Play in \(nextEpisodeCountdown)s")
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button("Cancel", action: cancelNextEpisodeCountdown)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.85))
                        .cornerRadius(16)
                        .frame(width: 260)
                        .padding(24)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(190)
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
                        VStack(alignment: .leading, spacing: 3) {
                            Text(media.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if media.type == .series {
                                Text("Season \(playingSeasonNumber) · Episode \(playingEpisodeNumber)")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
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

                        // Audio & Subtitles
                        Button(action: {
                            userInteracted()
                            showSubtitlePopover.toggle()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: selectedSubtitle != nil ? "captions.bubble.fill" : "captions.bubble")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedSubtitle != nil ? .white : .white.opacity(0.85))
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
                        .popover(isPresented: $showSubtitlePopover) {
                            subtitlesMenu
                        }

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
                    HStack(spacing: 16) {
                        // Play / Pause Toggle (Solid white circle button)
                        Button(action: {
                            userInteracted()
                            togglePlayPause()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 38, height: 38)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .white.opacity(0.18), radius: 6)
                        }
                        .buttonStyle(.plain)

                        // Skip -10s
                        Button(action: {
                            userInteracted()
                            seekRelative(-10)
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)

                        // Skip +10s
                        Button(action: {
                            userInteracted()
                            seekRelative(10)
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
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
                .padding(.top, 18)
                .padding(.bottom, 22)
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
        }
        .ignoresSafeArea()
        .onReceive(ksEngine.$currentTime) { time in
            onPlayerTick(current: time, total: ksEngine.duration)
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
        }
        .onDisappear {
            teardownPlayer()
        }
    }

    // MARK: - Playback Setup & Buffer Optimization
    private func setupPlayer() {
        activeStreamURL = streamURL
        guard let url = activeStreamURL else { return }

        // Validate that url is a playable stream scheme (http, https, file)
        guard let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https" || scheme == "file") else {
            playbackError = "Direct stream URL not available or incompatible format. Please select an alternative source."
            showPlaybackErrorSheet = true
            return
        }

        // Check for resume time
        if let media = mediaItem {
            if let resumeSec = watchlistManager.getResumeTime(id: media.id, season: playingSeasonNumber, episode: playingEpisodeNumber) {
                resumeTimeAvailable = resumeSec
                showResumeBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation {
                        showResumeBanner = false
                    }
                }
            }
        }

        let targetIMDb = mediaItem?.imdbID ?? (mediaItem?.id.hasPrefix("tt") == true ? mediaItem?.id : nil)
        let savedResume = resumeTimeAvailable ?? 0.0

        ksEngine.loadStream(url: url, startTime: savedResume, imdbID: targetIMDb)
        self.isPlaying = true
        setupStallWatchdog()
    }

    private func setupStallWatchdog() {
        stallTimer?.invalidate()
        var lastRecordedTime: Double = -1
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                guard self.isPlaying else { return }
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
        }

        // Update subtitles only when needed
        if let sel = selectedSubtitle {
            if sel.trackID != nil {
                if let embedded = ksEngine.currentEmbeddedSubtitleText {
                    if self.currentSubtitleText != embedded {
                        self.currentSubtitleText = embedded
                    }
                } else if self.currentSubtitleText != nil {
                    self.currentSubtitleText = nil
                }
            } else if sel.externalURL != nil {
                updateSubtitleCue(currentSecond: current)
            }
        } else if let embedded = ksEngine.currentEmbeddedSubtitleText {
            if self.currentSubtitleText != embedded {
                self.currentSubtitleText = embedded
            }
        } else if !subtitleCues.isEmpty {
            updateSubtitleCue(currentSecond: current)
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

            // Check if near end of episode for next episode countdown (< 25s)
            if self.mediaItem?.type == .series && self.duration > 60 && current >= (self.duration - 25.0) {
                if !self.showNextEpisodeCard && Config.autoPlayNextEpisode {
                    self.triggerNextEpisodeCountdown()
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
        // Sync audio tracks
        self.audioTracks = ksEngine.availableAudioTracks.map { track in
            AudioTrackItem(id: "\(track.id)", displayName: track.name, trackID: track.id)
        }
        if let activeId = ksEngine.selectedAudioTrackId {
            self.selectedAudioTrack = self.audioTracks.first { $0.trackID == activeId }
        }

        // Sync embedded subtitle tracks
        let embeddedSubs = ksEngine.availableSubtitleTracks.map { track in
            SubtitleTrack(id: "embedded_\(track.id)", displayName: "\(track.name) [Embedded]", trackID: track.id, externalURL: nil)
        }
        self.subtitles.removeAll { $0.trackID != nil }
        self.subtitles.insert(contentsOf: embeddedSubs, at: 0)
        if let activeSubId = ksEngine.selectedSubtitleTrackId {
            self.selectedSubtitle = self.subtitles.first { $0.trackID == activeSubId }
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
                imdbID: media.imdbID,
                type: .series,
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
        ksEngine.pause()
        ksEngine.reset()
        AggregatorService.stopAndCleanAllTorrentMissions()
    }

    private func exitPlayer() {
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

        onDismiss()
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
                    imdbID: media.imdbID,
                    type: media.type,
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
                        imdbID: media.imdbID,
                        type: media.type,
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

                guard let firstChoice = AggregatedLink.selectBestStream(from: candidates) ?? candidates.first else {
                    await MainActor.run {
                        self.isBuffering = false
                        self.showToast("No playable media sources available for this title.")
                        self.isSkippingFakeStream = false
                    }
                    return
                }

                let (newURL, pickedLink) = try await self.aggregatorService.resolveStreamURLWithFallback(startingLink: firstChoice, allLinks: candidates)
                await MainActor.run {
                    guard self.isPlaying || self.isBuffering else { return }
                    self.currentActiveLinkID = pickedLink.id
                    self.activeStreamURL = newURL
                    self.isSkippingFakeStream = false
                    self.ksEngine.loadStream(url: newURL, startTime: savedTime)
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
            let imdb = item.imdbID ?? item.id
            let fetched = await subtitleService.fetchSubtitles(
                imdbID: imdb,
                type: item.type,
                season: playingSeasonNumber,
                episode: playingEpisodeNumber
            )

            await MainActor.run {
                self.subtitles.append(contentsOf: fetched)
                self.isLoadingSubtitles = false

                // Auto-select preferred subtitle language if available
                if let auto = fetched.first(where: {
                    $0.displayName.lowercased().contains(SubtitleService.languageName(for: Config.preferredSubtitleLanguage).lowercased())
                }) {
                    selectSubtitleTrack(auto)
                }
            }
        }
    }

    private func selectSubtitleTrack(_ track: SubtitleTrack) {
        selectedSubtitle = track
        currentSubtitleText = nil
        subtitleCues = []

        if let tid = track.trackID {
            ksEngine.selectSubtitleTrack(id: tid)
        } else if let externalURL = track.externalURL {
            ksEngine.selectSubtitleTrack(id: nil)
            Task {
                let cues = await subtitleService.loadCues(from: externalURL)
                await MainActor.run {
                    self.subtitleCues = cues
                }
            }
        }
    }

    private func disableSubtitles() {
        selectedSubtitle = nil
        currentSubtitleText = nil
        subtitleCues = []
        ksEngine.selectSubtitleTrack(id: nil)
    }

    private func updateSubtitleCue(currentSecond: Double) {
        guard !subtitleCues.isEmpty else {
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
                if self.selectedSubtitle != nil {
                    self.disableSubtitles()
                } else if let first = self.subtitles.first {
                    self.selectSubtitleTrack(first)
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
                self.exitPlayer()
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
            if !showEpisodesDrawer && !showSourcesDrawer && !showAudioPopover && !showSubtitlePopover {
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
        showNextEpisodeCard = false
    }

    private func playNextEpisodeNow() {
        countdownTimer?.invalidate()
        showNextEpisodeCard = false

        // Check pre-cached link first
        if let preURL = prefetchedNextEpisodeURL {
            let nextEpNum = playingEpisodeNumber + 1
            self.playingEpisodeNumber = nextEpNum
            self.activeStreamURL = preURL
            self.prefetchedNextEpisodeURL = nil
            self.isPrefetchingNextEpisode = false
            self.ksEngine.loadStream(url: preURL, startTime: 0)
            self.isPlaying = true
            showToast("Now Playing S\(playingSeasonNumber) E\(nextEpNum)")
            loadSubtitlesList()
            return
        }

        let nextEpNum = playingEpisodeNumber + 1
        if let match = episodesList.first(where: { $0.episodeNumber == nextEpNum }) {
            selectEpisodeToPlay(episode: match)
        } else {
            Task {
                let targetSeason = (nextEpNum > episodesList.count) ? (playingSeasonNumber + 1) : playingSeasonNumber
                let targetEpisode = (nextEpNum > episodesList.count) ? 1 : nextEpNum
                guard let media = mediaItem else { return }

                let eps = await tmdbService.fetchSeasonEpisodes(tvID: media.id, imdbID: media.imdbID, seasonNumber: targetSeason, title: media.title)
                if let nextEp = eps.first(where: { $0.episodeNumber == targetEpisode }) {
                    await MainActor.run {
                        self.selectedSeasonNumber = targetSeason
                        self.selectEpisodeToPlay(episode: nextEp)
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

        Task {
            do {
                let links = try await aggregatorService.fetchBestLinks(
                    tmdbID: media.id,
                    imdbID: media.imdbID,
                    type: .series,
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
                        self.isPlaying = true

                        self.isSwitchingEpisode = false
                        withAnimation {
                            self.showEpisodesDrawer = false
                        }
                        self.loadSubtitlesList()
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

    private var audioTracksMenu: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !audioTracks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AUDIO TRACKS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(audioTracks) { track in
                        Button(action: {
                            selectedAudioTrack = track
                            if let tid = track.trackID {
                                ksEngine.selectAudioTrack(id: tid)
                            }
                        }) {
                            HStack {
                                Text(track.displayName)
                                Spacer()
                                if selectedAudioTrack?.id == track.id {
                                    Image(systemName: "checkmark").foregroundColor(SoftTone.mist.color)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().background(Color.white.opacity(0.1))
            }

            // Audio Sync & Lip-Sync Controls (Isolated observed subview)
            PlayerAudioSyncControls()
        }
    }

    private var subtitlesMenu: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $audioSubtitleTab) {
                Text("Audio").tag(0)
                Text("Subtitles").tag(1)
            }
            .pickerStyle(.segmented)

            if audioSubtitleTab == 0 {
                audioTracksMenu
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("SUBTITLES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        if isLoadingSubtitles {
                            ProgressView().scaleEffect(0.6)
                        }
                    }

                    // Appearance & Sync Controls
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray)
                            HStack(spacing: 6) {
                                Circle().fill(Color.white).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(Color.white, lineWidth: subtitleColor == .white ? 2 : 0))
                                    .onTapGesture { subtitleColor = .white }
                                Circle().fill(Color.yellow).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(Color.white, lineWidth: subtitleColor == .yellow ? 2 : 0))
                                    .onTapGesture { subtitleColor = .yellow }
                                Circle().fill(Color.cyan).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(Color.white, lineWidth: subtitleColor == .cyan ? 2 : 0))
                                    .onTapGesture { subtitleColor = .cyan }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Size")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray)
                            HStack(spacing: 8) {
                                Button(action: { subtitleFontSize = max(16, subtitleFontSize - 2) }) {
                                    Image(systemName: "textformat.size.smaller")
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(Int(subtitleFontSize))")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Button(action: { subtitleFontSize = min(60, subtitleFontSize + 2) }) {
                                    Image(systemName: "textformat.size.larger")
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync Offset (\(String(format: "%+.1fs", subtitleOffsetSeconds)))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                        HStack(spacing: 4) {
                            Button("-0.5s") { subtitleOffsetSeconds -= 0.5 }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("Reset") { subtitleOffsetSeconds = 0.0 }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("+0.5s") { subtitleOffsetSeconds += 0.5 }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                        }
                    }

                    Divider().background(Color.white.opacity(0.1))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: {
                                disableSubtitles()
                            }) {
                                HStack {
                                    Text("Off")
                                        .font(.system(size: 13))
                                    Spacer()
                                    if selectedSubtitle == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(SoftTone.mist.color)
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            
                            ForEach(subtitles) { track in
                                Button(action: {
                                    selectSubtitleTrack(track)
                                }) {
                                    HStack {
                                        Text(track.displayName)
                                            .font(.system(size: 13))
                                            .lineLimit(1)
                                        Spacer()
                                        if selectedSubtitle?.id == track.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(SoftTone.mist.color)
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .padding(18)
        .frame(width: 320)
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
            let count = await tmdbService.fetchTVSeasonsCount(tvID: media.id, imdbID: media.imdbID, title: media.title)
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
            let eps = await tmdbService.fetchSeasonEpisodes(tvID: media.id, imdbID: media.imdbID, seasonNumber: sNum, title: media.title)
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
