import AppKit

// Pure AppKit entry point — avoids SwiftUI's App lifecycle
// overriding our main menu and terminate handling.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
