import Foundation
#if os(macOS)
import IOKit.pwr_mgt
#endif

/// Thread-safe manager responsible for preventing macOS idle display sleep,
/// screen dimming, and system screensavers while media is actively playing.
public final class DisplaySleepManager: @unchecked Sendable {
    public static let shared = DisplaySleepManager()

    #if os(macOS)
    private var assertionID: IOPMAssertionID = 0
    private var isPreventingSleep: Bool = false
    private var processActivity: NSObjectProtocol?
    private let lock = NSLock()
    #endif

    private init() {}

    /// Disables display sleep, screen dimming, and screensaver.
    /// Safe to call repeatedly; subsequent calls are no-ops while already active.
    public func disableDisplaySleep(reason: String = "Somnius Video Playback") {
        #if os(macOS)
        lock.lock()
        defer { lock.unlock() }

        guard !isPreventingSleep else { return }

        // 1. ProcessInfo Activity: informs App Nap / WindowServer of active user-initiated playback
        if processActivity == nil {
            processActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated],
                reason: reason
            )
        }

        // 2. IOKit Power Management Display Sleep Assertion: strictly blocks screensaver & display sleep
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isPreventingSleep = true
            print("🛡️ [DisplaySleepManager] Display sleep & screensaver disabled (assertion ID: \(assertionID))")
        } else {
            print("⚠️ [DisplaySleepManager] Failed to create display sleep assertion: \(result)")
        }
        #endif
    }

    /// Re-enables normal macOS display sleep, dimming, and screensaver.
    /// Safe to call repeatedly; cleanly releases active assertions and activities.
    public func enableDisplaySleep() {
        #if os(macOS)
        lock.lock()
        defer { lock.unlock() }

        if let activity = processActivity {
            ProcessInfo.processInfo.endActivity(activity)
            processActivity = nil
        }

        if isPreventingSleep {
            let result = IOPMAssertionRelease(assertionID)
            assertionID = 0
            isPreventingSleep = false
            print("💤 [DisplaySleepManager] Display sleep & screensaver re-enabled (release result: \(result))")
        }
        #endif
    }
}
