import Foundation
import Testing
@testable import Pausie

@Suite("Menu presentation")
struct MenuPresentationTests {
    private typealias Snapshot = MenuPresentation.Snapshot
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Menu bar title per state")
    func titles() {
        #expect(MenuPresentation(Snapshot(state: .idle)).title == nil)
        #expect(MenuPresentation(Snapshot(state: .working, workRemaining: 42 * 60 + 18)).title == "42:18")
        #expect(MenuPresentation(Snapshot(state: .preBreakPending, workRemaining: 4 * 60 + 52)).title == "04:52")
        #expect(MenuPresentation(Snapshot(state: .preBreakNoted, workRemaining: 191.2)).title == "03:12")
        #expect(MenuPresentation(Snapshot(state: .breakNoteRequired)).title == L10n.t(.menubarTitleBreak))
        #expect(MenuPresentation(Snapshot(state: .onBreak, breakRemaining: 8 * 60 + 42)).title == "08:42")
        #expect(MenuPresentation(Snapshot(state: .breakOver)).title == "00:00")
    }

    @Test("Countdown rounds up so a fresh cycle shows its full length")
    func countdownRounding() {
        #expect(TimeFormat.countdown(3000) == "50:00")
        #expect(TimeFormat.countdown(2999.2) == "50:00")
        #expect(TimeFormat.countdown(0.4) == "00:01")
        #expect(TimeFormat.countdown(0) == "00:00")
        #expect(TimeFormat.countdown(90 * 60) == "90:00")
        #expect(TimeFormat.shortCountdown(292) == "4:52")
    }

    @Test("Rows per state match screen 01")
    func rows() {
        #expect(MenuPresentation.makeRows(for: .idle) == [
            .separator, .start, .separator, .recentNotes, .settings, .separator, .quit,
        ])
        #expect(MenuPresentation.makeRows(for: .working) == [
            .separator, .recentNotes, .settings, .separator, .stop, .separator, .quit,
        ])
        #expect(MenuPresentation.makeRows(for: .preBreakNoted) == [
            .separator, .takeBreakNow, .editNote, .separator, .recentNotes, .settings, .separator, .stop, .separator, .quit,
        ])
        #expect(MenuPresentation.makeRows(for: .onBreak) == [
            .separator, .skipBreak, .separator, .recentNotes, .settings, .separator, .quit,
        ])
        for state in [SessionState.breakNoteRequired, .breakOver] {
            let rows = MenuPresentation.makeRows(for: state)
            #expect(!rows.contains(.stop))
            #expect(!rows.contains(.skipBreak))
            #expect(rows.contains(.quit))
        }
    }

    @Test("Stop is never offered during a break")
    func noStopDuringBreak() {
        for state in [SessionState.breakNoteRequired, .onBreak, .breakOver] {
            #expect(!MenuPresentation.makeRows(for: state).contains(.stop))
        }
    }

    @Test("Headers use the state's pose and copy")
    func headers() {
        let working = MenuPresentation(Snapshot(state: .working, workRemaining: 42 * 60 + 18, workEndsAt: now, workProgress: 0.15)).header
        #expect(working.pose == .focused)
        #expect(working.title == "Focus session")
        #expect(working.subtitle == "42:18 left · break at \(TimeFormat.clockTime(now))")
        #expect(working.progress == 0.15)

        let noted = MenuPresentation(Snapshot(state: .preBreakNoted, workRemaining: 192, workProgress: 0.9)).header
        #expect(noted.pose == .takingNotes)
        #expect(noted.subtitle == "Break in 03:12")

        let onBreak = MenuPresentation(Snapshot(state: .onBreak, breakRemaining: 522, breakEndsAt: now)).header
        #expect(onBreak.pose == .breakTime)
        #expect(onBreak.progress == nil)
        #expect(onBreak.subtitle == "08:42 left · ends at \(TimeFormat.clockTime(now))")

        #expect(MenuPresentation(Snapshot(state: .idle)).header.pose == .sleepy)
        #expect(MenuPresentation(Snapshot(state: .breakOver)).header.pose == .backToWork)
    }

    @Test("Recent note label is the first non-empty line without the todo marker")
    func recentNoteLabel() {
        func note(_ markdown: String) -> Note {
            Note(id: UUID(), markdown: markdown, createdAt: now, updatedAt: now)
        }
        #expect(MenuPresentation.recentNoteLabel(note("- [ ] Finish validation\n- [ ] Other")) == "Finish validation")
        #expect(MenuPresentation.recentNoteLabel(note("- [ ] \n- [ ] Second")) == "Second")
        #expect(MenuPresentation.recentNoteLabel(note("")) == L10n.t(.menuRecentNotesEmptyNote))
    }
}

@Suite("Editor and settings controls")
struct ControlLogicTests {
    @Test("Stepper moves by multiples of its step and respects the range")
    func stepper() {
        let work = Settings.workMinutesRange
        #expect(DurationStepper.increment(50, step: 5, range: work) == 55)
        #expect(DurationStepper.decrement(50, step: 5, range: work) == 45)
        #expect(DurationStepper.decrement(10, step: 5, range: work) == 6)
        #expect(DurationStepper.decrement(6, step: 5, range: work) == 6)
        #expect(DurationStepper.increment(6, step: 5, range: work) == 10)
        #expect(DurationStepper.increment(180, step: 5, range: work) == 180)
        #expect(DurationStepper.decrement(1, step: 1, range: Settings.breakMinutesRange) == 1)
    }

    @Test("Pasted multi-line markdown is split into rows without duplicate markers")
    func editorNormalize() {
        let id = UUID()
        let rows = TodoEditor.normalize([TodoEditor.EditorRow(id: id, text: "- [ ] one\n- [ ] two\nthree")])
        #expect(rows.map(\.text) == ["one", "two", "three"])
        #expect(rows.first?.id == id)
        #expect(TodoEditor.normalize([]).map(\.text) == [""])
        let plain = [TodoEditor.EditorRow(text: "already plain")]
        #expect(TodoEditor.normalize(plain) == plain)
    }
}
