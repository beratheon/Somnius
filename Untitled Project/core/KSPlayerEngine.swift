import Foundation
import SwiftUI
import AppKit
import Combine
import KSPlayer
import AVFoundation

public struct KSPlayerTrackInfo: Identifiable, Hashable {
    public let id: Int32
    public let name: String
    public let language: String?
    public let isEnabled: Bool

    public init(id: Int32, name: String, language: String?, isEnabled: Bool) {
        self.id = id
        self.name = name
        self.language = language
        self.isEnabled = isEnabled
    }
}

@MainActor
public class KSPlayerEngine: ObservableObject {
    public static let shared = KSPlayerEngine()

    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var bufferedTime: Double = 0
    @Published public var bufferedFraction: Double = 0
    @Published public var isPlaying: Bool = false
    @Published public var isBuffering: Bool = false
    @Published public var playbackRate: Double = 1.0
    @Published public var volume: Double = 1.0
    @Published public var isMuted: Bool = false
    @Published public var isAspectFill: Bool = false
    @Published public var isPipActive: Bool = false
    @Published public var playbackError: String? = nil
    @Published public var currentURL: URL? = nil

    @Published public var availableAudioTracks: [KSPlayerTrackInfo] = []
    @Published public var selectedAudioTrackId: Int32? = nil

    @Published public var availableSubtitleTracks: [KSPlayerTrackInfo] = []
    @Published public var selectedSubtitleTrackId: Int32? = nil
    @Published public var currentEmbeddedSubtitleText: String? = nil

    @Published public var audioDelay: Double = 0.0 // in seconds (-3.0 to +3.0)
    @Published public var palSpeedupEnabled: Bool = false
    @Published public var isExternalAudioInjected: Bool = false
    @Published public var activeIMDbID: String? = nil

    public let coordinator = KSVideoPlayer.Coordinator()
    public let options = KSOptions()

    private var pendingStartTime: Double? = nil

    public init() {
        configureEngineOptions()
    }

    private func configureEngineOptions() {
        // Configure KSPlayer to use KSMEPlayer (FFmpeg + Metal hardware decoding)
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSAVPlayer.self
        KSOptions.hardwareDecode = true
        KSOptions.asynchronousDecompression = true
        KSOptions.isSecondOpen = Config.fastStartBuffering
        KSOptions.isAccurateSeek = true
        KSOptions.isSeekedAutoPlay = true
        KSOptions.canStartPictureInPictureAutomaticallyFromInline = true
        KSOptions.preferredForwardBufferDuration = max(10.0, Double(Config.bufferAheadSeconds))
        KSOptions.maxBufferDuration = max(60.0, Double(Config.bufferAheadSeconds) * 2)

        options.hardwareDecode = true
        options.asynchronousDecompression = true
        options.isSecondOpen = Config.fastStartBuffering
        options.probesize = 1024 * 1024 * 2 // 2MB fast stream probe
        options.maxAnalyzeDuration = 1_000_000 // 1s analyze duration
        options.formatContextOptions["tcp_nodelay"] = 1
        options.formatContextOptions["reconnect"] = 1
        options.formatContextOptions["reconnect_streamed"] = 1
        options.formatContextOptions["reconnect_delay_max"] = 3
        options.decoderOptions["threads"] = "auto"
        options.preferredForwardBufferDuration = max(10.0, Double(Config.bufferAheadSeconds))
        options.maxBufferDuration = max(60.0, Double(Config.bufferAheadSeconds) * 2)
        options.isAccurateSeek = true
        options.isSeekedAutoPlay = true
        options.autoSelectEmbedSubtitle = true
    }

    public func setAudioDelay(_ delay: Double) {
        let clamped = max(-3.0, min(3.0, (round(delay * 20.0) / 20.0))) // 50ms increments
        self.audioDelay = clamped
        if let imdb = activeIMDbID, !imdb.isEmpty {
            Self.saveLipSyncOffset(clamped, for: imdb)
        }
        applyAudioFilters()
    }

