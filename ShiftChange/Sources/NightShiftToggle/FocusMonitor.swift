import Foundation
import AppKit
import Combine

/// Monitors the frontmost application and toggles Night Shift
/// based on the exclude list.
final class FocusMonitor: ObservableObject {
    @Published var currentAppName: String = ""
    @Published var currentBundleID: String = ""
    @Published var nightShiftOverridden: Bool = false

    /// Called when status changes so the menu bar can update.
    var onStatusChange: (() -> Void)?

    private var observer: NSObjectProtocol?
    private weak var excludeList: ExcludeListManager?
    private let nightShift = NightShiftManager.shared

    func start(excludeList: ExcludeListManager) {
        self.excludeList = excludeList

        // Set initial state from current frontmost app
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            currentAppName = frontmost.localizedName ?? ""
            currentBundleID = frontmost.bundleIdentifier ?? ""
        }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    func stop() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
        // Restore Night Shift if we were overriding
        nightShift.restoreIfNeeded()
        nightShiftOverridden = false
    }

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }

        let bundleID = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? ""

        currentAppName = appName
        currentBundleID = bundleID

        guard let excludeList = excludeList else { return }

        if excludeList.contains(bundleID: bundleID) {
            // Excluded app gained focus — disable Night Shift
            nightShift.disableForExcludedApp()
            nightShiftOverridden = true
        } else {
            // Non-excluded app gained focus — restore Night Shift if needed
            nightShift.restoreIfNeeded()
            nightShiftOverridden = false
        }

        onStatusChange?()
    }

    deinit {
        stop()
    }
}
