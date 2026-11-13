import AppKit
import SwiftUI

/// The break layer: one borderless panel per display, covering everything below the menu bar so
/// "Skip break…" stays reachable (rule 6). The card is shown on the main display; others are only dimmed.
@MainActor
final class BreakOverlayController {
    private let session: SessionController
    private let settings: SettingsStore
    private var panels: [OverlayPanel] = []
    /// Opens Settings (above the break layer) from the break-over sound chip.
    var onOpenSettings: () -> Void = {}

    init(session: SessionController, settings: SettingsStore) {
        self.session = session
        self.settings = settings
    }

    var isVisible: Bool { !panels.isEmpty }

    func show() {
        if panels.isEmpty { buildPanels() }
        for panel in panels { panel.orderFrontRegardless() }
        focus()
    }

    func hide() {
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
        }
        panels.removeAll()
    }

    /// Makes the card panel key so the editor, Return and Esc work.
    func focus() {
        panels.first { $0.showsCard }?.makeKeyAndOrderFront(nil)
    }

    /// Displays were added or removed: rebuild for every screen.
    func rebuildIfVisible() {
        guard isVisible else { return }
        hide()
        show()
    }

    private func buildPanels() {
        let screens = NSScreen.screens
        let main = screens.first
        panels = screens.map { screen in
            let showsCard = screen == main
            let panel = OverlayPanel(
                contentRect: Self.frameBelowMenuBar(screen),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.showsCard = showsCard
            panel.level = WindowLevel.breakOverlay
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isMovable = false
            let view = BreakOverlayView(session: session, settings: settings, showsCard: showsCard) { [weak self] in
                self?.onOpenSettings()
            }
            panel.contentView = NSHostingView(rootView: view)
            panel.setFrame(Self.frameBelowMenuBar(screen), display: false)
            return panel
        }
    }

    /// The whole display except the menu bar strip.
    static func frameBelowMenuBar(_ screen: NSScreen) -> NSRect {
        var frame = screen.frame
        let menuBarHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        frame.size.height -= menuBarHeight
        return frame
    }
}

final class OverlayPanel: NSPanel {
    var showsCard = false

    /// The required-note editor needs keyboard input.
    override var canBecomeKey: Bool { showsCard }

    /// The break can't be dismissed with Esc or ⌘W.
    override func cancelOperation(_ sender: Any?) {}
    override func performClose(_ sender: Any?) {}
}