    public func setPALSpeedup(_ enabled: Bool) {
        self.palSpeedupEnabled = enabled
        applyAudioFilters()
    }

    public func applyAudioFilters() {
        var filters: [String] = []

        // PAL speedup correction: slows 25fps audio to 23.976fps
        if palSpeedupEnabled {
            filters.append("atempo=0.95904")
        }

        // Lip-sync audio delay: adelay filter (in ms)
        let delayMs = Int(audioDelay * 1000)
        if delayMs > 0 {
            filters.append("adelay=\(delayMs)|\(delayMs)")
            options.videoDelay = 0.0
        } else if delayMs < 0 {
            options.videoDelay = Double(-delayMs) / 1000.0
        } else {
            options.videoDelay = 0.0
        }

        options.audioFilters = filters
    }

    public static func savedLipSyncOffset(for imdbID: String) -> Double {
        return UserDefaults.standard.double(forKey: "Somnus_LipSync_\(imdbID)")
    }

    public static func saveLipSyncOffset(_ offset: Double, for imdbID: String) {
        UserDefaults.standard.set(offset, forKey: "Somnus_LipSync_\(imdbID)")
    }

    public func loadStream(url: URL, startTime: Double = 0, imdbID: String? = nil, isExternalAudio: Bool = false) {
        self.currentURL = url
        self.playbackError = nil
        self.isBuffering = true
        self.currentTime = startTime
        self.pendingStartTime = startTime > 0 ? startTime : nil
        self.activeIMDbID = imdbID
        self.isExternalAudioInjected = isExternalAudio

        if let imdb = imdbID, !imdb.isEmpty {
            self.audioDelay = Self.savedLipSyncOffset(for: imdb)
        } else {
            self.audioDelay = 0.0
        }
        self.palSpeedupEnabled = Config.enablePALSpeedupCorrection
        applyAudioFilters()

        if let playerLayer = coordinator.playerLayer {
            playerLayer.set(url: url, options: options)
            if startTime > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.seek(to: startTime)
                }
            }
        }
    }

    public func play() {
        coordinator.playerLayer?.play()
        isPlaying = true
    }

    public func pause() {
        coordinator.playerLayer?.pause()
        isPlaying = false
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func seek(to seconds: Double) {
        let target = max(0, min(duration > 0 ? duration : Double.greatestFiniteMagnitude, seconds))
        currentTime = target
        coordinator.seek(time: TimeInterval(target))
    }

    public func seekRelative(_ seconds: Double) {
        seek(to: currentTime + seconds)
    }

    public func setRate(_ rate: Double) {
        playbackRate = rate
        coordinator.playbackRate = Float(rate)
    }

    public func setVolume(_ vol: Double) {
        let clamped = max(0.0, min(1.0, vol))
        volume = clamped
        coordinator.playbackVolume = Float(clamped)
        if clamped > 0 && isMuted {
            isMuted = false
            coordinator.isMuted = false
        }
    }

    public func toggleMute() {
        isMuted.toggle()
        coordinator.isMuted = isMuted
    }

    public func toggleAspect() {
        isAspectFill.toggle()
        coordinator.isScaleAspectFill = isAspectFill
    }

    public func togglePiP() {
        if let playerLayer = coordinator.playerLayer {
            playerLayer.isPipActive.toggle()
            isPipActive = playerLayer.isPipActive
        }
    }

    public func selectAudioTrack(id: Int32) {
        guard let player = coordinator.playerLayer?.player else { return }
        let tracks = player.tracks(mediaType: .audio)
        if let target = tracks.first(where: { $0.trackID == id }) {
            player.select(track: target)
            selectedAudioTrackId = id
            refreshTracks()
        }
    }

    public func selectSubtitleTrack(id: Int32?) {
        guard let player = coordinator.playerLayer?.player else { return }
        let tracks = player.tracks(mediaType: .subtitle)
        if let targetId = id, let target = tracks.first(where: { $0.trackID == targetId }) {
            player.select(track: target)
            selectedSubtitleTrackId = targetId
            coordinator.subtitleModel.selectedSubtitleInfo?.isEnabled = true
        } else {
            for track in tracks {
                track.isEnabled = false
            }
            selectedSubtitleTrackId = nil
            currentEmbeddedSubtitleText = nil
            coordinator.subtitleModel.selectedSubtitleInfo?.isEnabled = false
        }
        refreshTracks()
    }

    public func refreshTracks() {
        guard let player = coordinator.playerLayer?.player else { return }
        let audio = player.tracks(mediaType: .audio)
        self.availableAudioTracks = audio.map { track in
            let label: String
            if !track.name.isEmpty {
                label = track.name
            } else if let lang = track.language {
                label = lang
            } else {
                label = "Track \(track.trackID)"
            }
            return KSPlayerTrackInfo(
                id: track.trackID,
                name: label,
                language: track.languageCode,
                isEnabled: track.isEnabled
            )
        }
        if let active = audio.first(where: { $0.isEnabled }) {
            self.selectedAudioTrackId = active.trackID
        }

        let subs = player.tracks(mediaType: .subtitle)
        self.availableSubtitleTracks = subs.map { track in
            let label: String
            if !track.name.isEmpty {
                label = track.name
            } else if let lang = track.language {
                label = lang
            } else {
                label = "Subtitle \(track.trackID)"
            }
            return KSPlayerTrackInfo(
                id: track.trackID,
                name: label,
                language: track.languageCode,
                isEnabled: track.isEnabled
            )
        }
        if let activeSub = subs.first(where: { $0.isEnabled }) {
            self.selectedSubtitleTrackId = activeSub.trackID
        }
    }

    // Callbacks from KSVideoPlayer
    public func onPlayTick(current: TimeInterval, total: TimeInterval) {
        if current > 0 && !current.isNaN && !current.isInfinite {
            self.currentTime = current
            if self.isBuffering {
                self.isBuffering = false
            }
        }
        if total > 0 && !total.isNaN && !total.isInfinite {
            self.duration = total
        }

        // Handle pending start seek if restoring playback position
        if let start = pendingStartTime, current < start {
            seek(to: start)
            pendingStartTime = nil
        }

        // Calculate buffer fraction
        if let player = coordinator.playerLayer?.player {
            let playable = player.playableTime
            self.bufferedTime = max(0, playable - current)
            if duration > 0 {
                self.bufferedFraction = min(1.0, max(0.0, playable / duration))
            }
        }

        // Update embedded subtitle text
        if selectedSubtitleTrackId != nil {
            let parts = coordinator.subtitleModel.parts
            let text = parts.compactMap { $0.text?.string }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            self.currentEmbeddedSubtitleText = text.isEmpty ? nil : text
        } else {
            self.currentEmbeddedSubtitleText = nil
        }
    }

    public func onStateChanged(layer: KSPlayerLayer, state: KSPlayerState) {
        switch state {
        case .readyToPlay:
            isBuffering = false
            isPlaying = true
            refreshTracks()
            if let start = pendingStartTime {
                seek(to: start)
                pendingStartTime = nil
            }
        case .buffering:
            if !isPlaying || currentTime == 0 {
                isBuffering = true
            }
        case .bufferFinished:
            isBuffering = false
            isPlaying = true
        case .paused:
            isPlaying = false
        case .playedToTheEnd:
            isPlaying = false
            isBuffering = false
        case .error:
            isBuffering = false
            isPlaying = false
            playbackError = "KSPlayer encountered a stream playback error."
        case .preparing, .initialized:
            isBuffering = true
        }
    }

    public func onFinish(layer: KSPlayerLayer, error: Error?) {
        isPlaying = false
        isBuffering = false
        if let err = error {
            playbackError = err.localizedDescription
        }
    }

    public func reset() {
        coordinator.resetPlayer()
        currentURL = nil
        currentTime = 0
        duration = 0
        bufferedTime = 0
        bufferedFraction = 0
        isPlaying = false
        isBuffering = false
        playbackError = nil
        availableAudioTracks.removeAll()
        availableSubtitleTracks.removeAll()
        currentEmbeddedSubtitleText = nil
    }
}
