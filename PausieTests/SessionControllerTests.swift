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

    @Test("T14 + T15: Ask me later brings the note back at 3 and 1 min left, then the break screen asks")
    func askLaterReminders() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.presenter.reset()

        h.controller.askLater()
        #expect(h.controller.state == .preBreakSnoozed)
        #expect(h.controller.noteReminderAt == TimeInterval(3 * 60))
        #expect(h.presenter.calls == [.closeNoteWindow])

        h.advance(seconds: 119)
        #expect(h.controller.state == .preBreakSnoozed)
        h.advance(seconds: 1) // 3:00 left
        #expect(h.controller.state == .preBreakPending)
        #expect(h.presenter.calls.last == .openNoteWindow(.pending))

        h.controller.askLater()
        #expect(h.controller.noteReminderAt == TimeInterval(1 * 60))
        h.advance(minutes: 2) // 1:00 left
        #expect(h.controller.state == .preBreakPending)

        h.controller.askLater()
        #expect(h.controller.noteReminderAt == nil)
        h.advance(seconds: 59)
        #expect(h.controller.state == .preBreakSnoozed)
        h.advance(seconds: 1) // time up with nothing written: ask on the break screen
        #expect(h.controller.state == .breakNoteRequired)
        #expect(h.controller.breakDeadline == nil)
    }

    @Test("Ask me later right before a reminder skips it")
    func askLaterSkipsImminentReminder() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.advance(seconds: 115) // 3:05 left
        h.controller.askLater()
        #expect(h.controller.noteReminderAt == TimeInterval(1 * 60))
    }

    @Test("Write note now reopens the note window while snoozed")
    func writeNoteNow() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.askLater()
        h.presenter.reset()
        h.controller.writeNoteNow()
        #expect(h.controller.state == .preBreakPending)
        #expect(h.presenter.calls == [.openNoteWindow(.pending)])
        #expect(h.controller.noteReminderAt == nil)
    }

    @Test("The draft survives Ask me later")
    func draftSurvivesAskLater() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.draft = "- [ ] started typing"
        h.controller.askLater()
        h.controller.writeNoteNow()
        #expect(h.controller.draft == "- [ ] started typing")
    }

    @Test("Stop while snoozed goes idle and drops the reminder")
    func stopWhileSnoozed() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.askLater()
        h.controller.send(.stop)
        #expect(h.controller.state == .idle)
        #expect(h.controller.noteReminderAt == nil)
    }

    @Test("T3 + T6: Save keeps working; the break starts on time with the saved note")
    func saveKeepsWorking() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 46)
        h.controller.send(.saveNote(markdown: "- [ ] write tests\n- [ ] "))
        #expect(h.controller.state == .preBreakNoted)
        #expect(h.noteStore.notes.first?.markdown == "- [ ] write tests")
        #expect(h.presenter.calls.last == .closeNoteWindow)
        #expect(h.controller.workRemaining == TimeInterval(4 * 60))

        h.advance(minutes: 3)
        #expect(h.controller.state == .preBreakNoted)
        h.advance(minutes: 1)
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
        #expect(h.noteStore.notes.count == 1)
    }

    @Test("T6: a break starting after Save keeps the note's save time")
    func timeUpKeepsSaveTime() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 46)
        h.controller.send(.saveNote(markdown: "- [ ] a"))
        let savedAt = try #require(h.noteStore.latest?.updatedAt)
        h.advance(minutes: 4)
        #expect(h.controller.state == .onBreak)
        #expect(h.noteStore.latest?.updatedAt == savedAt)
    }

    @Test("T7: take a break now from the menu after saving")
    func takeBreakNow() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.takeBreakNow() // not saved yet: ignored
        #expect(h.controller.state == .preBreakPending)
        h.saveNoteAndTakeBreak("- [ ] a")
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.workRemaining == nil)
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
        #expect(h.noteStore.latest?.markdown == "- [ ] a")
    }

    @Test("T8: Edit note updates the same record; no duplicate in history")
    func editNoteUpdatesSameRecord() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNote(markdown: "- [ ] first"))
        let id = try #require(h.controller.currentNote?.id)

        h.controller.editNote()
        #expect(h.controller.state == .preBreakNoted)
        #expect(h.controller.draft == "- [ ] first")
        #expect(h.presenter.calls.last == .openNoteWindow(.edit))

        h.controller.send(.saveNote(markdown: "- [ ] first\n- [ ] second"))
        #expect(h.noteStore.notes.count == 1)
        #expect(h.noteStore.notes.first?.id == id)
        #expect(h.noteStore.notes.first?.markdown == "- [ ] first\n- [ ] second")
    }

    @Test("Edits in an open Edit note window are saved when time runs out")
    func timeUpWhileEditingSavesEdits() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNote(markdown: "- [ ] first"))
        h.controller.editNote()
        h.controller.draft = "- [ ] first\n- [ ] added while editing"
        h.advance(minutes: 5)
        #expect(h.controller.state == .onBreak)
        #expect(h.noteStore.notes.count == 1)
        #expect(h.noteStore.latest?.markdown == "- [ ] first\n- [ ] added while editing")
    }

    @Test("Edit of an empty saved note opens with the todo template")
    func editEmptyNote() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNote(markdown: "- [ ] "))
        #expect(h.noteStore.latest?.markdown == "")
        h.controller.editNote()
        #expect(h.controller.draft == TodoMarkdown.template)
    }

    @Test("T5 + T9 + rule 1: nothing written means the break timer waits for the save")
    func requiredNoteHoldsTheBreakTimer() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        #expect(h.controller.state == .preBreakPending)

        h.advance(minutes: 5)
        #expect(h.controller.state == .breakNoteRequired)
        #expect(h.controller.breakRemaining == nil)
        #expect(h.controller.breakDeadline == nil)

        // Writing takes 3 minutes; that time doesn't come out of the break.
        h.advance(minutes: 3)
        h.controller.draft = "- [ ] written on the break screen"
        h.controller.send(.saveRequiredNote(markdown: h.controller.draft))
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
        #expect(h.noteStore.latest?.markdown == "- [ ] written on the break screen")
    }

    @Test("T5: notes being typed when time runs out are saved and the break starts")
    func timeUpSavesTypedNotes() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.draft = "- [ ] half done\n- [ ] "
        h.presenter.reset()

        h.advance(minutes: 5)
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
        #expect(h.noteStore.latest?.markdown == "- [ ] half done")
        #expect(h.presenter.calls == [.closeNoteWindow, .showBreakOverlay(.running)])
    }

    @Test("T5: notes typed before Ask me later are saved at time up too")
    func timeUpSavesSnoozedDraft() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.draft = "- [ ] typed, then snoozed"
        h.controller.askLater()
        h.controller.writeNoteNow()
        h.controller.askLater()
        h.controller.askLater() // ignored: already snoozed
        h.advance(minutes: 5)
        #expect(h.controller.state == .onBreak)
        #expect(h.noteStore.latest?.markdown == "- [ ] typed, then snoozed")
    }

    @Test("A todo cleared before saving doesn't stay in the note as an empty checkbox")
    func clearedTodoIsDropped() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.saveNoteAndTakeBreak("- [ ] first\n- [ ] \n- [ ] third")
        #expect(h.noteStore.latest?.markdown == "- [ ] first\n- [ ] third")
    }

    @Test("T10 + T11: chime at the end of the break, Let's go stops it and opens the resume panel")
    func breakOverAndLetsGo() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.saveNoteAndTakeBreak("- [ ] resume here")
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
        h.saveNoteAndTakeBreak("- [ ] x")
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
        h.saveNoteAndTakeBreak("")
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
        h.saveNoteAndTakeBreak("")
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))

        h.advance(minutes: 10)
        h.controller.send(.letsGo)
        #expect(h.controller.workRemaining == TimeInterval(25 * 60))
    }

    // MARK: - Sleep and lock (rule 8)

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
        h.saveNoteAndTakeBreak("")
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

    // MARK: - Pause from the menu (T16, T17)

    @Test("T16 + T17: Pause freezes the work timer, Resume continues from where it stopped")
    func pauseAndResume() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 10)
        h.controller.pause()
        #expect(h.controller.isPausedByUser)
        h.advance(minutes: 60)
        #expect(h.controller.state == .working)
        #expect(h.controller.workRemaining == TimeInterval(40 * 60))

        h.controller.resume()
        #expect(!h.controller.isPausedByUser)
        h.advance(minutes: 5)
        #expect(h.controller.workRemaining == TimeInterval(35 * 60))
    }

    @Test("Paused in the last minutes: no reminder and no break until Resume")
    func pauseHoldsTheBreak() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.askLater()
        h.controller.pause()
        h.advance(minutes: 30)
        #expect(h.controller.state == .preBreakSnoozed)
        #expect(h.controller.breakDeadline == nil)

        h.controller.resume()
        h.advance(minutes: 2) // 3:00 left: the reminder comes back
        #expect(h.controller.state == .preBreakPending)
    }

    @Test("Pause and lock overlap: the timer runs only after both end")
    func pauseAndLock() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.controller.pause()
        h.controller.systemPaused(.screenLocked)
        h.controller.systemResumed(.screenLocked)
        h.advance(minutes: 5)
        #expect(h.controller.workRemaining == TimeInterval(50 * 60))
        #expect(h.controller.isPausedByUser)
        h.controller.resume()
        h.advance(minutes: 5)
        #expect(h.controller.workRemaining == TimeInterval(45 * 60))
    }

    @Test("A pause ends with its work block: a break taken from the menu, or Stop")
    func pauseClearedAtBreakAndStop() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNote(markdown: "- [ ] x"))
        h.controller.pause()
        h.controller.takeBreakNow()
        #expect(h.controller.state == .onBreak)
        #expect(!h.controller.isPausedByUser)
        h.controller.requestSkipBreak()
        h.controller.confirmSkipBreak()
        #expect(h.controller.state == .working)
        h.advance(minutes: 5)
        #expect(h.controller.workRemaining == TimeInterval(45 * 60))

        h.controller.pause()
        h.controller.send(.stop)
        #expect(!h.controller.isPausedByUser)
        h.controller.send(.start)
        h.advance(minutes: 5)
        #expect(h.controller.workRemaining == TimeInterval(45 * 60))
    }

    // MARK: - Skipping the note (T18-T21)

    @Test("T18 + T19: Skip keeps working; the break starts on time and nothing is saved or shown after")
    func skipNoteThenBreak() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.presenter.reset()

        h.controller.skipNote()
        #expect(h.controller.state == .preBreakSkipped)
        #expect(h.presenter.calls == [.closeNoteWindow])

        h.advance(minutes: 3) // no reminders after skipping
        #expect(h.controller.state == .preBreakSkipped)
        h.advance(minutes: 2)
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.breakDeadline != nil)
        #expect(h.noteStore.notes.isEmpty)
        #expect(!h.controller.hasNoteThisCycle) // the break cards don't promise a note

        h.advance(minutes: 10)
        h.presenter.reset()
        h.controller.send(.letsGo)
        #expect(h.controller.state == .working)
        #expect(h.presenter.calls == [.hideBreakOverlay]) // no Welcome back without a note
    }

    @Test("A skipped cycle doesn't show the previous cycle's note after the break")
    func skippedCycleShowsNoOldNote() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.saveNoteAndTakeBreak("- [ ] earlier note")
        h.advance(minutes: 10)
        h.controller.send(.letsGo)

        h.advance(minutes: 45)
        h.controller.skipNote()
        h.controller.takeBreakNow()
        #expect(h.controller.state == .onBreak)
        h.controller.requestSkipBreak()
        h.presenter.reset()
        h.controller.confirmSkipBreak()
        #expect(h.presenter.calls == [.hideBreakOverlay])
        #expect(h.noteStore.notes.count == 1)
    }

    @Test("T20: Write note now after skipping brings back what was typed")
    func writeNoteAfterSkipping() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.draft = "- [ ] half a thought"
        h.controller.skipNote()
        h.presenter.reset()

        h.controller.writeNoteNow()
        #expect(h.controller.state == .preBreakPending)
        #expect(h.presenter.calls == [.openNoteWindow(.pending)])
        #expect(h.controller.draft == "- [ ] half a thought")
        h.controller.send(.saveNote(markdown: h.controller.draft))
        #expect(h.controller.state == .preBreakNoted)
        #expect(h.noteStore.notes.count == 1)
    }

    @Test("T21: Skip on the break note card starts the break without a note")
    func skipOnBreakNoteCard() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 50)
        #expect(h.controller.state == .breakNoteRequired)
        h.presenter.reset()

        h.controller.skipNote()
        #expect(h.controller.state == .onBreak)
        #expect(h.presenter.calls == [.showBreakOverlay(.running)])
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
        #expect(h.noteStore.notes.isEmpty)
    }

    // MARK: - Snooze the break (T22)

    @Test("T22: snoozing a running break gives 5 more min of work, then a full break; only once")
    func postponeRunningBreak() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.send(.saveNote(markdown: "- [ ] Finish the login screen"))
        h.advance(minutes: 5)
        #expect(h.controller.state == .onBreak)
        #expect(h.controller.canPostponeBreak)
        h.advance(minutes: 2)
        h.presenter.reset()

        h.controller.postponeBreak()
        #expect(h.controller.state == .preBreakNoted)
        #expect(h.presenter.calls == [.hideBreakOverlay])
        #expect(h.controller.workRemaining == SessionRules.breakPostpone)
        #expect(h.controller.breakDeadline == nil)
        #expect(h.controller.hasPostponedBreak)

        h.advance(seconds: SessionRules.breakPostpone - 1)
        #expect(h.controller.state == .preBreakNoted)
        h.advance(seconds: 1)
        #expect(h.controller.state == .onBreak)
        // The break starts again from the beginning, with the same note (no second record).
        #expect(h.controller.breakRemaining == TimeInterval(10 * 60))
        #expect(h.noteStore.notes.count == 1)

        #expect(!h.controller.canPostponeBreak)
        h.controller.postponeBreak()
        #expect(h.controller.state == .onBreak)
    }

    @Test("T22: snoozing the note card brings no reminders; the break screen asks again at time up")
    func postponeNoteCard() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 50)
        #expect(h.controller.state == .breakNoteRequired)
        h.presenter.reset()

        h.controller.postponeBreak()
        #expect(h.controller.state == .preBreakSnoozed)
        #expect(h.controller.noteReminderAt == nil)
        #expect(h.presenter.calls == [.hideBreakOverlay])

        h.advance(minutes: 4)
        #expect(h.controller.state == .preBreakSnoozed)
        #expect(!h.presenter.calls.contains(.openNoteWindow(.pending)))
        h.advance(minutes: 1)
        #expect(h.controller.state == .breakNoteRequired)
        #expect(h.controller.breakDeadline == nil)
        #expect(!h.controller.canPostponeBreak)
    }

    @Test("T22: notes typed on the note card before snoozing are saved at time up")
    func postponeNoteCardKeepsDraft() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 50)
        h.controller.draft = "- [ ] Reply to the review"
        h.controller.postponeBreak()
        h.advance(minutes: 5)
        #expect(h.controller.state == .onBreak)
        #expect(try #require(h.noteStore.notes.first).markdown == "- [ ] Reply to the review")
    }

    @Test("T22: a break whose note was skipped stays without a note after snoozing")
    func postponeSkippedBreak() {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 50)
        h.controller.skipNote()
        h.controller.postponeBreak()
        #expect(h.controller.state == .preBreakSkipped)
        h.advance(minutes: 5)
        #expect(h.controller.state == .onBreak)
        #expect(h.noteStore.notes.isEmpty)
    }

    @Test("T22: every cycle gets its own snooze; none while the skip confirmation is open")
    func postponeOncePerCycle() {
        let h = SessionHarness(workMinutes: 10, breakMinutes: 1)
        h.controller.send(.start)
        h.advance(minutes: 10)
        h.controller.postponeBreak()
        h.advance(minutes: 5)
        h.controller.skipNote()
        h.advance(minutes: 1)
        h.controller.send(.letsGo)
        #expect(!h.controller.hasPostponedBreak)

        h.advance(minutes: 10)
        h.controller.skipNote()
        h.controller.requestSkipBreak()
        #expect(!h.controller.canPostponeBreak)
        h.controller.postponeBreak()
        #expect(h.controller.state == .onBreak)
        h.controller.cancelSkipBreak()
        #expect(h.controller.canPostponeBreak)
    }

    // MARK: - Derived values

    @Test("Work end time and break progress")
    func derivedValues() {
        let h = SessionHarness()
        h.controller.send(.start)
        #expect(h.controller.workEndsAt == h.clock.now.addingTimeInterval(50 * 60))
        h.advance(minutes: 45)
        h.saveNoteAndTakeBreak("")
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
