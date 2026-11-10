import AppKit
import SwiftUI
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
        #expect(MenuPresentation(Snapshot(state: .preBreakSnoozed, workRemaining: 191.2)).title == "03:12")
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
        #expect(MenuPresentation.makeRows(for: .preBreakSnoozed) == [
            .separator, .writeNote, .separator, .recentNotes, .settings, .separator, .stop, .separator, .quit,
        ])
        #expect(MenuPresentation.makeRows(for: .preBreakPending) == MenuPresentation.makeRows(for: .working))
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

        let snoozed = MenuPresentation(Snapshot(state: .preBreakSnoozed, workRemaining: 192, workEndsAt: now, workProgress: 0.9)).header
        #expect(snoozed.title == "Focus session")
        #expect(snoozed.subtitle == "03:12 left · break at \(TimeFormat.clockTime(now))")
        #expect(snoozed.progress == 0.9)

        let noted = MenuPresentation(Snapshot(state: .preBreakNoted, workRemaining: 192, workProgress: 0.9)).header
        #expect(noted.pose == .takingNotes)
        #expect(noted.title == "Note saved")
        #expect(noted.subtitle == "Break in 03:12")
        #expect(MenuPresentation(Snapshot(state: .preBreakNoted, workRemaining: 192)).title == "03:12")

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
    func editorPaste() {
        var model = TodoEditorModel(markdown: "- [ ] first")
        let id = model.rows[0].id
        let focus = model.setText("- [ ] one\n- [ ] two\nthree", for: id)
        #expect(model.rows.map(\.text) == ["one", "two", "three"])
        #expect(model.rows.first?.id == id)
        #expect(focus == TodoEditorModel.Focus(rowID: model.rows[2].id, caret: .end))
        #expect(model.markdown == "- [ ] one\n- [ ] two\n- [ ] three")
    }
}

@Suite("Todo editor model")
struct TodoEditorModelTests {
    private func model(_ texts: [String]) -> TodoEditorModel {
        TodoEditorModel(rows: texts.map { TodoEditorModel.Row(text: $0) })
    }

    @Test("An empty editor is one empty row with the todo template")
    func emptyEditor() {
        let model = TodoEditorModel(markdown: "")
        #expect(model.rows.map(\.text) == [""])
        #expect(model.markdown == TodoMarkdown.template)
        #expect(TodoEditorModel(rows: []).rows.count == 1)
    }

    @Test("Return adds an empty row below and focuses it")
    func insert() {
        var model = model(["a", "b"])
        let focus = model.insertRow(after: model.rows[0].id)
        #expect(model.rows.map(\.text) == ["a", "", "b"])
        #expect(focus == TodoEditorModel.Focus(rowID: model.rows[1].id, caret: .end))
    }

    @Test("Return in an empty or blank todo doesn't add a line")
    func returnInEmptyRow() {
        var model = model(["a", ""])
        #expect(model.insertRow(after: model.rows[1].id) == nil)
        #expect(model.rows.map(\.text) == ["a", ""])

        var blank = self.model(["   "])
        #expect(blank.insertRow(after: blank.rows[0].id) == nil)
        #expect(blank.rows.count == 1)

        var fresh = TodoEditorModel(markdown: "")
        #expect(fresh.insertRow(after: fresh.rows[0].id) == nil)
        #expect(fresh.markdown == TodoMarkdown.template)
    }

    @Test("Backspace in a cleared middle todo removes it; the caret goes to the end of the row above")
    func deleteMiddle() {
        var model = model(["first", "second", "third"])
        let middle = model.rows[1].id
        #expect(model.setText("", for: middle) == nil)
        #expect(model.rows.count == 3)

        let focus = model.deleteEmptyRow(middle)
        #expect(model.rows.map(\.text) == ["first", "third"])
        #expect(focus == TodoEditorModel.Focus(rowID: model.rows[0].id, caret: .end))
        #expect(model.markdown == "- [ ] first\n- [ ] third")
    }

    @Test("Backspace in an empty first row focuses the next row's start")
    func deleteFirst() {
        var model = model(["", "b"])
        let focus = model.deleteEmptyRow(model.rows[0].id)
        #expect(model.rows.map(\.text) == ["b"])
        #expect(focus == TodoEditorModel.Focus(rowID: model.rows[0].id, caret: .start))
    }

    @Test("Forward delete in an empty row focuses the start of the row below")
    func deleteForward() {
        var model = model(["a", "", "c"])
        let focus = model.deleteEmptyRow(model.rows[1].id, forward: true)
        #expect(model.rows.map(\.text) == ["a", "c"])
        #expect(focus == TodoEditorModel.Focus(rowID: model.rows[1].id, caret: .start))
    }

    @Test("Rows with text and the last remaining row are never removed")
    func deleteGuards() {
        var model = model(["a", "b"])
        #expect(model.deleteEmptyRow(model.rows[0].id) == nil)
        var single = self.model([""])
        #expect(single.deleteEmptyRow(single.rows[0].id) == nil)
        #expect(single.rows.count == 1)
    }

