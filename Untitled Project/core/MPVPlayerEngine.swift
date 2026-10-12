import Foundation
import SwiftUI
import AppKit
import QuartzCore
import Combine
import Libmpv

// MARK: - Metal Layer for High-Performance EDR/XDR & MoltenVK
public class MetalLayer: CAMetalLayer {
    // Workaround for MoltenVK setting drawableSize to 1x1 causing flicker
    public override var drawableSize: CGSize {
        get { return super.drawableSize }
        set {
            if Int(newValue.width) > 1 && Int(newValue.height) > 1 {
                super.drawableSize = newValue
            }
        }
    }

    // Activate Apple Extended Dynamic Range (EDR/XDR) asynchronously on the main thread.
    // NEVER use DispatchQueue.main.sync here, as MoltenVK's VO thread calls this while
    // the main thread may be interacting with mpv, causing an instant, fatal deadlock.
    public override var wantsExtendedDynamicRangeContent: Bool {
        get { return super.wantsExtendedDynamicRangeContent }
        set {
            if Thread.isMainThread {
                super.wantsExtendedDynamicRangeContent = newValue
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.wantsExtendedDynamicRangeContent = newValue
                }
            }
        }
    }
}

// MARK: - Video Scaling & Aspect Modes
public enum VideoScaleMode: String, CaseIterable, Identifiable {
    case fit = "Fit to Screen"
    case fill = "Fill Screen (Zoom)"
    case stretch = "Stretch to Fill"
    case widescreen16_9 = "16:9 Widescreen"
    case cinema21_9 = "21:9 Cinema"
    case classic4_3 = "4:3 Classic"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .fit: return "arrow.down.right.and.arrow.up.left"
        case .fill: return "arrow.up.left.and.arrow.down.right"
        case .stretch: return "rectangle.expand.vertical"
        case .widescreen16_9: return "rectangle.ratio.16.to.9"
        case .cinema21_9: return "film"
        case .classic4_3: return "rectangle.ratio.4.to.3"
        }
    }
}

