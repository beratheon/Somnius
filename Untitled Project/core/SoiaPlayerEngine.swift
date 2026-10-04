import Foundation
import AppKit
import Combine
import SwiftUI

typealias mpv_create_fn = @convention(c) () -> UnsafeMutableRawPointer?
typealias mpv_initialize_fn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
typealias mpv_set_option_string_fn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32
typealias mpv_command_string_fn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Int32
typealias mpv_command_fn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32
typealias mpv_get_property_string_fn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?
typealias mpv_set_property_string_fn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32
typealias mpv_free_fn = @convention(c) (UnsafeMutableRawPointer?) -> Void
typealias mpv_destroy_fn = @convention(c) (UnsafeMutableRawPointer?) -> Void

class SoiaPlayerEngine: ObservableObject {
    private var libHandle: UnsafeMutableRawPointer? = nil

    private var mpv_create: mpv_create_fn?
    private var mpv_initialize: mpv_initialize_fn?
    private var mpv_set_option_string: mpv_set_option_string_fn?
    private var mpv_command_string: mpv_command_string_fn?
    private var mpv_command: mpv_command_fn?
    private var mpv_get_property_string: mpv_get_property_string_fn?
    private var mpv_set_property_string: mpv_set_property_string_fn?
    private var mpv_free: mpv_free_fn?
    private var mpv_destroy: mpv_destroy_fn?

    private(set) var mpvHandle: UnsafeMutableRawPointer? = nil
    @Published var isLoaded: Bool = false
    @Published var isPlaying: Bool = false
    @Published var currentURLString: String = ""

    static let shared = SoiaPlayerEngine()

    init() {
        loadLibMPV()
    }

