import Foundation
import CBlueLightBridge

/// Abstraction over the Night Shift control surface so the override
/// state machine can be unit tested without the private framework.
protocol BlueLightControlling {
    /// Night Shift is currently applying a color shift (manual toggle or schedule-triggered).
    var isEnabled: Bool { get }
    /// The Night Shift feature is running/monitoring (true whenever a schedule
    /// is configured, even outside warming hours). NOT "display is warmed".
    var isActive: Bool { get }
    /// A Night Shift schedule is configured (sun-based or custom).
    var isScheduled: Bool { get }
    func setEnabled(_ enabled: Bool)
    /// Registers a handler invoked (on the main queue in production) whenever
    /// Night Shift status changes — including changes we didn't make
    /// (schedule triggers, System Settings, Control Center). Pass nil to remove.
    func setStatusChangeHandler(_ handler: (() -> Void)?)
}

/// Production implementation backed by the CoreBrightness bridge.
struct CoreBrightnessBlueLightClient: BlueLightControlling {
    var isEnabled: Bool { CBlueLightBridge.isNightShiftEnabled() }
    var isActive: Bool { CBlueLightBridge.isNightShiftActive() }
    var isScheduled: Bool { CBlueLightBridge.isNightShiftScheduled() }
    func setEnabled(_ enabled: Bool) { CBlueLightBridge.setNightShiftEnabled(enabled) }
    func setStatusChangeHandler(_ handler: (() -> Void)?) {
        CBlueLightBridge.setStatusChangeHandler(handler)
    }
}

/// Wraps the private CoreBrightness framework bridge for Night Shift control.
final class NightShiftManager {
    static let shared = NightShiftManager()

    private let client: BlueLightControlling

    /// Whether we have overridden (disabled) Night Shift for an excluded app.
    private(set) var isOverriding = false

    /// Whether Night Shift should be restored when focus leaves an excluded app.
    private var shouldRestoreOnFocusChange = false

    init(client: BlueLightControlling = CoreBrightnessBlueLightClient()) {
        self.client = client
    }

    /// Current Night Shift enabled state (manual toggle).
    var isEnabled: Bool {
        client.isEnabled
    }

    /// Whether the Night Shift feature is active (schedule configured / monitoring).
    var isActive: Bool {
        client.isActive
    }

    /// Whether a Night Shift schedule is configured.
    var isScheduled: Bool {
        client.isScheduled
    }

    /// The Night Shift state as the user intends it, seen through any active
    /// per-app override: while overriding this is the state we'd restore to
    /// on focus change; otherwise it's the live state.
    var effectiveEnabled: Bool {
        isOverriding ? shouldRestoreOnFocusChange : isEnabled
    }

    /// Globally turn Night Shift on or off — same effect as the System
    /// Settings toggle ("Turn Off Until Tomorrow" / "Turn On Until Sunset");
    /// the OS handles the until-next-schedule-trigger part itself.
    ///
    /// If an excluded app currently has focus, the per-app override wins:
    /// the display stays unshifted and only the restore intent changes, so
    /// ShiftChange keeps working as configured.
    func setGlobalEnabled(_ enabled: Bool) {
        if isOverriding {
            shouldRestoreOnFocusChange = enabled
        } else {
            client.setEnabled(enabled)
        }
    }

    /// Starts observing Night Shift status changes from outside our control
    /// (schedule triggers, System Settings, Control Center). While an
    /// excluded app has focus, an external enable is immediately re-disabled
    /// and folded into the restore intent, so the display never warms mid-
    /// session in a color-critical app. `onChange` fires after each change
    /// so the UI can refresh.
    func startObservingStatusChanges(onChange: @escaping () -> Void) {
        client.setStatusChangeHandler { [weak self] in
            self?.handleExternalStatusChange()
            onChange()
        }
    }

    /// If the schedule (or the user) turns Night Shift on while we're
    /// overriding for an excluded app, keep the display unshifted and restore
    /// to on when focus leaves. Our own re-disable triggers another
    /// notification, which no-ops here because isEnabled is then false.
    private func handleExternalStatusChange() {
        guard isOverriding, isEnabled else { return }
        shouldRestoreOnFocusChange = true
        client.setEnabled(false)
    }

    /// Disable Night Shift because an excluded app gained focus.
    /// Only records a restore if Night Shift was actually enabled (manual
    /// toggle or schedule-triggered). A configured schedule alone does not
    /// count — otherwise we'd force-enable Night Shift outside schedule hours.
    func disableForExcludedApp() {
        // Already overriding (excluded app → excluded app switch): keep the
        // original restore decision. Re-reading `isEnabled` here would see
        // the false we just set and lose the pending restore.
        guard !isOverriding else { return }

        // Update state BEFORE the setEnabled side effect: the framework's
        // status notification may re-enter handleExternalStatusChange, which
        // must observe the final state.
        let wasEnabled = isEnabled
        shouldRestoreOnFocusChange = wasEnabled
        isOverriding = true

        if wasEnabled {
            client.setEnabled(false)
        }
    }

    /// Re-enable Night Shift if it was enabled before we overrode it.
    func restoreIfNeeded() {
        guard isOverriding else { return }

        // Update state BEFORE the setEnabled side effect — see
        // disableForExcludedApp for why.
        let shouldRestore = shouldRestoreOnFocusChange
        isOverriding = false
        shouldRestoreOnFocusChange = false

        if shouldRestore {
            client.setEnabled(true)
        }
    }
}
