import Foundation
@testable import Pausie

final class FakeClock: SessionClock, @unchecked Sendable {
    var now: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        now = start
    }

    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    func advance(minutes: Double) {
        advance(minutes * 60)
    }
}

@MainActor
final class RecordingPresenter: SessionPresenting {
    enum Call: Equatable {
        case openNoteWindow(NoteWindowMode)
        case closeNoteWindow
        case showBreakOverlay(BreakOverlayMode)
        case hideBreakOverlay
        case showResumePanel(Note)
        case closeResumePanel
    }

    private(set) var calls: [Call] = []

    func openNoteWindow(mode: NoteWindowMode) { calls.append(.openNoteWindow(mode)) }
    func closeNoteWindow() { calls.append(.closeNoteWindow) }
    func showBreakOverlay(mode: BreakOverlayMode) { calls.append(.showBreakOverlay(mode)) }
    func hideBreakOverlay() { calls.append(.hideBreakOverlay) }
    func showResumePanel(note: Note) { calls.append(.showResumePanel(note)) }
    func closeResumePanel() { calls.append(.closeResumePanel) }

    func reset() { calls.removeAll() }
}

@MainActor
final class FakeChime: ChimePlaying {
    private(set) var playCount = 0
    private(set) var stopCount = 0
    private(set) var isPlaying = false

    func play() {
        playCount += 1
        isPlaying = true
    }

    func stop() {
        stopCount += 1
        isPlaying = false
    }
}

@MainActor
final class SettingsBox {
    var value = Settings()
}

enum TestFiles {
    static func temporaryNotesURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "PausieTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "notes.json")
    }
}

/// A controller wired to fakes, with the 1 s ticker disabled; tests call `tick()` after moving the clock.
@MainActor
struct SessionHarness {
    let clock = FakeClock()
    let settings = SettingsBox()
    let presenter = RecordingPresenter()
    let chime = FakeChime()
    let notesURL = TestFiles.temporaryNotesURL()
    let noteStore: NoteStore
    let controller: SessionController

    init(workMinutes: Int = 50, breakMinutes: Int = 10) {
        settings.value.workMinutes = workMinutes
        settings.value.breakMinutes = breakMinutes
        noteStore = NoteStore(fileURL: notesURL)
        let settings = settings
        controller = SessionController(
            clock: clock,
            settings: { settings.value },
            noteStore: noteStore,
            chime: chime,
            autoTick: false
        )
        controller.presenter = presenter
    }

    func advance(minutes: Double) {
        clock.advance(minutes: minutes)
        controller.tick()
    }

    func advance(seconds: TimeInterval) {
        clock.advance(seconds)
        controller.tick()
    }
}
