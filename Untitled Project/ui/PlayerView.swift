import SwiftUI
import AVKit

#if os(macOS)
import AppKit

struct NativePlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.videoGravity = .resizeAspect
        playerView.wantsLayer = true
        playerView.layer?.backgroundColor = NSColor.black.cgColor
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player != player {
            nsView.player = player
        }
    }
}
#endif

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
    var onDismiss: () -> Void

    @StateObject private var watchlistManager = WatchlistManager.shared
    @State private var activeStreamURL: URL? = nil
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0

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

    // Auto-hide controls state
    @State private var showControls: Bool = true
    @State private var hideControlsWorkItem: DispatchWorkItem? = nil

    // Transient play/pause pulse animation
    @State private var showPlayPausePulse: Bool = false
    @State private var isMuted: Bool = false

    // Subtitles & Audio Tracks
    @State private var subtitles: [SubtitleTrack] = []
    @State private var selectedSubtitle: SubtitleTrack?
    @State private var audioTracks: [AudioTrackItem] = []
    @State private var selectedAudioTrack: AudioTrackItem?
    @State private var audioSelectionGroup: AVMediaSelectionGroup?
    @State private var embeddedSubGroup: AVMediaSelectionGroup?

    // Audio & Subtitle Popovers
    @State private var showAudioPopover: Bool = false
    @State private var showSubtitlePopover: Bool = false

    private let tmdbService = TMDBService()
    private let aggregatorService = AggregatorService()

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.ignoresSafeArea()

            if let _ = activeStreamURL ?? streamURL, let p = player {
                #if os(macOS)
                NativePlayerView(player: p)
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

            // Click detector layer to toggle GUI & play/pause
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    userInteracted()
                    togglePlayPause()
                }
                .onHover { isHovered in
                    if isHovered {
                        userInteracted()
                    }
                }

            // Episode Switching Spinner Overlay
            if isSwitchingEpisode {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        Text("Switching to \(switchingEpisodeTitle)...")
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

            // Transient Center Play/Pause Pulse Icon
            if showPlayPausePulse {
                Image(systemName: isPlaying ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.6), radius: 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            // Floating Minimalist Overlay Controls
            VStack {
                // Top Bar
                HStack(spacing: 16) {
                    Button(action: {
                        player?.pause()
                        player = nil
                        onDismiss()
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

                                Text("⚡ SOIA HARDWARE ENGINE (4K / DV)")
                                    .font(.caption.bold())
                                    .foregroundColor(.purple)
                            }
                        }
                    }

                    Spacer()

                    // Watchlist Toggle Button
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
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: .blue.opacity(0.4), radius: 6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Track Selectors
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
                            Image(systemName: "captions.bubble.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
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

                // Bottom Control Bar
                VStack(spacing: 12) {
                    // Time Scrubber
                    HStack(spacing: 12) {
                        Text(formatTime(currentTime))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundColor(.white.opacity(0.9))

                        Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                            userInteracted()
                            if !editing {
                                player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 1000))
                            }
                        }
                        .tint(.blue)

                        Text(formatTime(duration))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Centered Playback Controls Layout
                    HStack(alignment: .center) {
                        // Left slot for symmetry
                        Color.clear.frame(width: 80, height: 44)

                        Spacer()

                        // Centered Controls: Skip -10s, Play/Pause, Skip +10s
                        HStack(spacing: 24) {
                            Button(action: {
                                userInteracted()
                                seekRelative(-10)
                            }) {
                                Image(systemName: "gobackward.10")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                userInteracted()
                                togglePlayPause()
                            }) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                userInteracted()
                                seekRelative(10)
                            }) {
                                Image(systemName: "goforward.10")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        // Right slot: Mute button
                        HStack {
                            Button(action: {
                                userInteracted()
                                isMuted.toggle()
                                player?.isMuted = isMuted
                            }) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: 80, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.4), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                )
            }
            .opacity(showControls ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.25), value: showControls)

            // TV Show Seasons & Episodes Glass Side Drawer
            if showEpisodesDrawer {
                episodesSideDrawer
                    .transition(.move(edge: .trailing))
                    .zIndex(250)
            }
        }
        .onAppear {
            if let s = currentSeason { playingSeasonNumber = s; selectedSeasonNumber = s }
            if let e = currentEpisode { playingEpisodeNumber = e }
            setupPlayer()
            userInteracted()
            if mediaItem?.type == .series {
                loadTVShowData()
            }
        }
        .onDisappear {
            hideControlsWorkItem?.cancel()
            if let media = mediaItem {
                watchlistManager.recordHistory(
                    item: media,
                    season: playingSeasonNumber,
                    episode: playingEpisodeNumber,
                    progress: currentTime,
                    duration: duration
                )
            }
            player?.pause()
            player = nil
        }
    }

    private func userInteracted() {
        showControls = true
        hideControlsWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            if isPlaying && !showEpisodesDrawer {
                withAnimation {
                    showControls = false
                }
            }
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    private func setupPlayer() {
        activeStreamURL = streamURL
        guard let url = activeStreamURL else { return }

        if let media = mediaItem {
            watchlistManager.recordHistory(
                item: media,
                season: playingSeasonNumber,
                episode: playingEpisodeNumber,
                progress: currentTime,
                duration: duration
            )
        }

        let headers = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer
        newPlayer.play()
        self.isPlaying = true

        Task {
            if let dur = try? await playerItem.asset.load(.duration) {
                await MainActor.run {
                    self.duration = dur.seconds
                }
            }
        }

        newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000), queue: .main) { time in
            self.currentTime = time.seconds
            if let itemDur = newPlayer.currentItem?.duration.seconds, !itemDur.isNaN, itemDur > 0 {
                self.duration = itemDur
            }
        }

        loadEmbeddedTracks(item: playerItem)
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

    private func selectEpisodeToPlay(episode: TVEpisodeItem) {
        guard let media = mediaItem else { return }
        isSwitchingEpisode = true
        switchingEpisodeTitle = "S\(selectedSeasonNumber) E\(episode.episodeNumber): \(episode.name)"

        Task {
            do {
                let links = try await aggregatorService.fetchBestLinks(
                    tmdbID: media.id,
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

                        let headers = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"]
                        let asset = AVURLAsset(url: resolvedURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                        let item = AVPlayerItem(asset: asset)

                        self.player?.replaceCurrentItem(with: item)
                        self.player?.play()
                        self.isPlaying = true

                        self.isSwitchingEpisode = false
                        withAnimation {
                            self.showEpisodesDrawer = false
                        }
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

    // Side Drawer for Seasons & Episodes
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
            .padding(16)
            .background(Color.black.opacity(0.4))

            // Season Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...max(1, totalSeasonsCount), id: \.self) { s in
                        Button(action: {
                            selectedSeasonNumber = s
                            loadSeasonEpisodes(s)
                        }) {
                            Text("Season \(s)")
                                .font(.caption.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(selectedSeasonNumber == s ? Color.blue : Color.white.opacity(0.12))
                                .foregroundColor(selectedSeasonNumber == s ? .white : .gray)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider().background(Color.white.opacity(0.1))

            // Episodes List
            if isLoadingEpisodes {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(episodesList) { ep in
                            Button(action: {
                                selectEpisodeToPlay(episode: ep)
                            }) {
                                HStack(spacing: 12) {
                                    Text("\(ep.episodeNumber)")
                                        .font(.caption.monospacedDigit().bold())
                                        .foregroundColor(playingSeasonNumber == selectedSeasonNumber && playingEpisodeNumber == ep.episodeNumber ? .cyan : .gray)
                                        .frame(width: 20)

                                    if let stillURL = ep.stillURL {
                                        AsyncImage(url: stillURL) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.gray.opacity(0.2))
                                        }
                                        .frame(width: 80, height: 48)
                                        .cornerRadius(6)
                                        .clipped()
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ep.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        if let plot = ep.overview, !plot.isEmpty {
                                            Text(plot)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    if playingSeasonNumber == selectedSeasonNumber && playingEpisodeNumber == ep.episodeNumber {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.caption)
                                            .foregroundColor(.cyan)
                                    }
                                }
                                .padding(10)
                                .background(
                                    playingSeasonNumber == selectedSeasonNumber && playingEpisodeNumber == ep.episodeNumber ?
                                    Color.blue.opacity(0.25) : Color.white.opacity(0.06)
                                )
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 320)
        .background(Color(red: 0.1, green: 0.1, blue: 0.13).opacity(0.95))
        .overlay(Rectangle().frame(width: 1).foregroundColor(Color.white.opacity(0.15)), alignment: .leading)
    }

    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }

        withAnimation(.easeOut(duration: 0.2)) {
            showPlayPausePulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.3)) {
                showPlayPausePulse = false
            }
        }
    }

    private func seekRelative(_ seconds: Double) {
        guard let p = player else { return }
        let current = p.currentTime().seconds
        let target = max(0, min(current + seconds, duration))
        p.seek(to: CMTime(seconds: target, preferredTimescale: 1000))
        self.currentTime = target
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let sec = Int(seconds)
        let hours = sec / 3600
        let minutes = (sec % 3600) / 60
        let secs = sec % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    private func loadEmbeddedTracks(item: AVPlayerItem) {
        Task {
            guard let asset = try? await item.asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions) else { return }

            // Audio Tracks
            if let audioGroup = try? await item.asset.loadMediaSelectionGroup(for: .audible) {
                await MainActor.run {
                    self.audioSelectionGroup = audioGroup
                    self.audioTracks = audioGroup.options.compactMap { opt in
                        let name = opt.displayName
                        let lang = opt.extendedLanguageTag ?? "Unknown"
                        let title = "\(name) (\(lang.uppercased()))"
                        return AudioTrackItem(id: opt.displayName, displayName: title, option: opt)
                    }
                }
            }

            // Subtitle Tracks
            if let subGroup = try? await item.asset.loadMediaSelectionGroup(for: .legible) {
                await MainActor.run {
                    self.embeddedSubGroup = subGroup
                    let embeddedSubs = subGroup.options.compactMap { opt in
                        let name = opt.displayName
                        let lang = opt.extendedLanguageTag ?? "Unknown"
                        let title = "\(name) (\(lang.uppercased()))"
                        return SubtitleTrack(displayName: title, option: opt)
                    }
                    self.subtitles = [SubtitleTrack(displayName: "Off")] + embeddedSubs
                }
            }
        }
    }

    private var audioTracksMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audio Tracks")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Divider()

            ForEach(audioTracks) { track in
                Button(action: {
                    selectedAudioTrack = track
                    if let group = audioSelectionGroup, let opt = track.option {
                        player?.currentItem?.select(opt, in: group)
                    }
                    showAudioPopover = false
                }) {
                    HStack {
                        Text(track.displayName)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        if selectedAudioTrack?.id == track.id {
                            Image(systemName: "check")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 220)
        .padding(.vertical, 4)
        .background(Color(red: 0.15, green: 0.15, blue: 0.18))
    }

    private var subtitlesMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Subtitles")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Divider()

            ForEach(subtitles) { track in
                Button(action: {
                    selectedSubtitle = track
                    if let opt = track.option, let group = embeddedSubGroup {
                        player?.currentItem?.select(opt, in: group)
                    } else if track.displayName == "Off", let group = embeddedSubGroup {
                        player?.currentItem?.select(nil, in: group)
                    }
                    showSubtitlePopover = false
                }) {
                    HStack {
                        Text(track.displayName)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        if selectedSubtitle?.id == track.id {
                            Image(systemName: "check")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 220)
        .padding(.vertical, 4)
        .background(Color(red: 0.15, green: 0.15, blue: 0.18))
    }
}