    @Test("Up and down move between rows and stop at the ends")
    func arrows() {
        let model = model(["a", "b"])
        #expect(model.neighbor(of: model.rows[0].id, offset: 1)?.rowID == model.rows[1].id)
        #expect(model.neighbor(of: model.rows[0].id, offset: -1) == nil)
        #expect(model.neighbor(of: model.rows[1].id, offset: 1) == nil)
    }
}

@Suite("Resume panel auto-close")
@MainActor
struct AutoCloseTimerTests {
    final class Counter {
        var value = 0
    }

    @Test("Fires once after the delay")
    func fires() async throws {
        let counter = Counter()
        let timer = AutoCloseTimer(delay: 0.05) { counter.value += 1 }
        timer.start()
        #expect(timer.isScheduled)
        try await Task.sleep(for: .milliseconds(300))
        #expect(counter.value == 1)
        #expect(!timer.isScheduled)
    }

    @Test("Paused while hovered; resuming starts the delay again")
    func pauseAndResume() async throws {
        let counter = Counter()
        let timer = AutoCloseTimer(delay: 0.1) { counter.value += 1 }
        timer.start()
        timer.pause()
        try await Task.sleep(for: .milliseconds(250))
        #expect(counter.value == 0)
        timer.resume()
        try await Task.sleep(for: .milliseconds(300))
        #expect(counter.value == 1)
    }

    @Test("Closing cancels it")
    func cancel() async throws {
        let counter = Counter()
        let timer = AutoCloseTimer(delay: 0.05) { counter.value += 1 }
        timer.start()
        timer.cancel()
        try await Task.sleep(for: .milliseconds(200))
        #expect(counter.value == 0)
    }

    @Test("The Welcome back panel closes after 15 s")
    func delay() {
        #expect(SessionRules.resumePanelAutoCloseDelay == 15)
    }
}

@Suite("Panel sizing")
struct PanelSizingTests {
    @Test("Heights are whole points, finite and capped at the screen")
    func clampedHeight() {
        #expect(PanelSizing.clampedHeight(220.2, maxHeight: 900) == 221)
        #expect(PanelSizing.clampedHeight(.greatestFiniteMagnitude, maxHeight: 900) == 900)
        #expect(PanelSizing.clampedHeight(.infinity, maxHeight: 900) == 0)
        #expect(PanelSizing.clampedHeight(.nan, maxHeight: 900) == 0)
        #expect(PanelSizing.clampedHeight(-5, maxHeight: 900) == 0)
    }
}

@Suite("Panel resizing")
@MainActor
struct PanelResizingTests {
    private func makePanel(height: CGFloat) -> TopAnchoredPanel {
        TopAnchoredPanel(
            contentRect: NSRect(x: 100, y: 100, width: 380, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
    }

    @Test("Fractional heights that round to the current height don't resize the window")
    func ignoresSubPointChanges() {
        // The old loop: AppKit shows 288, SwiftUI keeps asking for 287.5.
        let panel = makePanel(height: 288)
        panel.setContentHeightIfNeeded(287.5)
        panel.setContentHeightIfNeeded(287.01)
        panel.setContentHeightIfNeeded(288)
        #expect(panel.contentRect(forFrameRect: panel.frame).height == 288)
    }

    @Test("Real changes resize to whole points")
    func roundsUp() {
        let panel = makePanel(height: 200)
        panel.setContentHeightIfNeeded(287.5)
        #expect(panel.contentRect(forFrameRect: panel.frame).height == 288)
        panel.setContentHeightIfNeeded(.infinity)
        #expect(panel.contentRect(forFrameRect: panel.frame).height == 288)
    }
}

@Suite("Status item label")
@MainActor
struct StatusItemLabelTests {
    private func size(of view: some View) -> CGSize {
        NSHostingView(rootView: view).fittingSize
    }

    private func rolling(_ text: String) -> CGSize {
        size(of: RollingText(text: text, font: TypographyToken.menuBarTitle.font))
    }

    @Test("The countdown keeps its size from second to second")
    func stableSize() {
        let sizes = ["42:18", "42:17", "09:59", "00:00", "59:11", "10:01"].map(rolling)
        #expect(Set(sizes.map(\.width)).count == 1, "\(sizes)")
        #expect(Set(sizes.map(\.height)).count == 1, "\(sizes)")
    }

    @Test("Rolling digits are drawn at the same size as plain text in the same font")
    func sameSizeAsPlainText() {
        let text = "42:18"
        let plain = size(of: Text(text).font(TypographyToken.menuBarTitle.font))
        let rolling = rolling(text)
        // Same glyph size; each character slot rounds up to a whole point, so the width may differ by
        // under a point per character (constant from second to second, see `stableSize`).
        #expect(abs(plain.height - rolling.height) < 0.5, "plain \(plain), rolling \(rolling)")
        #expect(abs(plain.width - rolling.width) <= CGFloat(text.count), "plain \(plain), rolling \(rolling)")
    }

    @Test("The menu bar font is Regular 12 with monospaced digits")
    func font() {
        let spec = TypographyToken.menuBarTitle.spec
        #expect(spec.size == 12)
        #expect(spec.weight == .regular)
        #expect(spec.monospacedDigits)
    }
}
