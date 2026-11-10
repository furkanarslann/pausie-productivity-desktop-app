import AppKit

/// A panel whose top edge stays put when its SwiftUI content grows or shrinks
/// (e.g. a new todo row), so a window pinned below the menu bar doesn't drift.
class TopAnchoredPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect
        if isVisible, rect.size != frame.size, rect.origin == frame.origin {
            rect.origin.y = frame.maxY - rect.height
        }
        super.setFrame(rect, display: flag)
    }

    /// Sizes the panel to its content and centers it in the main screen's visible area (below the menu bar).
    func centerOnMainScreen(contentSize: NSSize) {
        setContentSize(contentSize)
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(
            x: (visible.midX - frame.width / 2).rounded(),
            y: (visible.midY - frame.height / 2).rounded()
        ))
    }

    /// Sizes the panel to its content, then places its top-right corner `inset` away from the
    /// top-right of the main screen's visible area.
    func pinToTopRight(contentSize: NSSize, inset: CGSize) {
        setContentSize(contentSize)
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(
            x: visible.maxX - frame.width - inset.width,
            y: visible.maxY - frame.height - inset.height
        ))
    }
}
