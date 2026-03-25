import Foundation
import CBlueLightBridge

/// Wraps the private CoreBrightness framework bridge for Night Shift control.
final class NightShiftManager {
    static let shared = NightShiftManager()

    /// Whether we have overridden (disabled) Night Shift for an excluded app.
    private(set) var isOverriding = false

    /// Whether Night Shift should be restored when focus leaves an excluded app.
    private var shouldRestoreOnFocusChange = false

    private init() {}

    /// Current Night Shift enabled state (manual toggle).
    var isEnabled: Bool {
        CBlueLightBridge.isNightShiftEnabled()
    }

    /// Whether Night Shift is actively warming the display right now.
    var isActive: Bool {
        CBlueLightBridge.isNightShiftActive()
    }

    /// Whether a Night Shift schedule is configured.
    var isScheduled: Bool {
        CBlueLightBridge.isNightShiftScheduled()
    }

    /// Disable Night Shift because an excluded app gained focus.
    /// Only records a restore if Night Shift was actually enabled (manual
    /// toggle or schedule-triggered). A configured schedule alone does not
    /// count — otherwise we'd force-enable Night Shift outside schedule hours.
    func disableForExcludedApp() {
        let wasEnabled = isEnabled
        shouldRestoreOnFocusChange = wasEnabled

        if wasEnabled {
            CBlueLightBridge.setNightShiftEnabled(false)
        }
        isOverriding = true
    }

    /// Re-enable Night Shift if it was enabled before we overrode it.
    func restoreIfNeeded() {
        guard isOverriding else { return }

        if shouldRestoreOnFocusChange {
            CBlueLightBridge.setNightShiftEnabled(true)
        }
        isOverriding = false
        shouldRestoreOnFocusChange = false
    }
}
