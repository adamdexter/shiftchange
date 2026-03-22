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
    /// Scans /Applications and ~/Applications for .app bundles.
    static func findAll() -> [AppInfo] {
        var apps: [AppInfo] = []
        var seenBundleIDs = Set<String>()

        let searchPaths = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications",
        ]

        let fileManager = FileManager.default

        for basePath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: basePath),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }

                // Don't recurse into .app bundles
                enumerator.skipDescendants()

                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier else { continue }

                guard !seenBundleIDs.contains(bundleID) else { continue }
                seenBundleIDs.insert(bundleID)

                let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                apps.append(AppInfo(name: name, bundleID: bundleID, bundleURL: url))
            }
        }

        return apps.sorted()
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
