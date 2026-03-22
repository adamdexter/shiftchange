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

    /// Current Night Shift enabled state.
    var isEnabled: Bool {
        CBlueLightBridge.isNightShiftEnabled()
    }

    /// Whether a Night Shift schedule is configured.
    var isScheduled: Bool {
        CBlueLightBridge.isNightShiftScheduled()
    }

    /// Disable Night Shift because an excluded app gained focus.
    /// Records whether to restore it later.
    func disableForExcludedApp() {
        let wasEnabled = isEnabled
        let hasSchedule = isScheduled
        shouldRestoreOnFocusChange = wasEnabled || hasSchedule

        if wasEnabled {
            CBlueLightBridge.setNightShiftEnabled(false)
        }
        isOverriding = true
    }

    /// Re-enable Night Shift if it was on before we overrode it.
    func restoreIfNeeded() {
        guard isOverriding else { return }

        if shouldRestoreOnFocusChange {
            CBlueLightBridge.setNightShiftEnabled(true)
        }
        isOverriding = false
        shouldRestoreOnFocusChange = false
    }
}
