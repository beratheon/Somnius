import Foundation
#if os(macOS)
import IOKit.pwr_mgt
#endif

/// Thread-safe manager responsible for preventing macOS idle display sleep,
/// screen dimming, and system screensavers while media is actively playing.
public final class DisplaySleepManager: @unchecked Sendable {
    public static let shared = DisplaySleepManager()

    #if os(macOS)
    private var displayAssertionID: IOPMAssertionID = 0
    private var systemAssertionID: IOPMAssertionID = 0
    private var isPreventingSleep: Bool = false
    private var processActivity: NSObjectProtocol?
    private var heartbeatTimer: Timer?
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
                options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled, .userInitiated],
                reason: reason
            )
        }

        // 2. IOKit Display Sleep Assertion: blocks screensaver & display sleep
        let resDisplay = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &displayAssertionID
        )

        // 3. IOKit System Sleep Assertion: prevents system idle sleep
        let resSystem = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &systemAssertionID
        )

        if resDisplay == kIOReturnSuccess || resSystem == kIOReturnSuccess {
            isPreventingSleep = true
            print("🛡️ [DisplaySleepManager] Display sleep & screensaver disabled (displayID: \(displayAssertionID), systemID: \(systemAssertionID))")
        } else {
            print("⚠️ [DisplaySleepManager] Failed to create power assertions: display=\(resDisplay), system=\(resSystem)")
        }

        // 4. Recurring 30s heartbeat: declares user activity to macOS WindowServer so screensaver timer never elapses
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer?.invalidate()
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                var activityAssertion: IOPMAssertionID = 0
                IOPMAssertionDeclareUserActivity(
                    "Somnius Active Playback Keepalive" as CFString,
                    kIOPMUserActiveLocal,
                    &activityAssertion
                )
            }
        }
        #endif
    }

    /// Re-enables normal macOS display sleep, dimming, and screensaver.
    /// Safe to call repeatedly; cleanly releases active assertions and activities.
    public func enableDisplaySleep() {
        #if os(macOS)
        lock.lock()
        defer { lock.unlock() }

        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer?.invalidate()
            self?.heartbeatTimer = nil
        }

        if let activity = processActivity {
            ProcessInfo.processInfo.endActivity(activity)
            processActivity = nil
        }

        if isPreventingSleep {
            if displayAssertionID != 0 {
                _ = IOPMAssertionRelease(displayAssertionID)
                displayAssertionID = 0
            }
            if systemAssertionID != 0 {
                _ = IOPMAssertionRelease(systemAssertionID)
                systemAssertionID = 0
            }
            isPreventingSleep = false
            print("💤 [DisplaySleepManager] Display sleep & screensaver re-enabled cleanly")
        }
        #endif
    }
}
