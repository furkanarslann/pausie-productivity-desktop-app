import AppKit
import SwiftUI

/// Shows the note window: an `NSPanel` centered on the main display (screen 03b) that can be minimized
/// but not closed (rule 4). It opens with the editor focused so the user can type right away.
@MainActor
final class NoteWindowController {
    private let session: SessionController
    private var panel: NotePanel?

    init(session: SessionController) {
        self.session = session
    }

    var isVisible: Bool { panel?.isVisible == true || panel?.isMiniaturized == true }
    var frame: NSRect? { panel?.frame }

    func show(mode: NoteWindowMode) {
        let panel = panel ?? makePanel()
        self.panel = panel
        let (_, size) = panel.hostSizedContent(NoteWindowView(session: session, mode: mode), width: Metrics.NoteWindow.width)
        panel.centerOnMainScreen(contentSize: size)

        if panel.isMiniaturized { panel.deminiaturize(nil) }
        // A non-activating panel takes the keyboard without bringing Pausie (or its menu bar) forward.
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard let panel else { return }
        panel.orderOut(nil)
        panel.contentViewController = nil
        self.panel = nil
    }

    private func makePanel() -> NotePanel {
        let panel = NotePanel(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.NoteWindow.width, height: Metrics.NoteWindow.width),
            styleMask: [.titled, .miniaturizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.t(.noteWindowTitle)
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .pausie(.surfaceWindow)
        panel.isFloatingPanel = true
        panel.level = WindowLevel.panel
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        return panel
    }
}

/// The note panel can't be closed: Esc and ⌘W do nothing.
private final class NotePanel: TopAnchoredPanel {
    override func cancelOperation(_ sender: Any?) {}
    override func performClose(_ sender: Any?) {}
}
