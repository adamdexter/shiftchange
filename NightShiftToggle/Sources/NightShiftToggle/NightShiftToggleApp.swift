import SwiftUI

@main
struct NightShiftToggleApp: App {
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