// MARK: - MPV Video View
public class MPVVideoView: NSView {
    public let metalLayer = MetalLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        metalLayer.frame = bounds
        metalLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = NSColor.black.cgColor
        layer = metalLayer
    }

    public override func makeBackingLayer() -> CALayer {
        return metalLayer
    }

    public override func layout() {
        super.layout()
        updateLayerGeometry()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLayerGeometry()
        if let win = window {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didEnterFullScreenNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didExitFullScreenNotification, object: nil)

            NotificationCenter.default.addObserver(self, selector: #selector(windowGeometryChanged), name: NSWindow.didResizeNotification, object: win)
            NotificationCenter.default.addObserver(self, selector: #selector(windowGeometryChanged), name: NSWindow.didEnterFullScreenNotification, object: win)
            NotificationCenter.default.addObserver(self, selector: #selector(windowGeometryChanged), name: NSWindow.didExitFullScreenNotification, object: win)
        }
    }

    @objc private func windowGeometryChanged() {
        updateLayerGeometry()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateLayerGeometry()
    }

    public override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        updateLayerGeometry()
    }

    public func updateLayerGeometry() {
        metalLayer.frame = bounds
        let scale = window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Track Info Struct
public struct MPVTrackInfo: Identifiable, Hashable {
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

public typealias KSPlayerTrackInfo = MPVTrackInfo

public enum MPVPlayerState {
    case readyToPlay
    case buffering
    case bufferFinished
    case paused
    case error
}

public typealias KSPlayerState = MPVPlayerState

// MARK: - MPV Player Engine
@MainActor
public class MPVPlayerEngine: ObservableObject {
    public static let shared = MPVPlayerEngine()

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
    @Published public var currentScaleMode: VideoScaleMode = .fit
    @Published public var isPipActive: Bool = false
    @Published public var playbackError: String? = nil
    @Published public var currentURL: URL? = nil

    @Published public var availableAudioTracks: [MPVTrackInfo] = []
    @Published public var selectedAudioTrackId: Int32? = nil

    @Published public var availableSubtitleTracks: [MPVTrackInfo] = []
    @Published public var selectedSubtitleTrackId: Int32? = nil
    @Published public var currentEmbeddedSubtitleText: String? = nil
    @Published public var currentEmbeddedSubtitleImage: NSImage? = nil

    @Published public var audioDelay: Double = 0.0
    @Published public var palSpeedupEnabled: Bool = false
    @Published public var isExternalAudioInjected: Bool = false
    @Published public var activeIMDbID: String? = nil

    @Published public var hdrAvailable: Bool = false
    @Published public var edrRange: Double = 1.0

    private var mpv: OpaquePointer? = nil
    public let videoView = MPVVideoView()
    public var metalLayer: MetalLayer { videoView.metalLayer }
    private let eventQueue = DispatchQueue(label: "com.somnius.mpv.events", qos: .userInitiated)
    private var pendingURL: URL? = nil
    private var pendingStartTime: Double? = nil
    private var pendingIMDbID: String? = nil
    private var pendingIsExternalAudio: Bool = false
    private var lastObservedTime: Double = 0

    public init() {
    }

    // MARK: - Setup & Initialization
    public func attachView(_ view: MPVVideoView? = nil) {
        ensureEngineInitialized()

        if let pending = self.pendingURL, self.mpv != nil {
            print("🚀 [MPVPlayerEngine] Executing pending stream load: \(pending.absoluteString)")
            loadStreamNow(url: pending, startTime: self.pendingStartTime ?? 0)
        }
    }

    private func ensureEngineInitialized() {
        if mpv != nil { return }

        guard let handle = mpv_create() else {
            print("❌ [MPVPlayerEngine] Failed to create mpv context")
            return
        }

        // On macOS Cocoa with vo=gpu-next (MoltenVK), wid expects a retained CAMetalLayer* pointer!
        // We pass the permanently owned metalLayer pointer.
        var layerInt: Int64 = Int64(Int(bitPattern: Unmanaged.passUnretained(videoView.metalLayer).toOpaque()))

        let widStatus = mpv_set_option(handle, "wid", MPV_FORMAT_INT64, &layerInt)
        if widStatus < 0 {
            print("❌ [MPVPlayerEngine] wid set_option failed: \(String(cString: mpv_error_string(widStatus)))")
        }
        mpv_set_option_string(handle, "vo", "gpu-next")
        mpv_set_option_string(handle, "hwdec", "videotoolbox")

        // Apple Silicon XDR/EDR HDR Passthrough & Tone Mapping
        mpv_set_option_string(handle, "target-colorspace-hint", "yes")
        mpv_set_option_string(handle, "tone-mapping", "auto")
        mpv_set_option_string(handle, "target-peak", "auto")

        // Subtitles & Audio
        mpv_set_option_string(handle, "subs-match-os-language", "yes")
        mpv_set_option_string(handle, "subs-fallback", "yes")
        mpv_set_option_string(handle, "sub-auto", "fuzzy")
        mpv_set_option_string(handle, "sub-font", "SF Pro Text")
        mpv_set_option_string(handle, "sub-font-size", "48")
        mpv_set_option_string(handle, "sub-color", "1.0/1.0/1.0/1.0")
        mpv_set_option_string(handle, "sub-border-size", "2.5")
        mpv_set_option_string(handle, "audio-pitch-correction", "yes")

        // Network Streaming Buffering & Fast Start (Smooth playback on 4K Remux torrent streams)
        let bufferSeconds = max(60, Int(Config.bufferAheadSeconds * 2))
        mpv_set_option_string(handle, "cache", "yes")
        mpv_set_option_string(handle, "cache-secs", "\(bufferSeconds)")
        mpv_set_option_string(handle, "cache-pause", "yes")
        mpv_set_option_string(handle, "cache-pause-initial", "no")
        mpv_set_option_string(handle, "cache-pause-wait", "2")
        mpv_set_option_string(handle, "force-seekable", "yes")
        mpv_set_option_string(handle, "demuxer-max-bytes", "256MiB")
        mpv_set_option_string(handle, "demuxer-max-back-bytes", "128MiB")
        mpv_set_option_string(handle, "demuxer-readahead-secs", "\(bufferSeconds)")
        mpv_set_option_string(handle, "network-timeout", "15")
        mpv_set_option_string(handle, "keep-open", "yes")
        mpv_set_option_string(handle, "ytdl", "no")
        mpv_set_option_string(handle, "input-media-keys", "yes")

        #if DEBUG
        mpv_request_log_messages(handle, "info")
        #else
        mpv_request_log_messages(handle, "no")
        #endif

        let initStatus = mpv_initialize(handle)
        if initStatus < 0 {
            print("❌ [MPVPlayerEngine] mpv_initialize error: \(String(cString: mpv_error_string(initStatus)))")
            mpv_terminate_destroy(handle)
            return
        }

        self.mpv = handle
        print("✅ [MPVPlayerEngine] mpv initialized successfully with handle: \(handle)")

        // Observe Properties
        mpv_observe_property(handle, 1, "time-pos", MPV_FORMAT_DOUBLE)
        mpv_observe_property(handle, 2, "duration", MPV_FORMAT_DOUBLE)
        mpv_observe_property(handle, 3, "paused-for-cache", MPV_FORMAT_FLAG)
        mpv_observe_property(handle, 4, "pause", MPV_FORMAT_FLAG)
        mpv_observe_property(handle, 5, "video-params/sig-peak", MPV_FORMAT_DOUBLE)
        mpv_observe_property(handle, 6, "demuxer-cache-duration", MPV_FORMAT_DOUBLE)
        mpv_observe_property(handle, 7, "sub-text", MPV_FORMAT_STRING)
        mpv_observe_property(handle, 8, "track-list/count", MPV_FORMAT_INT64)

        // Wakeup Callback
        let selfPointer = Unmanaged.passRetained(self).toOpaque()
        mpv_set_wakeup_callback(handle, { ctx in
            guard let ctx = ctx else { return }
            let engine = Unmanaged<MPVPlayerEngine>.fromOpaque(ctx).takeUnretainedValue()
            engine.processEvents()
        }, selfPointer)

        // Screen Parameter Notification for EDR changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkScreenEDRSupport()
        }
    }

    // MARK: - Screen EDR Detection
    private func checkScreenEDRSupport() {
        guard let screen = NSScreen.main else { return }
        let maxEDR = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
        self.edrRange = Double(maxEDR)
        if maxEDR > 1.0 {
            self.metalLayer.wantsExtendedDynamicRangeContent = true
        }
    }

    // MARK: - Event Loop
    private func processEvents() {
        eventQueue.async { [weak self] in
            guard let self = self else { return }
            while true {
                guard let handle = self.mpv else { break }
                let eventPtr = mpv_wait_event(handle, 0)
                guard let event = eventPtr?.pointee else { break }
                if event.event_id == MPV_EVENT_NONE { break }

                switch event.event_id {
                case MPV_EVENT_PROPERTY_CHANGE:
                    let prop = UnsafePointer<mpv_event_property>(OpaquePointer(event.data))?.pointee
                    if let prop = prop {
                        let name = String(cString: prop.name)
                        self.handlePropertyChange(name: name, format: prop.format, data: prop.data)
                    }

                case MPV_EVENT_FILE_LOADED:
                    print("✅ [MPVPlayerEngine] MPV_EVENT_FILE_LOADED")
                    DispatchQueue.main.async {
                        self.isBuffering = false
                        self.isPlaying = true
                        self.refreshTracks()
                        if let start = self.pendingStartTime, start > 0 {
                            self.seek(to: start)
                            self.pendingStartTime = nil
                        }
                    }

                case MPV_EVENT_PLAYBACK_RESTART:
                    print("▶️ [MPVPlayerEngine] MPV_EVENT_PLAYBACK_RESTART")
                    DispatchQueue.main.async {
                        self.isBuffering = false
                        self.isPlaying = true
                    }

                case MPV_EVENT_END_FILE:
                    print("⏹️ [MPVPlayerEngine] MPV_EVENT_END_FILE")
                    if let endFile = UnsafePointer<mpv_event_end_file>(OpaquePointer(event.data))?.pointee {
                        if endFile.reason == MPV_END_FILE_REASON_ERROR {
                            let errStr = String(cString: mpv_error_string(endFile.error))
                            print("❌ [MPVPlayerEngine] File ended with error: \(errStr)")
                            DispatchQueue.main.async {
                                self.isPlaying = false
                                self.isBuffering = false
                                self.playbackError = "Media stream playback failed (\(errStr))."
                            }
                            break
                        }
                    }
                    DispatchQueue.main.async {
                        self.isPlaying = false
                        self.isBuffering = false
                    }

                case MPV_EVENT_SHUTDOWN:
                    DispatchQueue.main.async {
                        self.isPlaying = false
                        self.isBuffering = false
                        self.mpv = nil
                    }
                    break

                case MPV_EVENT_LOG_MESSAGE:
                    if let log = UnsafePointer<mpv_event_log_message>(OpaquePointer(event.data))?.pointee {
                        let prefix = String(cString: log.prefix)
                        let text = String(cString: log.text)
                        print("🪵 [mpv:\(prefix)] \(text)", terminator: "")
                    }

                default:
                    break
                }
            }
        }
    }

    private func handlePropertyChange(name: String, format: mpv_format, data: UnsafeMutableRawPointer?) {
        guard let data = data else { return }

        switch name {
        case "time-pos":
            let time = data.assumingMemoryBound(to: Double.self).pointee
            guard time >= 0 && !time.isNaN && !time.isInfinite else { return }
            let diff = abs(time - self.lastObservedTime)
            if diff >= 0.25 || self.currentTime == 0 {
                self.lastObservedTime = time
                DispatchQueue.main.async {
                    self.currentTime = time
                    self.isBuffering = false
                    self.isPlaying = true
                    if self.duration > 0 {
                        self.bufferedFraction = min(1.0, max(0.0, (time + self.bufferedTime) / self.duration))
                    }
                }
            }

        case "duration":
            let dur = data.assumingMemoryBound(to: Double.self).pointee
            guard dur > 0 && !dur.isNaN && !dur.isInfinite else { return }
            DispatchQueue.main.async {
                self.duration = dur
            }

        case "paused-for-cache":
            let buffering = data.assumingMemoryBound(to: Int32.self).pointee != 0
            DispatchQueue.main.async {
                self.isBuffering = buffering
            }

        case "pause":
            let paused = data.assumingMemoryBound(to: Int32.self).pointee != 0
            DispatchQueue.main.async {
                self.isPlaying = !paused
            }

        case "demuxer-cache-duration":
            let cached = data.assumingMemoryBound(to: Double.self).pointee
            guard cached >= 0 && !cached.isNaN else { return }
            DispatchQueue.main.async {
                self.bufferedTime = cached
            }

        case "video-params/sig-peak":
            let peak = data.assumingMemoryBound(to: Double.self).pointee
            DispatchQueue.main.async {
                let maxEDR = NSScreen.main?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1.0
                let isHDR = peak > 1.0
                self.hdrAvailable = isHDR && maxEDR > 1.0
                if self.hdrAvailable {
                    self.metalLayer.wantsExtendedDynamicRangeContent = true
                }
            }

        case "sub-text":
            if let cstr = data.assumingMemoryBound(to: UnsafePointer<CChar>?.self).pointee {
                let text = String(cString: cstr).trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self.currentEmbeddedSubtitleText = text.isEmpty ? nil : text
                }
            } else {
                DispatchQueue.main.async {
                    self.currentEmbeddedSubtitleText = nil
                }
            }

        case "track-list/count":
            DispatchQueue.main.async {
                self.refreshTracks()
            }

        default:
            break
        }
    }

    // MARK: - Playback Control
    public func loadStream(url: URL, startTime: Double = 0, imdbID: String? = nil, isExternalAudio: Bool = false) {
        print("🎬 [MPVPlayerEngine] loadStream requested for: \(url.absoluteString), startTime: \(startTime)")
        self.currentURL = url
        self.playbackError = nil
        self.isBuffering = true
        self.currentTime = startTime
        self.pendingURL = url
        self.pendingStartTime = startTime > 0 ? startTime : nil
        self.activeIMDbID = imdbID
        self.isExternalAudioInjected = isExternalAudio

        if let imdb = imdbID, !imdb.isEmpty {
            self.audioDelay = Self.savedLipSyncOffset(for: imdb)
        } else {
            self.audioDelay = 0.0
        }
        self.palSpeedupEnabled = Config.enablePALSpeedupCorrection

        ensureEngineInitialized()
        guard let _ = mpv else {
            print("⏳ [MPVPlayerEngine] View not yet attached; queuing stream for attachment.")
            return
        }

        loadStreamNow(url: url, startTime: startTime)
    }

    private func loadStreamNow(url: URL, startTime: Double) {
        var args = ["loadfile", url.absoluteString, "replace"]
        if startTime > 0 {
            args.append("-1")
            args.append("start=\(Int(startTime))")
        }
        executeCommand(args)
        applyAudioFilters()
        setScaleMode(currentScaleMode)
    }

    public func play() {
        guard let handle = mpv else { return }
        var flag: Int32 = 0
        mpv_set_property(handle, "pause", MPV_FORMAT_FLAG, &flag)
        isPlaying = true
    }

    public func pause() {
        guard let handle = mpv else { return }
        var flag: Int32 = 1
        mpv_set_property(handle, "pause", MPV_FORMAT_FLAG, &flag)
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
        executeCommand(["seek", "\(target)", "absolute"])
    }

    public func seekRelative(_ seconds: Double) {
        seek(to: currentTime + seconds)
    }

    public func setRate(_ rate: Double) {
        playbackRate = rate
        guard let handle = mpv else { return }
        var r = rate
        mpv_set_property(handle, "speed", MPV_FORMAT_DOUBLE, &r)
    }

    public func setVolume(_ vol: Double) {
        let clamped = max(0.0, min(1.0, vol))
        volume = clamped
        guard let handle = mpv else { return }
        var v = clamped * 100.0
        mpv_set_property(handle, "volume", MPV_FORMAT_DOUBLE, &v)
        if clamped > 0 && isMuted {
            toggleMute()
        }
    }

    public func toggleMute() {
        isMuted.toggle()
        guard let handle = mpv else { return }
        var m: Int32 = isMuted ? 1 : 0
        mpv_set_property(handle, "mute", MPV_FORMAT_FLAG, &m)
    }

    public func setScaleMode(_ mode: VideoScaleMode) {
        currentScaleMode = mode
        guard let handle = mpv else { return }

        switch mode {
        case .fit:
            mpv_set_property_string(handle, "panscan", "0.0")
            mpv_set_property_string(handle, "keepaspect", "yes")
            mpv_set_property_string(handle, "video-aspect-override", "-1")
            mpv_set_property_string(handle, "video-zoom", "0")
            isAspectFill = false

        case .fill:
            // Crop letterbox/pillarbox black bars to fill 100% of the screen/window seamlessly
            mpv_set_property_string(handle, "panscan", "1.0")
            mpv_set_property_string(handle, "keepaspect", "yes")
            mpv_set_property_string(handle, "video-aspect-override", "-1")
            mpv_set_property_string(handle, "video-zoom", "0")
            isAspectFill = true

        case .stretch:
            // Disregard native aspect ratio and stretch to window bounds
            mpv_set_property_string(handle, "panscan", "0.0")
            mpv_set_property_string(handle, "keepaspect", "no")
            mpv_set_property_string(handle, "video-aspect-override", "-1")
            mpv_set_property_string(handle, "video-zoom", "0")
            isAspectFill = true

        case .widescreen16_9:
            mpv_set_property_string(handle, "panscan", "0.0")
            mpv_set_property_string(handle, "keepaspect", "yes")
            mpv_set_property_string(handle, "video-aspect-override", "16:9")
            mpv_set_property_string(handle, "video-zoom", "0")
            isAspectFill = false

        case .cinema21_9:
            mpv_set_property_string(handle, "panscan", "0.0")
            mpv_set_property_string(handle, "keepaspect", "yes")
            mpv_set_property_string(handle, "video-aspect-override", "2.39:1")
            mpv_set_property_string(handle, "video-zoom", "0")
            isAspectFill = false

        case .classic4_3:
            mpv_set_property_string(handle, "panscan", "0.0")
            mpv_set_property_string(handle, "keepaspect", "yes")
            mpv_set_property_string(handle, "video-aspect-override", "4:3")
            mpv_set_property_string(handle, "video-zoom", "0")
            isAspectFill = false
        }
    }

    public func cycleScaleMode() -> VideoScaleMode {
        let all = VideoScaleMode.allCases
        let nextIndex = (all.firstIndex(of: currentScaleMode).map { ($0 + 1) % all.count }) ?? 0
        let next = all[nextIndex]
        setScaleMode(next)
        return next
    }

    public func toggleAspect() {
        _ = cycleScaleMode()
    }

    public func togglePiP() {
        isPipActive.toggle()
    }

    // MARK: - Track Selection
    public func selectAudioTrack(id: Int32) {
        guard let handle = mpv else { return }
        mpv_set_property_string(handle, "aid", "\(id)")
        selectedAudioTrackId = id
        refreshTracks()
    }

    public func selectSubtitleTrack(id: Int32?) {
        guard let handle = mpv else { return }
        if let targetId = id {
            mpv_set_property_string(handle, "sid", "\(targetId)")
            mpv_set_property_string(handle, "sub-visibility", "yes")
            selectedSubtitleTrackId = targetId
        } else {
            mpv_set_property_string(handle, "sid", "no")
            mpv_set_property_string(handle, "sub-visibility", "no")
            selectedSubtitleTrackId = nil
            currentEmbeddedSubtitleText = nil
            currentEmbeddedSubtitleImage = nil
        }
        refreshTracks()
    }

    public func refreshTracks() {
        guard let handle = mpv else { return }
        eventQueue.async { [weak self] in
            guard let self = self else { return }
            var count: Int64 = 0
            guard mpv_get_property(handle, "track-list/count", MPV_FORMAT_INT64, &count) >= 0 else { return }

            var audio: [MPVTrackInfo] = []
            var subs: [MPVTrackInfo] = []
            var activeAudio: Int32? = nil
            var activeSub: Int32? = nil

            for i in 0..<count {
                guard let typeC = mpv_get_property_string(handle, "track-list/\(i)/type") else { continue }
                let type = String(cString: typeC)
                mpv_free(typeC)

                var trackId: Int64 = 0
                mpv_get_property(handle, "track-list/\(i)/id", MPV_FORMAT_INT64, &trackId)
                let id32 = Int32(trackId)

                var isSel: Int32 = 0
                mpv_get_property(handle, "track-list/\(i)/selected", MPV_FORMAT_FLAG, &isSel)
                let isEnabled = isSel != 0

                var label = "Track \(id32)"
                if let titleC = mpv_get_property_string(handle, "track-list/\(i)/title") {
                    let t = String(cString: titleC)
                    if !t.isEmpty { label = t }
                    mpv_free(titleC)
                } else if let langC = mpv_get_property_string(handle, "track-list/\(i)/lang") {
                    let l = String(cString: langC)
                    if !l.isEmpty { label = l.uppercased() }
                    mpv_free(langC)
                }

                var langStr: String? = nil
                if let langC = mpv_get_property_string(handle, "track-list/\(i)/lang") {
                    langStr = String(cString: langC)
                    mpv_free(langC)
                }

                let track = MPVTrackInfo(id: id32, name: label, language: langStr, isEnabled: isEnabled)
                if type == "audio" {
                    audio.append(track)
                    if isEnabled { activeAudio = id32 }
                } else if type == "sub" {
                    subs.append(track)
                    if isEnabled { activeSub = id32 }
                }
            }

            DispatchQueue.main.async {
                self.availableAudioTracks = audio
                self.selectedAudioTrackId = activeAudio
                self.availableSubtitleTracks = subs
                self.selectedSubtitleTrackId = activeSub
            }
        }
    }

    // MARK: - Audio Filters & Lip Sync
    public func setAudioDelay(_ delay: Double) {
        let clamped = max(-3.0, min(3.0, (round(delay * 20.0) / 20.0)))
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
        guard let handle = mpv else { return }
        var delay = audioDelay
        mpv_set_property(handle, "audio-delay", MPV_FORMAT_DOUBLE, &delay)

        if palSpeedupEnabled {
            var speed = 0.95904
            mpv_set_property(handle, "speed", MPV_FORMAT_DOUBLE, &speed)
        }
    }

    public static func savedLipSyncOffset(for imdbID: String) -> Double {
        return UserDefaults.standard.double(forKey: "Somnius_LipSync_\(imdbID)")
    }

    public static func saveLipSyncOffset(_ offset: Double, for imdbID: String) {
        UserDefaults.standard.set(offset, forKey: "Somnius_LipSync_\(imdbID)")
    }

    // MARK: - Helper Commands
    @discardableResult
    public func executeCommand(_ args: [String]) -> Int32 {
        guard let handle = mpv else {
            print("⚠️ [MPVPlayerEngine] executeCommand dropped because mpv is nil: \(args.joined(separator: " "))")
            return -1
        }
        var cArgs: [UnsafePointer<CChar>?] = args.map { UnsafePointer<CChar>(strdup($0)) }
        cArgs.append(nil)
        defer {
            for ptr in cArgs where ptr != nil {
                free(UnsafeMutablePointer(mutating: ptr!))
            }
        }
        let status = mpv_command(handle, &cArgs)
        if status < 0 {
            print("❌ [MPVPlayerEngine] mpv_command '\(args.joined(separator: " "))' failed (\(status)): \(String(cString: mpv_error_string(status)))")
        } else {
            print("✅ [MPVPlayerEngine] mpv_command '\(args.joined(separator: " "))' succeeded")
        }
        return status
    }

    // MARK: - Shutdown & Teardown
    public func reset() {
        if let _ = mpv {
            executeCommand(["stop"])
        }
        currentURL = nil
        pendingURL = nil
        pendingStartTime = nil
        pendingIMDbID = nil
        pendingIsExternalAudio = false
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
        currentEmbeddedSubtitleImage = nil
    }

    public func shutdown() {
        reset()
        if let handle = mpv {
            mpv_set_wakeup_callback(handle, nil, nil)
            mpv_terminate_destroy(handle)
            self.mpv = nil
        }
    }

    deinit {
        if let handle = mpv {
            mpv_set_wakeup_callback(handle, nil, nil)
            mpv_terminate_destroy(handle)
        }
    }
}

public typealias KSPlayerEngine = MPVPlayerEngine
