import AppKit

/// Builds the object graph and connects the session controller to the window controllers.
@MainActor
final class AppCoordinator {
    let settingsStore: SettingsStore
    let noteStore: NoteStore
    let chime: ChimePlayer
    let session: SessionController
    let systemEvents = SystemEvents()

    private var statusItem: StatusItemController?

    init() {
        let settingsStore = SettingsStore()
        let noteStore = NoteStore()
        let chime = ChimePlayer()
        self.settingsStore = settingsStore
        self.noteStore = noteStore
        self.chime = chime
        session = SessionController(
            settings: { settingsStore.settings },
            noteStore: noteStore,
            chime: chime
        )
    }

    func start() {
        AppearanceController.apply(settingsStore.settings.appearance)
        settingsStore.onAppearanceChange = { AppearanceController.apply($0) }

        session.presenter = self

        systemEvents.onPause = { [weak self] in self?.session.systemPaused($0) }
        systemEvents.onResume = { [weak self] in self?.session.systemResumed($0) }
        systemEvents.start()

        statusItem = StatusItemController(coordinator: self)
    }

    func stop() {
        chime.stop()
        systemEvents.stop()
    }
}

extension AppCoordinator: SessionPresenting {
    func openNoteWindow(mode: NoteWindowMode) {}
    func closeNoteWindow() {}
    func showBreakOverlay(mode: BreakOverlayMode) {}
    func hideBreakOverlay() {}
    func showResumePanel(note: Note) {}
    func closeResumePanel() {}
}
