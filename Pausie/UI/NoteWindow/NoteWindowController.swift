import AppKit
import SwiftUI

/// Shows the note window: an `NSPanel` at the top right that can be minimized but not closed (rule 4).
/// In pending mode it appears without stealing focus from the app the user is working in.
@MainActor
final class NoteWindowController {
    private let session: SessionController
    private var panel: NotePanel?

    init(session: SessionController) {
        self.session = session
    }

    var isVisible: Bool { panel?.isVisible == true || panel?.isMiniaturized == true }

    func show(mode: NoteWindowMode) {
        let panel = panel ?? makePanel()
        self.panel = panel
        let hosting = NSHostingController(rootView: NoteWindowView(session: session, mode: mode))
        hosting.sizingOptions = .preferredContentSize
        panel.contentViewController = hosting
        panel.pinToTopRight(contentSize: hosting.view.fittingSize, inset: Metrics.NoteWindow.screenInset)

        if panel.isMiniaturized { panel.deminiaturize(nil) }
        switch mode {
        case .pending:
            // Don't take the keyboard away mid-typing; the user clicks in when ready.
            panel.orderFrontRegardless()
        case .edit:
            // Opened on purpose from the menu: ready to type.
            panel.makeKeyAndOrderFront(nil)
        }
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
