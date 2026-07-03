import XCTest
@testable import ShiftChange

/// Unit tests for the Night Shift override state machine.
/// These mirror the manual regression checklist in CLAUDE.md.
final class NightShiftManagerTests: XCTestCase {
    private var client: FakeBlueLightClient!
    private var manager: NightShiftManager!

    override func setUp() {
        super.setUp()
        client = FakeBlueLightClient()
        manager = NightShiftManager(client: client)
    }

    // Excluded app focused while Night Shift IS warming (after sunset)
    // → disable; leaving → restore.
    func testDisablesAndRestoresWhenNightShiftWasEnabled() {
        client.enabled = true

        manager.disableForExcludedApp()
        XCTAssertEqual(client.setEnabledCalls, [false])
        XCTAssertTrue(manager.isOverriding)
        XCTAssertFalse(client.enabled)

        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [false, true])
        XCTAssertFalse(manager.isOverriding)
        XCTAssertTrue(client.enabled)
    }

    // Excluded app focused while Night Shift is NOT warming (before sunset,
    // schedule configured) → nothing changes in either direction.
    // "Turn On Until Sunrise" must NOT get toggled.
    func testDoesNotTouchNightShiftWhenNotEnabledDespiteSchedule() {
        client.enabled = false
        client.scheduled = true
        client.active = true

        manager.disableForExcludedApp()
        XCTAssertEqual(client.setEnabledCalls, [])
        XCTAssertTrue(manager.isOverriding)

        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [], "Restore must not force-enable Night Shift outside schedule hours")
        XCTAssertFalse(manager.isOverriding)
    }

    // Excluded app focused with Night Shift off and no schedule → no-op.
    func testDoesNothingWhenNightShiftOffAndUnscheduled() {
        manager.disableForExcludedApp()
        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [])
    }

    // Regression: switching excluded app A → excluded app B → normal app
    // must still restore Night Shift. The second disableForExcludedApp call
    // must not clobber the pending restore by re-reading the (now false)
    // enabled state.
    func testSwitchingBetweenExcludedAppsPreservesRestore() {
        client.enabled = true

        manager.disableForExcludedApp() // app A
        manager.disableForExcludedApp() // app B
        XCTAssertEqual(client.setEnabledCalls, [false], "Should only disable once")

        manager.restoreIfNeeded() // back to a normal app
        XCTAssertEqual(client.setEnabledCalls, [false, true])
        XCTAssertTrue(client.enabled, "Night Shift must be restored after leaving the second excluded app")
    }

    // restoreIfNeeded when we never overrode → no-op.
    func testRestoreIsNoOpWhenNotOverriding() {
        client.enabled = true
        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [])
    }

    // Double restore must not enable twice.
    func testDoubleRestoreOnlyEnablesOnce() {
        client.enabled = true
        manager.disableForExcludedApp()
        manager.restoreIfNeeded()
        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [false, true])
    }

    // A no-op override cycle must not poison a later real one
    // (e.g. sunset happens between the two cycles).
    func testFreshCycleAfterNoOpCycleWorks() {
        manager.disableForExcludedApp()
        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [])

        client.enabled = true
        manager.disableForExcludedApp()
        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [false, true])
    }

    // MARK: - Global toggle (menu bar)

    // Toggling globally with no override active goes straight to the client —
    // same as the System Settings toggle.
    func testGlobalToggleOffWhileNotOverriding() {
        client.enabled = true
        manager.setGlobalEnabled(false)
        XCTAssertEqual(client.setEnabledCalls, [false])
        XCTAssertFalse(manager.effectiveEnabled)
    }

    // Turning Night Shift ON from the menu while an excluded app has focus:
    // the display must stay unshifted; the ON state applies on focus leave.
    func testGlobalToggleOnWhileOverridingOnlyChangesRestoreIntent() {
        client.enabled = false
        client.scheduled = true
        manager.disableForExcludedApp()
        XCTAssertEqual(client.setEnabledCalls, [])
        XCTAssertFalse(manager.effectiveEnabled)

        manager.setGlobalEnabled(true)
        XCTAssertEqual(client.setEnabledCalls, [], "Display must stay unshifted while an excluded app has focus")
        XCTAssertTrue(manager.effectiveEnabled)

        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [true])
        XCTAssertTrue(client.enabled)
    }

    // Turning Night Shift OFF from the menu while overriding cancels the
    // pending restore.
    func testGlobalToggleOffWhileOverridingCancelsRestore() {
        client.enabled = true
        manager.disableForExcludedApp()
        XCTAssertEqual(client.setEnabledCalls, [false])

        manager.setGlobalEnabled(false)
        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [false], "Restore must not re-enable after a global off")
        XCTAssertFalse(client.enabled)
    }

    // MARK: - External status changes (schedule triggers, System Settings)

    // Sunset fires while an excluded app is focused → Night Shift is
    // immediately re-disabled; leaving the excluded app then enables it.
    func testScheduleFiringWhileOverridingIsReDisabledAndRestoredLater() {
        var changeCount = 0
        manager.startObservingStatusChanges { changeCount += 1 }

        client.enabled = false
        client.scheduled = true
        manager.disableForExcludedApp()
        XCTAssertEqual(client.setEnabledCalls, [])

        // Sunset: the schedule enables Night Shift externally
        client.enabled = true
        client.fireStatusChange()
        XCTAssertEqual(client.setEnabledCalls, [false], "External enable must be immediately re-disabled")
        XCTAssertFalse(client.enabled, "Display must stay unshifted")
        XCTAssertTrue(manager.effectiveEnabled, "Restore intent must fold in the schedule's ON")
        XCTAssertGreaterThan(changeCount, 0)

        manager.restoreIfNeeded()
        XCTAssertEqual(client.setEnabledCalls, [false, true], "Night Shift should come on after leaving the excluded app")
        XCTAssertTrue(client.enabled)
    }

    // External changes with no override active only refresh the UI.
    func testExternalChangeWhileNotOverridingOnlyNotifies() {
        var changeCount = 0
        manager.startObservingStatusChanges { changeCount += 1 }

        client.enabled = true
        client.fireStatusChange()
        XCTAssertEqual(client.setEnabledCalls, [])
        XCTAssertEqual(changeCount, 1)
    }
}
