import XCTest
@testable import ShiftChange

final class ExcludeListManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: ExcludeListManager!

    override func setUp() {
        super.setUp()
        defaults = makeIsolatedDefaults()
        manager = ExcludeListManager(defaults: defaults)
    }

    func testAddAndContains() {
        manager.add(bundleID: "com.adobe.Photoshop")
        XCTAssertTrue(manager.contains(bundleID: "com.adobe.Photoshop"))
        XCTAssertFalse(manager.contains(bundleID: "com.apple.finder"))
    }

    func testDuplicateAddIsIgnored() {
        manager.add(bundleID: "com.adobe.Photoshop")
        manager.add(bundleID: "com.adobe.Photoshop")
        XCTAssertEqual(manager.excludedBundleIDs, ["com.adobe.Photoshop"])
    }

    func testRemove() {
        manager.add(bundleID: "com.adobe.Photoshop")
        manager.add(bundleID: "com.blackmagic-design.DaVinciResolve")
        manager.remove(bundleID: "com.adobe.Photoshop")
        XCTAssertEqual(manager.excludedBundleIDs, ["com.blackmagic-design.DaVinciResolve"])
    }

    func testPersistsToDefaults() {
        manager.add(bundleID: "com.adobe.Photoshop")
        XCTAssertEqual(defaults.stringArray(forKey: "excludedAppBundleIDs"), ["com.adobe.Photoshop"])
    }

    func testLoadsFromDefaultsOnInit() {
        defaults.set(["com.adobe.Photoshop"], forKey: "excludedAppBundleIDs")
        defaults.set(["/Volumes/Apps"], forKey: "additionalAppFolders")

        let reloaded = ExcludeListManager(defaults: defaults)
        XCTAssertEqual(reloaded.excludedBundleIDs, ["com.adobe.Photoshop"])
        XCTAssertEqual(reloaded.additionalAppFolders, ["/Volumes/Apps"])
    }

    func testAddAndRemoveFolder() {
        manager.addFolder("/Volumes/Apps")
        manager.addFolder("/Volumes/Apps") // duplicate ignored
        XCTAssertEqual(manager.additionalAppFolders, ["/Volumes/Apps"])

        manager.removeFolder("/Volumes/Apps")
        XCTAssertTrue(manager.additionalAppFolders.isEmpty)
        XCTAssertEqual(defaults.stringArray(forKey: "additionalAppFolders"), [])
    }
}
