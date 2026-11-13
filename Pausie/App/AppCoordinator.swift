import AppKit

/// Builds the object graph and connects the session controller to the window controllers.
/// It applies UI effects but makes no decisions: those come from `SessionMachine`.
@MainActor
final class AppCoordinator {
    let settingsStore: SettingsStore
    let noteStore: NoteStore
    let chime: ChimePlayer
    let session: SessionController
    let systemEvents = SystemEvents()

    private var statusItem: StatusItemController?
    private let noteWindow: NoteWindowController
    private let breakOverlay: BreakOverlayController
    private let resumePanel = ResumePanelController()
    private let settingsWindow: SettingsWindowController

    init() {
        let settingsStore = SettingsStore()
        let noteStore = NoteStore()
        let chime = ChimePlayer(sound: { settingsStore.settings.breakSound })
        let session = SessionController(
            settings: { settingsStore.settings },
            noteStore: noteStore,
            chime: chime
        )
        self.settingsStore = settingsStore
        self.noteStore = noteStore
        self.chime = chime
        self.session = session
        noteWindow = NoteWindowController(session: session)
        breakOverlay = BreakOverlayController(session: session, settings: settingsStore)
        settingsWindow = SettingsWindowController(store: settingsStore, player: chime)
    }

    func start() {
        AppearanceController.apply(settingsStore.settings.appearance)
        settingsStore.onAppearanceChange = { AppearanceController.apply($0) }

        session.presenter = self

        systemEvents.onPause = { [weak self] in self?.session.systemPaused($0) }
        systemEvents.onResume = { [weak self] in self?.session.systemResumed($0) }
        systemEvents.onScreensChanged = { [weak self] in self?.breakOverlay.rebuildIfVisible() }
        breakOverlay.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        systemEvents.start()

        statusItem = StatusItemController(session: session, noteStore: noteStore, actions: self)
    }

    func stop() {
        chime.stop()
        systemEvents.stop()
    }
}

extension AppCoordinator: SessionPresenting {
    func openNoteWindow(mode: NoteWindowMode) {
        noteWindow.show(mode: mode)
    }

    func closeNoteWindow() {
        noteWindow.close()
    }

    func showBreakOverlay(mode: BreakOverlayMode) {
        // The overlay view picks its card from the session state; the mode only says it must be up.
        breakOverlay.show()
    }

    func hideBreakOverlay() {
        breakOverlay.hide()
    }

    func showResumePanel(note: Note) {
        resumePanel.show(note: note, origin: .breakEnded)
    }

    func closeResumePanel() {
        resumePanel.close()
    }
}

extension AppCoordinator: StatusMenuActions {
    func requestSkipBreak() {
        session.requestSkipBreak()
        breakOverlay.focus()
    }

    func showRecentNote(_ note: Note) {
        resumePanel.show(note: note, origin: .recentNotes)
    }

    func showSettings() {
        settingsWindow.show()
    }
}
