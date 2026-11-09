import Foundation
import Testing
@testable import Pausie

@Suite("SessionController")
@MainActor
struct SessionControllerTests {
    // MARK: - Full flow

    @Test("T1-T2: the note window opens at minute 45 of a 50 min cycle")
    func warningAtMinute45() {
        let h = SessionHarness()
        h.controller.send(.start)
        #expect(h.controller.state == .working)
        #expect(h.controller.workRemaining == TimeInterval(50 * 60))

        h.advance(minutes: 44)
        #expect(h.controller.state == .working)
        h.advance(seconds: 59)
        #expect(h.controller.state == .working)
        h.advance(seconds: 1)
        #expect(h.controller.state == .preBreakPending)
        #expect(h.presenter.calls == [.closeResumePanel, .openNoteWindow(.pending)])

        // Only once.
        h.presenter.reset()
        h.advance(seconds: 30)
        #expect(h.presenter.calls.isEmpty)
    }

    @Test("T3 + T6: save & keep working, then the break starts directly")
    func saveAndContinueThenBreak() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 46)
        h.controller.send(.saveNoteAndContinue(markdown: "- [ ] write tests\n- [ ] "))
        #expect(h.controller.state == .preBreakNoted)
        #expect(h.noteStore.notes.first?.markdown == "- [ ] write tests")

        h.advance(minutes: 4)
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
        #expect(h.presenter.calls.contains(.showBreakOverlay(.running)))
    }

    @Test("T4: save & take a break skips the remaining work time")
    func saveAndBreak() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndBreak(markdown: "- [ ] a"))
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.workRemaining == nil)
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
    }

    @Test("T5 + T9 + rule 1: no note means the break timer waits for the save")
    func requiredNoteHoldsTheBreakTimer() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        #expect(h.controller.state == .preBreakPending)
        h.controller.draft = "- [ ] unsaved draft"

        h.advance(minutes: 5)
        #expect(h.controller.state == .breakNoteRequired)
        #expect(h.controller.breakRemaining == nil)
        #expect(h.controller.breakDeadline == nil)
        // The draft carries over to the required-note editor.
        #expect(h.controller.draft == "- [ ] unsaved draft")

        // Writing takes 3 minutes; that time doesn't come out of the break.
        h.advance(minutes: 3)
        h.controller.send(.saveRequiredNote(markdown: h.controller.draft))
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
        #expect(h.noteStore.latest?.markdown == "- [ ] unsaved draft")
    }

    @Test("T7: take a break now from the menu")
    func takeBreakNow() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndContinue(markdown: ""))
        h.controller.send(.takeBreakNow)
        #expect(h.controller.state == .onBreak)
    }

    @Test("T8: Edit note updates the same record; no duplicate in history")
    func editNoteUpdatesSameRecord() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndContinue(markdown: "- [ ] first"))
        let id = try #require(h.controller.currentNote?.id)

        h.controller.send(.editNote)
        #expect(h.controller.state == .preBreakNoted)
        #expect(h.controller.draft == "- [ ] first")
        #expect(h.presenter.calls.last == .openNoteWindow(.edit))

        h.controller.send(.saveNoteAndContinue(markdown: "- [ ] first\n- [ ] second"))
        #expect(h.noteStore.notes.count == 1)
        #expect(h.noteStore.notes.first?.id == id)
        #expect(h.noteStore.notes.first?.markdown == "- [ ] first\n- [ ] second")
    }

    @Test("Edit of an empty saved note opens with the todo template")
    func editEmptyNote() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndContinue(markdown: "- [ ] "))
        #expect(h.noteStore.latest?.markdown == "")
        h.controller.send(.editNote)
        #expect(h.controller.draft == TodoMarkdown.template)
    }

    @Test("T10 + T11: chime at the end of the break, Let's go stops it and opens the resume panel")
    func breakOverAndLetsGo() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndBreak(markdown: "- [ ] resume here"))
        let note = try #require(h.controller.currentNote)

        h.advance(minutes: 9)
        h.controller.send(.letsGo) // rule 2: ignored while running
        #expect(h.controller.state == .onBreak)

        h.advance(minutes: 1)
        #expect(h.controller.state == .breakOver)
        #expect(h.chime.isPlaying)
        #expect(h.controller.breakProgress == 1)

        h.presenter.reset()
        h.controller.send(.letsGo)
        #expect(h.controller.state == .working)
        #expect(!h.chime.isPlaying)
        #expect(h.presenter.calls == [.hideBreakOverlay, .showResumePanel(note)])
        #expect(h.controller.workRemaining == TimeInterval(50 * 60))
        #expect(h.controller.currentNote == nil)
        #expect(h.controller.draft == TodoMarkdown.template)
    }

    @Test("T12: skip needs confirmation; Keep resting continues the break")
    func skipBreak() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndBreak(markdown: "- [ ] x"))
        let note = try #require(h.controller.currentNote)

        h.controller.confirmSkipBreak() // no confirmation shown yet: nothing happens
        #expect(h.controller.state == .onBreak)

        h.controller.requestSkipBreak()
        #expect(h.controller.isSkipConfirmationPresented)
        h.controller.cancelSkipBreak()
        #expect(!h.controller.isSkipConfirmationPresented)
        #expect(h.controller.state == .onBreak)

        h.presenter.reset()
        h.controller.requestSkipBreak()
        h.controller.confirmSkipBreak()
        #expect(h.controller.state == .working)
        #expect(h.presenter.calls == [.hideBreakOverlay, .showResumePanel(note)])
        #expect(h.controller.workRemaining == TimeInterval(50 * 60))
    }

    @Test("Skip confirmation can't be opened outside a running break")
    func skipRequestOutsideBreak() {
        let h = SessionHarness()
        h.controller.requestSkipBreak()
        #expect(!h.controller.isSkipConfirmationPresented)
    }

    @Test("Break ending while the skip confirmation is open closes it")
    func breakEndsDuringSkipConfirmation() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndBreak(markdown: ""))
        h.controller.requestSkipBreak()
        h.advance(minutes: 10)
        #expect(h.controller.state == .breakOver)
        #expect(!h.controller.isSkipConfirmationPresented)
    }

    @Test("T13: stop resets the timer")
    func stop() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 46)
        h.controller.send(.stop)
        #expect(h.controller.state == .idle)
        #expect(h.controller.workRemaining == nil)
        #expect(h.controller.workDeadline == nil)
        #expect(h.presenter.calls.last == .closeNoteWindow)
    }

    @Test("Rule 8: the resume panel closes itself at the next warning")
    func resumePanelClosesAtWarning() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        #expect(h.presenter.calls.first == .closeResumePanel)
    }

    // MARK: - Settings (rule 11)

    @Test("Duration changes mid-cycle apply from the next cycle")
    func settingsSnapshot() {
        let h = SessionHarness(workMinutes: 50, breakMinutes: 10)
        h.controller.send(.start)
        h.settings.value.workMinutes = 25
        h.settings.value.breakMinutes = 5
        h.advance(minutes: 10)
        #expect(h.controller.workRemaining == TimeInterval(40 * 60))

        h.advance(minutes: 35)
        h.controller.send(.saveNoteAndBreak(markdown: ""))
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))

        h.advance(minutes: 10)
        h.controller.send(.letsGo)
        #expect(h.controller.workRemaining == TimeInterval(25 * 60))
    }

    // MARK: - Sleep and lock (rule 5)

    @Test("Screen lock pauses the work timer and resumes where it left off")
    func lockPausesWork() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 10)
        h.controller.systemPaused(.screenLocked)
        h.advance(minutes: 60)
        #expect(h.controller.state == .working)
        #expect(h.controller.workRemaining == TimeInterval(40 * 60))

        h.controller.systemResumed(.screenLocked)
        #expect(h.controller.workRemaining == TimeInterval(40 * 60))
        h.advance(minutes: 5)
        #expect(h.controller.workRemaining == TimeInterval(35 * 60))
    }

    @Test("Lock then sleep: work resumes only after both end")
    func overlappingPauses() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.controller.systemPaused(.screenLocked)
        h.controller.systemPaused(.sleep)
        h.clock.advance(minutes: 30)
        h.controller.systemResumed(.sleep)
        h.advance(minutes: 5)
        #expect(h.controller.workRemaining == TimeInterval(50 * 60))
        h.controller.systemResumed(.screenLocked)
        h.advance(minutes: 5)
        #expect(h.controller.workRemaining == TimeInterval(45 * 60))
    }

    @Test("Sleep during a break: break time keeps running; Break's over opens on wake")
    func sleepDuringBreak() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndBreak(markdown: ""))
        h.controller.systemPaused(.sleep)
        h.clock.advance(minutes: 15) // no ticks while asleep
        #expect(h.controller.state == .onBreak)
        h.controller.systemResumed(.sleep)
        #expect(h.controller.state == .breakOver)
        #expect(h.chime.isPlaying)
    }

    @Test("Sleep in the warning window keeps the note window state")
    func sleepDuringWarning() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 47)
        h.controller.systemPaused(.sleep)
        h.clock.advance(minutes: 30)
        h.controller.systemResumed(.sleep)
        #expect(h.controller.state == .preBreakPending)
        #expect(h.controller.workRemaining == TimeInterval(3 * 60))
    }

    // MARK: - Derived values

    @Test("Work end time and break progress")
    func derivedValues() {
        let h = SessionHarness()
        h.controller.send(.start)
        #expect(h.controller.workEndsAt == h.clock.now.addingTimeInterval(50 * 60))
        h.advance(minutes: 45)
        h.controller.send(.saveNoteAndBreak(markdown: ""))
        #expect(h.controller.breakProgress == 0)
        h.advance(minutes: 5)
        #expect(abs(h.controller.breakProgress - 0.5) < 0.0001)
        #expect(h.controller.breakEndsAt == h.clock.now.addingTimeInterval(5 * 60))
    }

    @Test("A late tick still goes through the warning before time up")
    func lateTick() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 51)
        #expect(h.controller.state == .breakNoteRequired)
        #expect(h.presenter.calls == [
            .closeResumePanel, .openNoteWindow(.pending), .closeNoteWindow, .showBreakOverlay(.noteRequired),
        ])
    }
}
