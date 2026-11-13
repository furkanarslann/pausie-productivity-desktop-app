import AppKit
import SwiftUI

/// Shows the resume panel at the top right: after "Let's go!" / skip (T11, T12) or when a note is picked
/// from Recent notes. It closes itself after 15 s (paused while the pointer is over it), when the user
/// closes it, or at the next warning (rule 8). The note stays reachable from Recent notes.
@MainActor
final class ResumePanelController {
    private var panel: ResumePanel?
    private let autoCloseDelay: TimeInterval
    private lazy var autoClose = AutoCloseTimer(delay: autoCloseDelay) { [weak self] in self?.close() }

    init(autoCloseDelay: TimeInterval = SessionRules.resumePanelAutoCloseDelay) {
        self.autoCloseDelay = autoCloseDelay
    }

    var isVisible: Bool { panel?.isVisible == true }
    var frame: NSRect? { panel?.frame }

    func show(note: Note, origin: ResumePanelOrigin) {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.title = L10n.t(origin.titleKey)
        let view = ResumePanelView(
            note: note,
            origin: origin,
            onClose: { [weak self] in self?.close() },
            onHoverChange: { [weak self] hovering in
                guard let self, isVisible else { return }
                if hovering { autoClose.pause() } else { autoClose.resume() }
            }
        )
        let (_, size) = panel.hostSizedContent(view, width: Metrics.ResumePanel.width)
        panel.pinToTopRight(contentSize: size, inset: Metrics.ResumePanel.screenInset)
        panel.orderFrontRegardless()
        panel.makeKey()
        autoClose.start()
    }

    func close() {
        autoClose.cancel()
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
