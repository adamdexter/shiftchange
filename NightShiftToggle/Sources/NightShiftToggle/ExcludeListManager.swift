import Foundation
import Combine

/// Manages the list of apps that should have Night Shift disabled when in focus.
/// Persists the list to UserDefaults.
final class ExcludeListManager: ObservableObject {
    private static let storageKey = "excludedAppBundleIDs"

    @Published var excludedBundleIDs: [String] = [] {
        didSet {
            UserDefaults.standard.set(excludedBundleIDs, forKey: Self.storageKey)
        }
    }

    init() {
        self.excludedBundleIDs = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
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
}
