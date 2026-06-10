import XCTest
@testable import ShiftChange

final class FocusMonitorTests: XCTestCase {
    private var client: FakeBlueLightClient!
    private var manager: NightShiftManager!
    private var monitor: FocusMonitor!
    private var excludeList: ExcludeListManager!

    override func setUp() {
        super.setUp()
        client = FakeBlueLightClient()
        manager = NightShiftManager(client: client)
        monitor = FocusMonitor(nightShift: manager)
        excludeList = ExcludeListManager(defaults: makeIsolatedDefaults())
        excludeList.add(bundleID: "com.adobe.Photoshop")
        monitor.start(excludeList: excludeList)
    }

    override func tearDown() {
        monitor.stop()
        super.tearDown()
    }

    func testExcludedAppFocusDisablesNightShift() {
        client.enabled = true

        monitor.handleFocusChange(bundleID: "com.adobe.Photoshop", appName: "Photoshop")

        XCTAssertTrue(monitor.nightShiftOverridden)
        XCTAssertEqual(monitor.currentAppName, "Photoshop")
        XCTAssertEqual(monitor.currentBundleID, "com.adobe.Photoshop")
        XCTAssertEqual(client.setEnabledCalls, [false])
    }

    func testLeavingExcludedAppRestoresNightShift() {
        client.enabled = true

        monitor.handleFocusChange(bundleID: "com.adobe.Photoshop", appName: "Photoshop")
        monitor.handleFocusChange(bundleID: "com.apple.finder", appName: "Finder")

        XCTAssertFalse(monitor.nightShiftOverridden)
        XCTAssertEqual(client.setEnabledCalls, [false, true])
        XCTAssertTrue(client.enabled)
    }

    func testNonExcludedAppFocusIsNoOp() {
        client.enabled = true

        monitor.handleFocusChange(bundleID: "com.apple.finder", appName: "Finder")

        XCTAssertFalse(monitor.nightShiftOverridden)
        XCTAssertEqual(client.setEnabledCalls, [])
    }

    func testStatusChangeCallbackFiresOnFocusChange() {
        var callbackCount = 0
        monitor.onStatusChange = { callbackCount += 1 }

        monitor.handleFocusChange(bundleID: "com.adobe.Photoshop", appName: "Photoshop")
        monitor.handleFocusChange(bundleID: "com.apple.finder", appName: "Finder")

        XCTAssertEqual(callbackCount, 2)
    }

    func testStopRestoresNightShiftWhileOverriding() {
        client.enabled = true

        monitor.handleFocusChange(bundleID: "com.adobe.Photoshop", appName: "Photoshop")
        monitor.stop()

        XCTAssertEqual(client.setEnabledCalls, [false, true])
        XCTAssertTrue(client.enabled, "Quitting while overriding must restore Night Shift")
        XCTAssertFalse(monitor.nightShiftOverridden)
    }
}
