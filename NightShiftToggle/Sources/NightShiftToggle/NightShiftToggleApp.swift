import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Make the app a regular app so it appears in Cmd+Tab and can become key window
        NSApplication.shared.setActivationPolicy(.regular)
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
