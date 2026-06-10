import Foundation
@testable import ShiftChange

/// In-memory stand-in for the CoreBrightness bridge.
/// Records every setEnabled call so tests can assert that Night Shift is
/// never toggled when it shouldn't be (see the regression checklist in CLAUDE.md).
final class FakeBlueLightClient: BlueLightControlling {
    var enabled = false
    var active = false
    var scheduled = false
    private(set) var setEnabledCalls: [Bool] = []

    var isEnabled: Bool { enabled }
    var isActive: Bool { active }
    var isScheduled: Bool { scheduled }

    func setEnabled(_ enabled: Bool) {
        setEnabledCalls.append(enabled)
        self.enabled = enabled
    }
}

/// Creates an isolated UserDefaults suite for a test, so tests never touch
/// the real preferences domain.
func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "ShiftChangeTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
