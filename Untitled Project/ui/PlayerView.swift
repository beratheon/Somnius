import SwiftUI
import AVKit
import Combine

#if os(macOS)
import AppKit

class NativePlayerNSView: NSView, AVPictureInPictureControllerDelegate {
    let playerLayer = AVPlayerLayer()
    var pipController: AVPictureInPictureController?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = playerLayer
        playerLayer.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect

        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = self
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    func setPlayer(_ p: AVPlayer) {
        if playerLayer.player != p {
            playerLayer.player = p
        }
    }

    func setVideoGravity(_ g: AVLayerVideoGravity) {
        playerLayer.videoGravity = g
    }

    func togglePiP() {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
    }
}

struct NativePlayerView: NSViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    var pipTrigger: Bool = false

    func makeNSView(context: Context) -> NativePlayerNSView {
        let view = NativePlayerNSView()
        view.setPlayer(player)
        view.setVideoGravity(videoGravity)
        return view
    }

    func updateNSView(_ nsView: NativePlayerNSView, context: Context) {
        nsView.setPlayer(player)
        nsView.setVideoGravity(videoGravity)
        if pipTrigger != context.coordinator.lastPipTrigger {
            context.coordinator.lastPipTrigger = pipTrigger
            nsView.togglePiP()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastPipTrigger: Bool = false
    }
}
#endif

// MARK: - Streaming Scrubber Bar with Hover Tooltip & Buffer Indicator
struct StreamingScrubberBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let bufferedFraction: Double
    var onSeek: (Double) -> Void
    var onScrubbingChanged: (Bool) -> Void

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
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.18))
                    .frame(height: isHovering || isDragging ? 7 : 4)

                // Buffered Progress Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.42))
                    .frame(width: bufferWidth, height: isHovering || isDragging ? 7 : 4)

                // Played Progress Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [Color.blue, Color.cyan, Color.purple], startPoint: .leading, endPoint: .trailing))
                    .frame(width: playedWidth, height: isHovering || isDragging ? 7 : 4)

                // Scrubbing Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: isHovering || isDragging ? 16 : 10, height: isHovering || isDragging ? 16 : 10)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                    .offset(x: max(0, min(width - 16, playedWidth - (isHovering || isDragging ? 8 : 5))))

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

enum PlayerEngineType: String, CaseIterable, Identifiable {
    case avPlayer = "Apple Native (AVPlayer)"
    case soiaMPV = "Soia Hardware Engine (libmpv)"

    var id: String { rawValue }
}

