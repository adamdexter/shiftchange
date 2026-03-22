import SwiftUI
import AppKit
import ServiceManagement

@main
struct NightShiftToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We manage the settings window manually via AppDelegate,
        // but SwiftUI requires at least one Scene.
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let excludeList = ExcludeListManager()
    let focusMonitor = FocusMonitor()

    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var settingsWindow: NSWindow?

    // Menu items that need updating
    private var statusMenuItem: NSMenuItem!
    private var activeAppMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!

    private static let hasLaunchedKey = "hasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory (menu bar only, no Dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)

        // Set the app icon (for window title bar, About, etc.)
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            let size: CGFloat = 1024
            let padding: CGFloat = size * 0.10
            let paddedImage = NSImage(size: NSSize(width: size, height: size))
            paddedImage.lockFocus()
            let drawRect = NSRect(
                x: padding, y: padding,
                width: size - padding * 2, height: size - padding * 2
            )
            icon.draw(in: drawRect)
            paddedImage.unlockFocus()
            NSApplication.shared.applicationIconImage = paddedImage
        }

        // Start monitoring
        focusMonitor.start(excludeList: excludeList)
        focusMonitor.onStatusChange = { [weak self] in
            self?.updateMenuStatus()
        }

        // Set up menu bar
        setupStatusItem()

        // Show settings on first launch OR if exclude list is empty
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: Self.hasLaunchedKey)
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: Self.hasLaunchedKey)
        }
        if isFirstLaunch || excludeList.excludedBundleIDs.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.openSettings()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If the settings window is visible, intercept quit to offer minimize option
        if let window = settingsWindow, window.isVisible {
            let alert = NSAlert()
            alert.messageText = "Quit ShiftChange?"
            alert.informativeText = "Did you mean to terminate and quit this app or just minimize to the menu bar?"
            alert.addButton(withTitle: "Minimize to Menu Bar")
            alert.addButton(withTitle: "Quit")
            alert.alertStyle = .informational

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Minimize: just close the window and keep running
                window.close()
                return .terminateCancel
            } else {
                // Quit: actually terminate
                focusMonitor.stop()
                return .terminateNow
            }
        }

        // No window open — quit directly (e.g. from menu bar Quit)
        focusMonitor.stop()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusMonitor.stop()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "moon.circle", accessibilityDescription: "ShiftChange")
            image?.isTemplate = true
            button.image = image
        }

        statusMenu = NSMenu()

        // Status line
        statusMenuItem = NSMenuItem(title: statusTitle(), action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenu.addItem(statusMenuItem)

        // Active app line
        activeAppMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        activeAppMenuItem.isEnabled = false
        statusMenu.addItem(activeAppMenuItem)

        statusMenu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        // Launch at Login
        launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem.target = self
        launchAtLoginMenuItem.state = isLaunchAtLoginEnabled() ? .on : .off
        statusMenu.addItem(launchAtLoginMenuItem)

        statusMenu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit ShiftChange", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)

        statusItem.menu = statusMenu

        updateMenuStatus()
    }

    private func statusTitle() -> String {
        if focusMonitor.nightShiftOverridden {
            return "Night Shift: Disabled (excluded app)"
        } else {
            return "Night Shift: Following schedule"
        }
    }

    private func updateMenuStatus() {
        guard let statusMenuItem, let activeAppMenuItem, let button = statusItem?.button else { return }

        statusMenuItem.title = statusTitle()

        if !focusMonitor.currentAppName.isEmpty {
            activeAppMenuItem.title = "Active: \(focusMonitor.currentAppName)"
            activeAppMenuItem.isHidden = false
        } else {
            activeAppMenuItem.isHidden = true
        }

        // Update menu bar icon based on state
        let symbolName = focusMonitor.nightShiftOverridden ? "moon.circle.fill" : "moon.circle"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ShiftChange")
        image?.isTemplate = true
        button.image = image
    }

    // MARK: - Settings Window

    @objc func openSettings() {
        // If window already exists, just bring it forward
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let contentView = ContentView()
            .environmentObject(excludeList)
            .environmentObject(focusMonitor)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ShiftChange"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.settingsWindow = window

        // Show in Dock while window is open
        NSApplication.shared.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func toggleLaunchAtLogin() {
        let newState = !isLaunchAtLoginEnabled()
        setLaunchAtLogin(enabled: newState)
        launchAtLoginMenuItem.state = newState ? .on : .off
    }

    @objc private func quitApp() {
        focusMonitor.stop()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Launch at Login

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
}

// MARK: - Window Delegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Hide from Dock when settings window closes
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}
