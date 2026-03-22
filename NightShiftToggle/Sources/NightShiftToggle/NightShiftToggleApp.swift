import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Make the app a regular app so it appears in Cmd+Tab and can become key window
        NSApplication.shared.setActivationPolicy(.regular)
        // Set the app icon with ~10% padding to match macOS icon guidelines
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
        // Activate and bring to front
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@main
struct NightShiftToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var excludeList = ExcludeListManager()
    @StateObject private var focusMonitor = FocusMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(excludeList)
                .environmentObject(focusMonitor)
                .onAppear {
                    focusMonitor.start(excludeList: excludeList)
                }
        }
    }
}
