import Foundation
import Combine

/// Manages the list of apps that should have Night Shift disabled when in focus.
/// Also manages additional application search folders.
/// Persists both lists to UserDefaults.
final class ExcludeListManager: ObservableObject {
    private static let excludeKey = "excludedAppBundleIDs"
    private static let foldersKey = "additionalAppFolders"

    @Published var excludedBundleIDs: [String] = [] {
        didSet {
            UserDefaults.standard.set(excludedBundleIDs, forKey: Self.excludeKey)
        }
    }

    /// Additional folders to scan for .app bundles (e.g. external drives).
    @Published var additionalAppFolders: [String] = [] {
        didSet {
            UserDefaults.standard.set(additionalAppFolders, forKey: Self.foldersKey)
        }
    }

    init() {
        self.excludedBundleIDs = UserDefaults.standard.stringArray(forKey: Self.excludeKey) ?? []
        self.additionalAppFolders = UserDefaults.standard.stringArray(forKey: Self.foldersKey) ?? []
    }

    func add(bundleID: String) {
        guard !excludedBundleIDs.contains(bundleID) else { return }
        excludedBundleIDs.append(bundleID)
    }

    func remove(bundleID: String) {
        excludedBundleIDs.removeAll { $0 == bundleID }
    }

    func contains(bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }

    func addFolder(_ path: String) {
        guard !additionalAppFolders.contains(path) else { return }
        additionalAppFolders.append(path)
    }

    func removeFolder(_ path: String) {
        additionalAppFolders.removeAll { $0 == path }
    }
}
