import AppKit
import SwiftUI

/// Settings window (420 pt, centered). It sits above the break layer so it can be used during a break.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private var window: NSWindow?

    init(store: SettingsStore) {
        self.store = store
    }

    func show() {
        if let window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.Settings.width, height: Metrics.Settings.width),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.t(.settingsWindowTitle)
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .pausie(.surfaceWindow)
        window.level = WindowLevel.panel
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self

        // A fresh view each time so unsaved stepper values are dropped on Cancel / close.
        let hosting = NSHostingController(rootView: SettingsView(store: store) { [weak self] in self?.close() })
        hosting.sizingOptions = .preferredContentSize
        window.contentViewController = hosting
        window.setContentSize(hosting.view.fittingSize)
        window.center()

        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentViewController = nil
        window = nil
    }
}
