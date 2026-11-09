import AppKit
import SwiftUI

/// Shows the resume panel at the top right: after "Let's go!" / skip (T11, T12) or when a note is picked
/// from Recent notes. It stays until closed and closes itself at the next warning (rule 8).
@MainActor
final class ResumePanelController {
    private var panel: ResumePanel?

    var isVisible: Bool { panel?.isVisible == true }

    func show(note: Note) {
        let panel = panel ?? makePanel()
        self.panel = panel
        let hosting = NSHostingController(rootView: ResumePanelView(note: note) { [weak self] in self?.close() })
        hosting.sizingOptions = .preferredContentSize
        panel.contentViewController = hosting
        panel.pinToTopRight(contentSize: hosting.view.fittingSize, inset: Metrics.ResumePanel.screenInset)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        guard let panel else { return }
        panel.orderOut(nil)
        panel.contentViewController = nil
        self.panel = nil
    }

    private func makePanel() -> ResumePanel {
        let panel = ResumePanel(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.ResumePanel.width, height: Metrics.ResumePanel.width),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.t(.resumeTitle)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The system shadow follows the rounded content.
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = WindowLevel.panel
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}

private final class ResumePanel: TopAnchoredPanel {}
