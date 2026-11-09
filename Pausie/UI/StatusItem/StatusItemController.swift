import AppKit
import SwiftUI

/// What the status item menu can ask the app to do.
@MainActor
protocol StatusMenuActions: AnyObject {
    func requestSkipBreak()
    func showRecentNote(_ note: Note)
    func showSettings()
}

/// Owns the `NSStatusItem`: template icon, `mm:ss` title, and the menu (screens 01 and 02).
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let session: SessionController
    private let noteStore: NoteStore
    private weak var actions: StatusMenuActions?
    private var isMenuOpen = false
    private var builtForState: SessionState?

    init(session: SessionController, noteStore: NoteStore, actions: StatusMenuActions) {
        self.session = session
        self.noteStore = noteStore
        self.actions = actions
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        menu.minimumWidth = Metrics.Menu.width
        statusItem.menu = menu

        if let button = statusItem.button {
            button.image = PausieAsset.menuBarIcon()
            button.imagePosition = .imageLeading
            button.setAccessibilityLabel(L10n.t(.noteWindowTitle))
        }
        observeSession()
    }

    // MARK: - Title

    private func observeSession() {
        withObservationTracking {
            updateTitle()
            rebuildIfStateChangedWhileOpen()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSession() }
        }
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }
        let presentation = MenuPresentation(session: session)
        if let title = presentation.title {
            button.attributedTitle = NSAttributedString(string: title, attributes: [
                .font: TypographyToken.menuBarTitle.nsFont,
            ])
            button.imagePosition = .imageLeading
        } else {
            button.attributedTitle = NSAttributedString()
            button.imagePosition = .imageOnly
        }
    }

    private func rebuildIfStateChangedWhileOpen() {
        let state = session.state
        guard isMenuOpen, state != builtForState else { return }
        rebuildMenu()
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    private func rebuildMenu() {
        let presentation = MenuPresentation(session: session)
        builtForState = session.state
        menu.removeAllItems()
        menu.addItem(headerItem())
        for row in presentation.rows {
            menu.addItem(item(for: row))
        }
    }

    private func headerItem() -> NSMenuItem {
        let hosting = NSHostingView(rootView: MenuHeaderView(session: session))
        hosting.frame.size = hosting.fittingSize
        let item = NSMenuItem()
        item.view = hosting
        return item
    }

    private func item(for row: MenuPresentation.Row) -> NSMenuItem {
        switch row {
        case .separator:
            return .separator()
        case .start:
            return actionItem(.menuItemStart, #selector(start), key: "s")
        case .stop:
            return actionItem(.menuItemStop, #selector(stop))
        case .takeBreakNow:
            return actionItem(.menuItemTakeBreakNow, #selector(takeBreakNow))
        case .editNote:
            return actionItem(.menuItemEditNote, #selector(editNote))
        case .skipBreak:
            return actionItem(.menuItemSkipBreak, #selector(skipBreak))
        case .recentNotes:
            let item = NSMenuItem(title: L10n.t(.menuItemRecentNotes), action: nil, keyEquivalent: "")
            item.submenu = RecentNotesMenu.make(notes: noteStore.notes, target: self, action: #selector(openRecentNote(_:)))
            return item
        case .settings:
            return actionItem(.menuItemSettings, #selector(openSettings), key: ",")
        case .quit:
            return actionItem(.menuItemQuit, #selector(quit), key: "q")
        }
    }

    private func actionItem(_ key: L10nKey, _ action: Selector, key equivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t(key), action: action, keyEquivalent: equivalent)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func start() { session.send(.start) }
    @objc private func stop() { session.send(.stop) }
    @objc private func takeBreakNow() { session.send(.takeBreakNow) }
    @objc private func editNote() { session.send(.editNote) }
    @objc private func skipBreak() { actions?.requestSkipBreak() }
    @objc private func openSettings() { actions?.showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openRecentNote(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID, let note = noteStore.note(id: id) else { return }
        actions?.showRecentNote(note)
    }
}
