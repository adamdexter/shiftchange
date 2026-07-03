import Foundation
import Combine

/// Manages the list of apps that should have Night Shift disabled when in focus.
/// Also manages additional application search folders.
/// Persists both lists to UserDefaults.
final class ExcludeListManager: ObservableObject {
    private static let excludeKey = "excludedAppBundleIDs"
    private static let foldersKey = "additionalAppFolders"

    private let defaults: UserDefaults

    @Published var excludedBundleIDs: [String] = [] {
        didSet {
            defaults.set(excludedBundleIDs, forKey: Self.excludeKey)
        }
    }

    /// Additional folders to scan for .app bundles (e.g. external drives).
    @Published var additionalAppFolders: [String] = [] {
        didSet {
            defaults.set(additionalAppFolders, forKey: Self.foldersKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.excludedBundleIDs = defaults.stringArray(forKey: Self.excludeKey) ?? []
        self.additionalAppFolders = defaults.stringArray(forKey: Self.foldersKey) ?? []
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
