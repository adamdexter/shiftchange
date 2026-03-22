import Foundation
import AppKit

/// Represents an installed application.
struct AppInfo: Identifiable, Hashable, Comparable {
    var id: String { bundleID }
    let name: String
    let bundleID: String
    let bundleURL: URL

    static func < (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

/// Discovers installed applications on the system.
enum InstalledAppsFinder {
    /// Default search paths that are always scanned.
    static let defaultSearchPaths = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications",
    ]

    /// Scans default paths + any additional custom paths for .app bundles.
    static func findAll(extraPaths: [String] = []) -> [AppInfo] {
        var apps: [AppInfo] = []
        var seenBundleIDs = Set<String>()

        let allPaths = defaultSearchPaths + extraPaths
        let fileManager = FileManager.default

        for basePath in allPaths {
            guard fileManager.fileExists(atPath: basePath) else { continue }

            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: basePath),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }

                // Don't recurse into .app bundles
                enumerator.skipDescendants()

                if let app = appInfo(from: url), !seenBundleIDs.contains(app.bundleID) {
                    seenBundleIDs.insert(app.bundleID)
                    apps.append(app)
                }
            }
        }

        return apps.sorted()
    }

    /// Creates an AppInfo from a .app bundle URL, or nil if invalid.
    static func appInfo(from url: URL) -> AppInfo? {
        guard url.pathExtension == "app",
              let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return nil }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        return AppInfo(name: name, bundleID: bundleID, bundleURL: url)
    }

    /// Gets the icon for an app.
    static func icon(for app: AppInfo) -> NSImage {
        NSWorkspace.shared.icon(forFile: app.bundleURL.path)
    }

    /// Resolves a display name for a bundle ID from currently known apps.
    static func displayName(for bundleID: String, from apps: [AppInfo]) -> String {
        apps.first(where: { $0.bundleID == bundleID })?.name ?? bundleID
    }
}
