import XCTest
@testable import ShiftChange

final class InstalledAppsFinderTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftChangeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    /// Creates a minimal fake .app bundle (Contents/Info.plist only).
    @discardableResult
    private func makeFakeApp(named name: String, bundleID: String, in dir: URL? = nil) throws -> URL {
        let appURL = (dir ?? tempDir).appendingPathComponent("\(name).app")
        let contents = appURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": name,
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return appURL
    }

    func testAppInfoFromValidBundle() throws {
        let url = try makeFakeApp(named: "FakeEditor", bundleID: "net.adamdexter.tests.fakeeditor")

        let info = try XCTUnwrap(InstalledAppsFinder.appInfo(from: url))
        XCTAssertEqual(info.name, "FakeEditor")
        XCTAssertEqual(info.bundleID, "net.adamdexter.tests.fakeeditor")
        XCTAssertEqual(info.id, info.bundleID)
    }

    func testAppInfoRejectsNonAppURL() {
        XCTAssertNil(InstalledAppsFinder.appInfo(from: tempDir))
    }

    func testScanFindsAppsAndDeduplicatesByBundleID() throws {
        try makeFakeApp(named: "Alpha", bundleID: "net.adamdexter.tests.alpha")
        try makeFakeApp(named: "Beta", bundleID: "net.adamdexter.tests.beta")

        // Same bundle ID in a subfolder — must be deduplicated
        let sub = tempDir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try makeFakeApp(named: "AlphaCopy", bundleID: "net.adamdexter.tests.alpha", in: sub)

        let apps = InstalledAppsFinder.scan(paths: [tempDir.path])
        XCTAssertEqual(apps.map(\.bundleID).sorted(), [
            "net.adamdexter.tests.alpha",
            "net.adamdexter.tests.beta",
        ])
    }

    func testScanSkipsMissingPaths() {
        let apps = InstalledAppsFinder.scan(paths: ["/nonexistent/path/\(UUID().uuidString)"])
        XCTAssertTrue(apps.isEmpty)
    }

    func testScanResultsAreSortedCaseInsensitively() throws {
        try makeFakeApp(named: "zeta", bundleID: "net.adamdexter.tests.zeta")
        try makeFakeApp(named: "Alpha", bundleID: "net.adamdexter.tests.alpha2")

        let apps = InstalledAppsFinder.scan(paths: [tempDir.path])
        XCTAssertEqual(apps.map(\.name), ["Alpha", "zeta"])
    }

    func testDisplayNameFallsBackToBundleID() {
        let apps = [
            AppInfo(name: "Alpha", bundleID: "net.adamdexter.tests.alpha", bundleURL: tempDir),
        ]
        XCTAssertEqual(InstalledAppsFinder.displayName(for: "net.adamdexter.tests.alpha", from: apps), "Alpha")
        XCTAssertEqual(InstalledAppsFinder.displayName(for: "com.unknown.app", from: apps), "com.unknown.app")
    }
}
