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
}

/// Production implementation backed by the CoreBrightness bridge.
struct CoreBrightnessBlueLightClient: BlueLightControlling {
    var isEnabled: Bool { CBlueLightBridge.isNightShiftEnabled() }
    var isActive: Bool { CBlueLightBridge.isNightShiftActive() }
    var isScheduled: Bool { CBlueLightBridge.isNightShiftScheduled() }
    func setEnabled(_ enabled: Bool) { CBlueLightBridge.setNightShiftEnabled(enabled) }
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

    /// Disable Night Shift because an excluded app gained focus.
    /// Only records a restore if Night Shift was actually enabled (manual
    /// toggle or schedule-triggered). A configured schedule alone does not
    /// count — otherwise we'd force-enable Night Shift outside schedule hours.
    func disableForExcludedApp() {
        // Already overriding (excluded app → excluded app switch): keep the
        // original restore decision. Re-reading `isEnabled` here would see
        // the false we just set and lose the pending restore.
        guard !isOverriding else { return }

        let wasEnabled = isEnabled
        shouldRestoreOnFocusChange = wasEnabled

        if wasEnabled {
            client.setEnabled(false)
        }
        isOverriding = true
    }

    /// Re-enable Night Shift if it was enabled before we overrode it.
    func restoreIfNeeded() {
        guard isOverriding else { return }

        if shouldRestoreOnFocusChange {
            client.setEnabled(true)
        }
        isOverriding = false
        shouldRestoreOnFocusChange = false
    }
}
