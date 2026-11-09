import SwiftUI

@main
struct PausieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Pausie lives only in the menu bar; windows are managed by AppKit controllers.
        SwiftUI.Settings { EmptyView() }
    }
}