struct AudioTrackItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let option: AVMediaSelectionOption?

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
    let option: AVMediaSelectionOption?
    let externalURL: URL?

    init(id: String = UUID().uuidString, displayName: String, option: AVMediaSelectionOption? = nil, externalURL: URL? = nil) {
        self.id = id
        self.displayName = displayName
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

struct PlayerView: View {
    var streamURL: URL?
    var mediaItem: MediaItem?
    var currentSeason: Int? = nil
    var currentEpisode: Int? = nil
    var initialLinks: [AggregatedLink] = []
    var onDismiss: () -> Void

    @StateObject private var watchlistManager = WatchlistManager.shared
    @State private var activeStreamURL: URL? = nil
    @State private var player: AVPlayer?
    @State private var currentEngine: PlayerEngineType = .avPlayer
    private let soiaEngine = SoiaPlayerEngine.shared

    @State private var isPlaying: Bool = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var bufferedSeconds: Double = 0
    @State private var bufferedFraction: Double = 0

    // Buffer stall detection & recovery
    @State private var isBuffering: Bool = false
    @State private var stallSecondsCount: Double = 0
    @State private var stallTimer: Timer? = nil
    @State private var soiaPollTimer: Timer? = nil
    @State private var cancellables = Set<AnyCancellable>()

    // Video aspect ratio & PiP
    @State private var videoGravity: AVLayerVideoGravity = .resizeAspect
    @State private var pipTrigger: Bool = false
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

    // Next episode auto-play countdown & pre-caching
    @State private var showNextEpisodeCard: Bool = false
    @State private var nextEpisodeCountdown: Int = 10
    @State private var countdownTimer: Timer? = nil
    @State private var prefetchedNextEpisodeURL: URL? = nil
    @State private var isPrefetchingNextEpisode: Bool = false

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
    @State private var audioSelectionGroup: AVMediaSelectionGroup?
    @State private var embeddedSubGroup: AVMediaSelectionGroup?

    // Popovers
    @State private var showAudioPopover: Bool = false
    @State private var showSubtitlePopover: Bool = false
    @State private var showExternalPlayerPopover: Bool = false
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

    private let tmdbService = TMDBService()
    private let aggregatorService = AggregatorService()
    private let subtitleService = SubtitleService.shared

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.ignoresSafeArea()

            // 1. Dual-Engine Video Player View
            if currentEngine == .soiaMPV, let url = activeStreamURL ?? streamURL {
                SoiaEmbeddedPlayerView(urlString: url.absoluteString, engine: soiaEngine)
                    .ignoresSafeArea()
            } else if let _ = activeStreamURL ?? streamURL, let p = player {
                #if os(macOS)
                NativePlayerView(player: p, videoGravity: videoGravity, pipTrigger: pipTrigger)
                    .ignoresSafeArea()
                #else
                VideoPlayer(player: p)
                    .ignoresSafeArea()
                #endif
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                    Text("Loading Stream...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }

            // 2. Active Buffer / Stall Overlay Spinner
            if isBuffering && !isSwitchingEpisode {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(1.4)
                    Text("Buffering 4K HDR Stream...")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    if stallSecondsCount > 5 {
                        Text("Optimizing Debrid buffer (\(Int(stallSecondsCount))s)...")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .transition(.opacity)
                .zIndex(50)
            }

            // 3. On-Screen Subtitle Text Overlay
            if let text = currentSubtitleText, !text.isEmpty {
                VStack {
                    Spacer()
                    Text(text)
                        .font(.system(size: subtitleFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(subtitleColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.9), radius: 6, x: 0, y: 3)
                        .padding(.bottom, showControls ? 110 : 45)
                        .animation(.easeInOut(duration: 0.15), value: currentSubtitleText)
                }
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
            }

            // 4. User interaction overlay
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    userInteracted()
                    togglePlayPause()
                }
                #if os(macOS)
                .onContinuousHover { _ in
                    userInteracted()
                }
                #endif

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
                            .scaleEffect(1.5)
                            .tint(.blue)
                        Text("Loading \(switchingEpisodeTitle)...")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Scraping 4K HDR & Debrid sources...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
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
                            .foregroundColor(.blue)

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
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())

                        Button("Start Over") {
                            seekTo(0)
                            showResumeBanner = false
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
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
                                    .foregroundColor(.cyan)
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
                                    .background(Color.blue)
                                    .foregroundColor(.white)
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
                        .background(.ultraThinMaterial)
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
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)

                        VStack(spacing: 6) {
                            Text("Playback Notice")
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Text(playbackError ?? "This high-bitrate stream (MKV/Dolby TrueHD) can be played directly with Soia Engine or an external player.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 480)
                        }

                        VStack(spacing: 12) {
                            // Option 1: Embedded Soia Engine (libmpv)
                            if soiaEngine.isLoaded {
                                Button(action: {
                                    switchToSoiaEngine()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "cpu.fill")
                                        Text("Play with In-App Soia Engine (libmpv)")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: 380)
                                    .padding(.vertical, 12)
                                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }

                            // Option 2: Alternative Sources Drawer
                            Button(action: {
                                showPlaybackErrorSheet = false
                                withAnimation { showSourcesDrawer = true }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles.tv")
                                    Text("Choose Alternative 4K / 1080p Source")
                                }
                                .font(.headline)
                                .frame(maxWidth: 380)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            // Option 3: External Players with exact resume timestamp
                            if let url = activeStreamURL ?? streamURL {
                                if ExternalPlayer.iina.isInstalled {
                                    Button(action: {
                                        ExternalPlayer.iina.open(url: url, startTime: currentTime)
                                        showPlaybackErrorSheet = false
                                        onDismiss()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.rectangle.fill")
                                            Text("Open in IINA (starts at \(formatTime(currentTime)))")
                                        }
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: 380)
                                        .padding(.vertical, 10)
                                        .background(Color.purple.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if ExternalPlayer.vlc.isInstalled {
                                    Button(action: {
                                        ExternalPlayer.vlc.open(url: url, startTime: currentTime)
                                        showPlaybackErrorSheet = false
                                        onDismiss()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.circle.fill")
                                            Text("Open in VLC (starts at \(formatTime(currentTime)))")
                                        }
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: 380)
                                        .padding(.vertical, 10)
                                        .background(Color.orange.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

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
                // Top Bar
                HStack(spacing: 16) {
                    Button(action: {
                        exitPlayer()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    if let media = mediaItem {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(media.title)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                if media.type == .series {
                                    Text("S\(playingSeasonNumber) E\(playingEpisodeNumber)")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.3))
                                        .foregroundColor(.cyan)
                                        .cornerRadius(4)
                                }

                                Text(currentEngine == .soiaMPV ? "⚡ SOIA ENGINE (HDR TONE-MAPPED)" : "⚡ HARDWARE DECODE (60s BUFFER)")
                                    .font(.caption.bold())
                                    .foregroundColor(currentEngine == .soiaMPV ? .green : .purple)

                                if bufferedSeconds > 0 {
                                    Text("• \(Int(bufferedSeconds))s CACHED")
                                        .font(.caption2.bold())
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }

                    Spacer()

                    // Quick Watchlist Toggle
                    if let media = mediaItem {
                        Button(action: {
                            userInteracted()
                            watchlistManager.toggleWatchlist(media)
                        }) {
                            Image(systemName: watchlistManager.isWatchlisted(id: media.id) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 18))
                                .foregroundColor(watchlistManager.isWatchlisted(id: media.id) ? .yellow : .white)
                                .padding(8)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }

                    // Sources & Quality Drawer Button
                    Button(action: {
                        userInteracted()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showSourcesDrawer.toggle()
                            if showSourcesDrawer && availableStreamLinks.isEmpty {
                                loadAvailableSources()
                            }
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles.tv")
                                .font(.system(size: 14, weight: .bold))
                            Text("Sources")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    // TV Show Episodes Drawer Button
                    if mediaItem?.type == .series {
                        Button(action: {
                            userInteracted()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showEpisodesDrawer.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "rectangle.grid.1x2.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Episodes")
                                    .font(.subheadline.weight(.bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: .blue.opacity(0.4), radius: 6)
                        }
                        .buttonStyle(.plain)
                    }

                    // External Player Quick Launcher
                    Button(action: {
                        userInteracted()
                        showExternalPlayerPopover.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.video.fill")
                                .font(.system(size: 14))
                            Text("External")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showExternalPlayerPopover) {
                        externalPlayersMenu
                    }

                    // Engine Switcher
                    if soiaEngine.isLoaded {
                        Button(action: {
                            userInteracted()
                            showEnginePopover.toggle()
                        }) {
                            Image(systemName: "cpu")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(8)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showEnginePopover) {
                            engineSwitcherMenu
                        }
                    }

                    // Track Selectors: Audio & Subtitles
                    HStack(spacing: 12) {
                        Button(action: {
                            userInteracted()
                            showAudioPopover.toggle()
                        }) {
                            Image(systemName: "waveform")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(8)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showAudioPopover) {
                            audioTracksMenu
                        }

                        Button(action: {
                            userInteracted()
                            showSubtitlePopover.toggle()
                        }) {
                            Image(systemName: selectedSubtitle != nil ? "captions.bubble.fill" : "captions.bubble")
                                .font(.system(size: 18))
                                .foregroundColor(selectedSubtitle != nil ? .yellow : .white.opacity(0.9))
                                .padding(8)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showSubtitlePopover) {
                            subtitlesMenu
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
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
                        }
                    )

                    // Timestamps & Controls Row
                    HStack(spacing: 18) {
                        // Play / Pause Toggle
                        Button(action: {
                            userInteracted()
                            togglePlayPause()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 38))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)

                        // Skip -10s
                        Button(action: {
                            userInteracted()
                            seekRelative(-10)
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)

                        // Skip +10s
                        Button(action: {
                            userInteracted()
                            seekRelative(10)
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)

                        // Time display (Current / Total / Remaining)
                        HStack(spacing: 6) {
                            Text(formatTime(currentTime))
                                .font(.caption.monospacedDigit().bold())
                                .foregroundColor(.white)

                            Text("/")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text(formatTime(duration))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.gray)

                            if duration > currentTime {
                                Text("(-\(formatTime(duration - currentTime)))")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        Spacer()

                        // Playback Speed Selector (0.75x, 1x, 1.25x, 1.5x, 2x)
                        Button(action: {
                            userInteracted()
                            cyclePlaybackSpeed()
                        }) {
                            Text(String(format: "%.2fx", playbackSpeed).replacingOccurrences(of: ".00", with: ""))
                                .font(.caption.bold().monospacedDigit())
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)

                        // Aspect Ratio Toggle (Fit / Zoom Fill / Stretch)
                        Button(action: {
                            userInteracted()
                            cycleVideoGravity()
                        }) {
                            Image(systemName: "aspectratio")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(6)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        #if os(macOS)
                        // Picture-in-Picture Button
                        Button(action: {
                            userInteracted()
                            pipTrigger.toggle()
                        }) {
                            Image(systemName: "pip.enter")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(6)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        #endif

                        // Volume / Mute
                        HStack(spacing: 8) {
                            Button(action: {
                                userInteracted()
                                isMuted.toggle()
                                if currentEngine == .soiaMPV {
                                    soiaEngine.setVolume(isMuted ? 0 : volume)
                                } else {
                                    player?.isMuted = isMuted
                                }
                            }) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : (volume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)

                            Slider(value: $volume, in: 0...1) { _ in
                                userInteracted()
                                if currentEngine == .soiaMPV {
                                    soiaEngine.setVolume(volume)
                                } else {
                                    player?.volume = Float(volume)
                                }
                                if isMuted && volume > 0 {
                                    isMuted = false
                                    player?.isMuted = false
                                }
                            }
                            .tint(.white.opacity(0.8))
                            .frame(width: 75)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 18)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.4), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                )
            }
            .opacity(showControls ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.25), value: showControls)

            // 11. TV Show Seasons & Episodes Side Drawer
            if showEpisodesDrawer {
                episodesSideDrawer
                    .transition(.move(edge: .trailing))
                    .zIndex(250)
            }

            // 12. In-Player Stream Sources & Quality Switcher Drawer
            if showSourcesDrawer {
                sourcesSideDrawer
                    .transition(.move(edge: .trailing))
                    .zIndex(260)
            }
        }
        .onAppear {
            if let s = currentSeason { playingSeasonNumber = s; selectedSeasonNumber = s }
            if let e = currentEpisode { playingEpisodeNumber = e }
            if !initialLinks.isEmpty {
                availableStreamLinks = initialLinks
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

        // Automatic choice of engine if user configured "soia"
        if Config.playbackEngineMode == "soia" && soiaEngine.isLoaded {
            switchToSoiaEngine()
            return
        }

        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = Config.bufferAheadSeconds
        playerItem.automaticallyPreservesTimeOffsetFromLive = true

        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        self.player = newPlayer
        newPlayer.play()
        self.isPlaying = true

        setupStallWatchdog(for: playerItem)

        // Observe Item Status & Errors
        Task {
            if let dur = try? await playerItem.asset.load(.duration) {
                await MainActor.run {
                    self.duration = dur.seconds
                }
            }
        }

        // Periodic observer for current time & watch history auto-save
        newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000), queue: .main) { time in
            let sec = time.seconds
            self.currentTime = sec
            if let itemDur = newPlayer.currentItem?.duration.seconds, !itemDur.isNaN, itemDur > 0 {
                self.duration = itemDur
            }

            // Update on-screen subtitle cue
            updateSubtitleCue(currentSecond: sec)

            // Auto-save history every 5 seconds while playing
            if self.isPlaying && sec > 5 && Date().timeIntervalSince(self.lastHistorySaveTime) > 5.0 {
                self.saveCurrentHistoryProgress()
            }

            // Zero-latency next episode pre-caching (< 75 seconds remaining)
            self.checkPrecacheNextEpisode(currentSec: sec)

            // Check if near end of episode for next episode countdown (< 25s)
            if self.mediaItem?.type == .series && self.duration > 60 && sec >= (self.duration - 25.0) {
                if !self.showNextEpisodeCard && Config.autoPlayNextEpisode {
                    self.triggerNextEpisodeCountdown()
                }
            }
        }

        // Watch for playback errors
        NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: .main) { notif in
            let err = (notif.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
            self.playbackError = err ?? "Stream encountered a format error (e.g. MKV/Dolby TrueHD)."
            self.showPlaybackErrorSheet = true
        }

        loadEmbeddedTracks(item: playerItem)
    }

    private func setupStallWatchdog(for playerItem: AVPlayerItem) {
        cancellables.removeAll()

        playerItem.publisher(for: \.loadedTimeRanges)
            .receive(on: DispatchQueue.main)
            .sink { [self] ranges in
                guard let first = ranges.first as? CMTimeRange else { return }
                let loadedEnd = first.start.seconds + first.duration.seconds
                self.bufferedSeconds = max(0, loadedEnd - self.currentTime)
                if self.duration > 0 {
                    self.bufferedFraction = min(1.0, loadedEnd / self.duration)
                }
            }
            .store(in: &cancellables)

        playerItem.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [self] empty in
                if empty && self.isPlaying {
                    self.isBuffering = true
                }
            }
            .store(in: &cancellables)

        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [self] likely in
                if likely {
                    self.isBuffering = false
                    self.stallSecondsCount = 0
                    if self.isPlaying {
                        self.player?.play()
                        self.player?.rate = Float(self.playbackSpeed)
                    }
                }
            }
            .store(in: &cancellables)

        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            guard self.isPlaying, let p = self.player else { return }
            if p.timeControlStatus == .waitingToPlayAtSpecifiedRate || self.isBuffering {
                self.stallSecondsCount += 1.0
                if self.stallSecondsCount == 6.0 {
                    print("[StallWatchdog] Soft kick after 6s")
                    p.play()
                    p.rate = Float(self.playbackSpeed)
                } else if self.stallSecondsCount == 14.0 {
                    print("[StallWatchdog] Reseeking after 14s")
                    p.seek(to: CMTime(seconds: self.currentTime, preferredTimescale: 1000))
                    p.play()
                    p.rate = Float(self.playbackSpeed)
                } else if self.stallSecondsCount >= 22.0 {
                    print("[StallWatchdog] Prolonged stall. Trying auto-recovery.")
                    self.attemptStallAutoRecovery()
                }
            } else {
                self.stallSecondsCount = 0
                if self.isBuffering {
                    self.isBuffering = false
                }
            }
        }
    }

    private func attemptStallAutoRecovery() {
        stallSecondsCount = 0
        showToast("Reconnecting Debrid stream buffer...")
        guard let url = activeStreamURL ?? streamURL else { return }
        let saved = currentTime
        let newItem = AVPlayerItem(url: url)
        newItem.preferredForwardBufferDuration = Config.bufferAheadSeconds
        setupStallWatchdog(for: newItem)
        player?.replaceCurrentItem(with: newItem)
        player?.seek(to: CMTime(seconds: saved, preferredTimescale: 1000))
        player?.play()
        player?.rate = Float(playbackSpeed)
    }

    private func switchToSoiaEngine() {
        guard let url = activeStreamURL ?? streamURL else { return }
        let saved = currentTime
        player?.pause()
        currentEngine = .soiaMPV
        showPlaybackErrorSheet = false
        showToast("Switched to Soia Engine (libmpv)")
        startSoiaPolling(savedTime: saved)
    }

    private func startSoiaPolling(savedTime: Double = 0) {
        soiaPollTimer?.invalidate()
        if savedTime > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.soiaEngine.seekTo(savedTime)
            }
        }
        soiaPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let pos = self.soiaEngine.getTimePos()
            let dur = self.soiaEngine.getDuration()
            let cache = self.soiaEngine.getCacheDuration()

            if pos > 0 { self.currentTime = pos }
            if dur > 0 { self.duration = dur }
            if dur > 0 {
                self.bufferedSeconds = cache
                self.bufferedFraction = min(1.0, (pos + cache) / dur)
            }

            self.updateSubtitleCue(currentSecond: pos)

            if self.isPlaying && pos > 5 && Date().timeIntervalSince(self.lastHistorySaveTime) > 5.0 {
                self.saveCurrentHistoryProgress()
            }

            self.checkPrecacheNextEpisode(currentSec: pos)

            if self.mediaItem?.type == .series && dur > 60 && pos >= (dur - 25.0) {
                if !self.showNextEpisodeCard && Config.autoPlayNextEpisode {
                    self.triggerNextEpisodeCountdown()
                }
            }
        }
    }

    private func cycleVideoGravity() {
        switch videoGravity {
        case .resizeAspect:
            videoGravity = .resizeAspectFill
            showToast("Aspect: Zoom / Fill (No Black Bars)")
        case .resizeAspectFill:
            videoGravity = .resize
            showToast("Aspect: Stretch to Window")
        default:
            videoGravity = .resizeAspect
            showToast("Aspect: Fit (Original Aspect)")
        }
    }

    private func cyclePlaybackSpeed() {
        if playbackSpeed == 1.0 {
            playbackSpeed = 1.25
        } else if playbackSpeed == 1.25 {
            playbackSpeed = 1.5
        } else if playbackSpeed == 1.5 {
            playbackSpeed = 2.0
        } else if playbackSpeed == 2.0 {
            playbackSpeed = 0.75
        } else {
            playbackSpeed = 1.0
        }

        if currentEngine == .soiaMPV {
            soiaEngine.setSpeed(playbackSpeed)
        } else {
            player?.rate = Float(playbackSpeed)
        }
        showToast("Playback Speed: \(String(format: "%.2fx", playbackSpeed).replacingOccurrences(of: ".00", with: ""))")
    }

    private func checkPrecacheNextEpisode(currentSec: Double) {
        guard mediaItem?.type == .series, duration > 90, currentSec >= (duration - 75.0) else { return }
        guard prefetchedNextEpisodeURL == nil, !isPrefetchingNextEpisode else { return }
        isPrefetchingNextEpisode = true
        let nextEp = playingEpisodeNumber + 1
        guard let media = mediaItem else { return }

        Task {
            print("[PlayerView] Pre-caching next episode S\(playingSeasonNumber) E\(nextEp)...")
            if let links = try? await aggregatorService.fetchBestLinks(
                tmdbID: media.id,
                imdbID: media.imdbID,
                type: .series,
                season: playingSeasonNumber,
                episode: nextEp
            ), let top = links.first {
                if let (resURL, _) = try? await aggregatorService.resolveStreamURLWithFallback(startingLink: top, allLinks: links) {
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
        hideControlsWorkItem?.cancel()
        countdownTimer?.invalidate()
        stallTimer?.invalidate()
        soiaPollTimer?.invalidate()
        cancellables.removeAll()
        saveCurrentHistoryProgress()
        #if os(macOS)
        if let mon = keyEventMonitor {
            NSEvent.removeMonitor(mon)
            keyEventMonitor = nil
        }
        NSCursor.unhide()
        #endif
        player?.pause()
        player = nil
        if currentEngine == .soiaMPV {
            soiaEngine.destroy()
        }
    }

    private func exitPlayer() {
        teardownPlayer()
        onDismiss()
    }

    // MARK: - In-Player Alternative Sources Drawer
    private func loadAvailableSources() {
        guard let media = mediaItem else { return }
        isLoadingSources = true
        Task {
            do {
                let links = try await aggregatorService.fetchBestLinks(
                    tmdbID: media.id,
                    imdbID: media.imdbID,
                    type: media.type,
                    season: playingSeasonNumber,
                    episode: playingEpisodeNumber
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
                    self.activeStreamURL = newURL
                    if self.currentEngine == .soiaMPV {
                        self.soiaEngine.playNewStream(urlString: newURL.absoluteString)
                        self.soiaEngine.seekTo(savedTime)
                    } else {
                        let newItem = AVPlayerItem(url: newURL)
                        newItem.preferredForwardBufferDuration = Config.bufferAheadSeconds
                        self.setupStallWatchdog(for: newItem)
                        self.player?.replaceCurrentItem(with: newItem)
                        self.player?.seek(to: CMTime(seconds: savedTime, preferredTimescale: 1000))
                        self.player?.play()
                        self.player?.rate = Float(self.playbackSpeed)
                        self.isPlaying = true
                    }
                    self.showToast("Switched to \(link.resolutionBadge) at \(formatTime(savedTime))")
                }
            } catch {
                await MainActor.run {
                    self.showToast("Failed to switch source: \(error.localizedDescription)")
                }
            }
        }
    }

    private var sourcesSideDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "sparkles.tv")
                    .foregroundColor(.yellow)
                Text("Stream Sources & Quality")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Button(action: { withAnimation { showSourcesDrawer = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color.black.opacity(0.4))

            if isLoadingSources {
                VStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Text("Finding alternative 4K & FHD streams...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if availableStreamLinks.isEmpty {
                VStack {
                    Spacer()
                    Text("No alternative sources available")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(availableStreamLinks) { link in
                            Button(action: {
                                switchToLink(link)
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            Text(link.resolutionBadge)
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.3))
                                                .foregroundColor(.cyan)
                                                .cornerRadius(4)

                                            if let size = link.sizeString {
                                                Text(size)
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.white.opacity(0.12))
                                                    .foregroundColor(.white.opacity(0.9))
                                                    .cornerRadius(4)
                                            }

                                            if link.isCached {
                                                Text("⚡ Instant Debrid")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.25))
                                                    .foregroundColor(.green)
                                                    .cornerRadius(4)
                                            }

                                            if let hdr = link.hdrTag {
                                                Text(hdr)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple.opacity(0.3))
                                                    .foregroundColor(.purple)
                                                    .cornerRadius(4)
                                            }

                                            if let audio = link.audioTag {
                                                Text(audio)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange.opacity(0.25))
                                                    .foregroundColor(.orange)
                                                    .cornerRadius(4)
                                            }
                                        }

                                        Text(link.title)
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }

                                    Spacer()

                                    Image(systemName: "play.circle")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 380)
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .shadow(color: .black.opacity(0.7), radius: -10, y: 0)
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

        if let option = track.option, let group = embeddedSubGroup {
            player?.currentItem?.select(option, in: group)
        } else if let externalURL = track.externalURL {
            disableEmbeddedSubtitles()
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
        disableEmbeddedSubtitles()
    }

    private func disableEmbeddedSubtitles() {
        if let group = embeddedSubGroup {
            player?.currentItem?.select(nil, in: group)
        }
    }

    private func updateSubtitleCue(currentSecond: Double) {
        guard !subtitleCues.isEmpty else { return }
        let adjusted = currentSecond + subtitleOffsetSeconds
        let active = subtitleCues.first { cue in
            cue.startTime <= adjusted && adjusted <= cue.endTime
        }
        currentSubtitleText = active?.text
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
                self.isMuted.toggle()
                if self.currentEngine == .soiaMPV {
                    self.soiaEngine.setVolume(self.isMuted ? 0 : self.volume)
                } else {
                    self.player?.isMuted = self.isMuted
                }
                return nil
            case 3: // 'F'
                if let window = NSApp.keyWindow {
                    window.toggleFullScreen(nil)
                }
                return nil
            case 8: // 'C'
                if self.selectedSubtitle != nil {
                    self.disableSubtitles()
                } else if let first = self.subtitles.first {
                    self.selectSubtitleTrack(first)
                }
                return nil
            case 1: // 'S' - Sources
                withAnimation {
                    self.showSourcesDrawer.toggle()
                    if self.showSourcesDrawer && self.availableStreamLinks.isEmpty {
                        self.loadAvailableSources()
                    }
                }
                return nil
            case 14: // 'E' - Episodes
                if self.mediaItem?.type == .series {
                    withAnimation { self.showEpisodesDrawer.toggle() }
                }
                return nil
            case 35: // 'P' - Picture in Picture
                self.pipTrigger.toggle()
                return nil
            case 53: // Esc
                self.exitPlayer()
                return nil
            default:
                return event
            }
        }
        #endif
    }

    private func adjustVolume(by delta: Double) {
        userInteracted()
        volume = max(0, min(1.0, volume + delta))
        if currentEngine == .soiaMPV {
            soiaEngine.setVolume(volume)
        } else {
            player?.volume = Float(volume)
        }
        if isMuted && volume > 0 {
            isMuted = false
            player?.isMuted = false
        }
    }

    // MARK: - Auto-Hide Controls & Inactivity
    private func userInteracted() {
        showControls = true
        #if os(macOS)
        NSCursor.unhide()
        #endif
        hideControlsWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            if isPlaying && !showEpisodesDrawer && !showSourcesDrawer && !showAudioPopover && !showSubtitlePopover && !showExternalPlayerPopover && !showEnginePopover {
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
        if currentEngine == .soiaMPV {
            soiaEngine.togglePlayPause()
            isPlaying = soiaEngine.isPlaying
        } else if let player = player {
            if isPlaying {
                player.pause()
            } else {
                player.play()
                player.rate = Float(playbackSpeed)
            }
            isPlaying.toggle()
        }

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
        if currentEngine == .soiaMPV {
            soiaEngine.seekRelative(seconds)
            currentTime = max(0, min(currentTime + seconds, duration))
        } else if let player = player {
            let newTime = max(0, min(currentTime + seconds, duration))
            player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1000))
            currentTime = newTime
        }
    }

    private func seekTo(_ seconds: Double) {
        if currentEngine == .soiaMPV {
            soiaEngine.seekTo(seconds)
            currentTime = seconds
        } else if let player = player {
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
            currentTime = seconds
        }
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

            if currentEngine == .soiaMPV {
                soiaEngine.playNewStream(urlString: preURL.absoluteString)
            } else {
                let item = AVPlayerItem(url: preURL)
                item.preferredForwardBufferDuration = Config.bufferAheadSeconds
                setupStallWatchdog(for: item)
                player?.replaceCurrentItem(with: item)
                player?.play()
                player?.rate = Float(playbackSpeed)
                isPlaying = true
            }
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

                let eps = await tmdbService.fetchSeasonEpisodes(tvID: media.id, seasonNumber: targetSeason)
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

                        if self.currentEngine == .soiaMPV {
                            self.soiaEngine.playNewStream(urlString: resolvedURL.absoluteString)
                        } else {
                            let item = AVPlayerItem(url: resolvedURL)
                            item.preferredForwardBufferDuration = Config.bufferAheadSeconds
                            self.setupStallWatchdog(for: item)
                            self.player?.replaceCurrentItem(with: item)
                            self.player?.play()
                            self.player?.rate = Float(self.playbackSpeed)
                            self.isPlaying = true
                        }

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

    // MARK: - Audio & Embedded Tracks
    private func loadEmbeddedTracks(item: AVPlayerItem) {
        Task {
            let asset = item.asset
            if let audioGroup = try? await asset.loadMediaSelectionGroup(for: .audible) {
                let options = audioGroup.options
                let tracks = options.compactMap { opt -> AudioTrackItem? in
                    return AudioTrackItem(id: UUID().uuidString, displayName: opt.displayName, option: opt)
                }
                await MainActor.run {
                    self.audioSelectionGroup = audioGroup
                    self.audioTracks = tracks
                    self.selectedAudioTrack = tracks.first
                }
            }

            if let subGroup = try? await asset.loadMediaSelectionGroup(for: .legible) {
                let options = subGroup.options
                let tracks = options.compactMap { opt -> SubtitleTrack? in
                    return SubtitleTrack(id: UUID().uuidString, displayName: opt.displayName, option: opt)
                }
                await MainActor.run {
                    self.embeddedSubGroup = subGroup
                    self.subtitles.insert(contentsOf: tracks, at: 0)
                }
            }
        }
    }

    private var engineSwitcherMenu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Playback Engine")
                .font(.headline)
                .padding(.bottom, 2)

            ForEach(PlayerEngineType.allCases) { eng in
                Button(action: {
                    showEnginePopover = false
                    if eng != currentEngine {
                        if eng == .soiaMPV {
                            switchToSoiaEngine()
                        } else {
                            currentEngine = .avPlayer
                            setupPlayer()
                        }
                    }
                }) {
                    HStack {
                        Text(eng.rawValue)
                        Spacer()
                        if currentEngine == eng {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private var audioTracksMenu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audio Tracks")
                .font(.headline)
                .padding(.bottom, 4)

            if audioTracks.isEmpty {
                Text("Default Stream Audio")
                    .foregroundColor(.secondary)
            } else {
                ForEach(audioTracks) { track in
                    Button(action: {
                        selectedAudioTrack = track
                        if let group = audioSelectionGroup, let option = track.option {
                            player?.currentItem?.select(option, in: group)
                        }
                        showAudioPopover = false
                    }) {
                        HStack {
                            Text(track.displayName)
                            Spacer()
                            if selectedAudioTrack?.id == track.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(width: 220)
    }

    private var subtitlesMenu: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Subtitles")
                    .font(.headline)
                Spacer()
                if isLoadingSubtitles {
                    ProgressView().scaleEffect(0.7)
                }
            }

            Button(action: {
                disableSubtitles()
                showSubtitlePopover = false
            }) {
                HStack {
                    Text("Off")
                    Spacer()
                    if selectedSubtitle == nil {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(.plain)

            Divider()

            // Subtitle Delay Offset Controls
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sync Offset:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%+.1fs", subtitleOffsetSeconds))
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                }

                HStack(spacing: 8) {
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
            .padding(.vertical, 2)

            // Subtitle Appearance: Color & Size
            VStack(alignment: .leading, spacing: 4) {
                Text("Subtitle Color:")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack(spacing: 8) {
                    Button("Yellow") { subtitleColor = .yellow }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .foregroundColor(.yellow)
                    Button("White") { subtitleColor = .white }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .foregroundColor(.white)
                    Button("Cyan") { subtitleColor = .cyan }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .foregroundColor(.cyan)
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(subtitles) { track in
                        Button(action: {
                            selectSubtitleTrack(track)
                            showSubtitlePopover = false
                        }) {
                            HStack {
                                Text(track.displayName)
                                    .lineLimit(1)
                                Spacer()
                                if selectedSubtitle?.id == track.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .frame(width: 260)
    }

    private var externalPlayersMenu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Open in External Player")
                .font(.headline)
                .padding(.bottom, 2)

            ForEach(ExternalPlayer.allCases) { playerApp in
                Button(action: {
                    showExternalPlayerPopover = false
                    if let url = activeStreamURL ?? streamURL {
                        playerApp.open(url: url, startTime: currentTime)
                    }
                }) {
                    HStack {
                        Text(playerApp.rawValue)
                        Spacer()
                        if playerApp.isInstalled {
                            Text("Installed")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                        } else {
                            Text("Not Found")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!playerApp.isInstalled)
            }
        }
        .padding()
        .frame(width: 220)
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
                                .background(selectedSeasonNumber == sNum ? Color.blue : Color.white.opacity(0.1))
                                .foregroundColor(selectedSeasonNumber == sNum ? .white : .gray)
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
                                        .foregroundColor(isCurrent ? .green : .gray)
                                        .frame(width: 24)

                                    if let still = ep.stillURL {
                                        AsyncImage(url: still) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.white.opacity(0.1))
                                        }
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
                                                Text("NOW PLAYING")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.3))
                                                    .foregroundColor(.green)
                                                    .cornerRadius(4)
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
                                .background(isCurrent ? Color.green.opacity(0.1) : Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isCurrent ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
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
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .shadow(color: .black.opacity(0.7), radius: -10, y: 0)
    }

    private func loadTVShowData() {
        guard let media = mediaItem, media.type == .series else { return }
        Task {
            let count = await tmdbService.fetchTVSeasonsCount(tvID: media.id)
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
            let eps = await tmdbService.fetchSeasonEpisodes(tvID: media.id, seasonNumber: sNum)
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
