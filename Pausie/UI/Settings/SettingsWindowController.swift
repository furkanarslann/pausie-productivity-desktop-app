import AppKit
import SwiftUI

/// Settings window (420 pt, centered). It sits above the break layer so it can be used during a break.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private let player: ChimePlayer
    private var window: NSWindow?

    init(store: SettingsStore, player: ChimePlayer) {
        self.store = store
        self.player = player
    }

    var frame: NSRect? { window?.frame }

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
        let view = SettingsView(store: store, player: player) { [weak self] in self?.close() }
        let (_, size) = window.hostSizedContent(view, width: Metrics.Settings.width)
        window.setContentSize(size)
        window.center()

        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        player.stopPreview()
        window?.contentViewController = nil
        window = nil
    }
}