    private func loadLibMPV() {
        let possiblePaths = [
            "/Applications/IINA.app/Contents/Frameworks/libmpv.2.dylib",
            "/opt/homebrew/lib/libmpv.dylib",
            "/usr/local/lib/libmpv.dylib"
        ]

        for path in possiblePaths {
            if let handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL) {
                self.libHandle = handle
                bindFunctions(handle)
                self.isLoaded = true
                print("[SoiaEngine] Successfully initialized Soia high-performance video engine from \(path)")
                break
            }
        }
    }

    private func bindFunctions(_ handle: UnsafeMutableRawPointer) {
        func loadSym<T>(_ name: String) -> T? {
            guard let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: T.self)
        }

        mpv_create = loadSym("mpv_create")
        mpv_initialize = loadSym("mpv_initialize")
        mpv_set_option_string = loadSym("mpv_set_option_string")
        mpv_command_string = loadSym("mpv_command_string")
        mpv_command = loadSym("mpv_command")
        mpv_get_property_string = loadSym("mpv_get_property_string")
        mpv_set_property_string = loadSym("mpv_set_property_string")
        mpv_free = loadSym("mpv_free")
        mpv_destroy = loadSym("mpv_destroy")
    }

    func attachToView(_ nsView: NSView, urlString: String) {
        guard isLoaded, let create = mpv_create, let initMPV = mpv_initialize, let setOpt = mpv_set_option_string, let cmdStr = mpv_command_string else {
            print("[SoiaEngine] libmpv dynamic library unavailable.")
            return
        }

        if mpvHandle != nil {
            destroy()
        }

        guard let mpv = create() else { return }
        self.mpvHandle = mpv
        self.currentURLString = urlString

        // Soia Engine Hardware Acceleration & Dolby Vision / HDR Pipeline
        setOpt(mpv, "vo", "gpu")
        setOpt(mpv, "gpu-api", "auto")
        setOpt(mpv, "hwdec", "videotoolbox")
        setOpt(mpv, "target-colorspace-hint", "yes")
        setOpt(mpv, "tone-mapping", "auto")
        setOpt(mpv, "hdr-compute-peak", "auto")
        setOpt(mpv, "demuxer-max-bytes", "150000000") // 150MB buffer
        setOpt(mpv, "demuxer-readahead-secs", "30")
        setOpt(mpv, "keep-open", "yes")

        // Pass Cocoa NSView layer window ID to render inside app window
        nsView.wantsLayer = true
        nsView.layer?.backgroundColor = NSColor.black.cgColor
        let viewLayerPtr = unsafeBitCast(nsView, to: Int.self)
        setOpt(mpv, "wid", "\(viewLayerPtr)")

        let initResult = initMPV(mpv)
        if initResult < 0 {
            print("[SoiaEngine] mpv_initialize error \(initResult)")
            return
        }

        // Play stream
        let cmd = "loadfile \"\(urlString)\""
        cmdStr(mpv, cmd)
        self.isPlaying = true
    }

    func playNewStream(urlString: String) {
        guard let mpv = mpvHandle, let cmdStr = mpv_command_string else { return }
        self.currentURLString = urlString
        let cmd = "loadfile \"\(urlString)\""
        cmdStr(mpv, cmd)
        self.isPlaying = true
    }

    func getPropertyString(_ name: String) -> String? {
        guard let mpv = mpvHandle, let getProp = mpv_get_property_string, let freeMpv = mpv_free else { return nil }
        guard let cStr = getProp(mpv, name) else { return nil }
        let str = String(cString: cStr)
        freeMpv(cStr)
        return str
    }

    func setPropertyString(_ name: String, value: String) {
        guard let mpv = mpvHandle, let setProp = mpv_set_property_string else { return }
        _ = setProp(mpv, name, value)
    }

    func getTimePos() -> Double {
        guard let str = getPropertyString("time-pos") else { return 0 }
        return Double(str) ?? 0
    }

    func getDuration() -> Double {
        guard let str = getPropertyString("duration") else { return 0 }
        return Double(str) ?? 0
    }

    func getCacheDuration() -> Double {
        guard let str = getPropertyString("demuxer-cache-duration") else { return 0 }
        return Double(str) ?? 0
    }

    func seekTo(_ seconds: Double) {
        setPropertyString("time-pos", value: "\(seconds)")
    }

    func seekRelative(_ seconds: Double) {
        guard let mpv = mpvHandle, let cmdStr = mpv_command_string else { return }
        cmdStr(mpv, "seek \(seconds) relative")
    }

    func setPause(_ paused: Bool) {
        setPropertyString("pause", value: paused ? "yes" : "no")
        isPlaying = !paused
    }

    func togglePlayPause() {
        guard let mpv = mpvHandle, let cmdStr = mpv_command_string else { return }
        cmdStr(mpv, "cycle pause")
        isPlaying.toggle()
    }

    func setVolume(_ volume: Double) {
        guard let mpv = mpvHandle, let cmdStr = mpv_command_string else { return }
        cmdStr(mpv, "set volume \(Int(volume * 100))")
    }

    func setSpeed(_ speed: Double) {
        setPropertyString("speed", value: String(format: "%.2f", speed))
    }

    func cycleAudioTrack() {
        guard let mpv = mpvHandle, let cmdStr = mpv_command_string else { return }
        cmdStr(mpv, "cycle aid")
    }

    func cycleSubtitleTrack() {
        guard let mpv = mpvHandle, let cmdStr = mpv_command_string else { return }
        cmdStr(mpv, "cycle sid")
    }

    func addSubtitle(urlOrPath: String) {
        guard let mpv = mpvHandle, let cmdStr = mpv_command_string else { return }
        cmdStr(mpv, "sub-add \"\(urlOrPath)\"")
    }

    func destroy() {
        if let mpv = mpvHandle, let destroyMPV = mpv_destroy {
            destroyMPV(mpv)
            mpvHandle = nil
        }
        isPlaying = false
        currentURLString = ""
    }

    deinit {
        destroy()
        if let handle = libHandle {
            dlclose(handle)
        }
    }
}

struct SoiaEmbeddedPlayerView: NSViewRepresentable {
    let urlString: String
    let engine: SoiaPlayerEngine

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        DispatchQueue.main.async {
            engine.attachToView(view, urlString: urlString)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if engine.currentURLString != urlString {
            DispatchQueue.main.async {
                engine.playNewStream(urlString: urlString)
            }
        }
    }
}
