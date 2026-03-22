import SwiftUI
import AppKit
import ServiceManagement

@main
struct NightShiftToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window opened from menu bar
        Settings {
            ContentView()
                .environmentObject(appDelegate.excludeList)
                .environmentObject(appDelegate.focusMonitor)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let excludeList = ExcludeListManager()
    let focusMonitor = FocusMonitor()

    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!

    // Menu items that need updating
    private var statusMenuItem: NSMenuItem!
    private var activeAppMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory (menu bar only, no Dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)

        // Set the app icon (for Settings window title bar, About, etc.)
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

    // MARK: - Actions

    @objc private func openSettings() {
        // Show the app temporarily so the settings window can appear
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Open the Settings window
        if #available(macOS 14.0, *) {
            NSApplication.shared.mainMenu?.items
                .first(where: { $0.submenu?.items.contains(where: { $0.action == #selector(NSApplication.showSettingsWindow) }) != nil })?
                .submenu?.items
                .first(where: { $0.action == #selector(NSApplication.showSettingsWindow) })?
                .target?.perform(#selector(NSApplication.showSettingsWindow))
                ?? NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }

        // Hide from Dock again when all windows close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.watchForWindowClose()
        }
    }

    private func watchForWindowClose() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let visibleWindows = NSApplication.shared.windows.filter { $0.isVisible && $0.level == .normal }
                if visibleWindows.isEmpty {
                    NSApplication.shared.setActivationPolicy(.accessory)
                }
            }
        }
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
