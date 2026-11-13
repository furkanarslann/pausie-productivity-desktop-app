import Testing
@testable import Pausie

/// Every row of the transition table is a test.
@Suite("SessionMachine transitions")
struct SessionMachineTests {
    private func reduce(_ state: SessionState, _ event: SessionEvent) -> SessionTransition? {
        SessionMachine.reduce(state, event)
    }

    private let breakEffects: (String) -> [SessionEffect] = { markdown in
        [.persistNote(markdown), .closeNoteWindow, .showBreakOverlay(.running), .startBreakTimer]
    }

    @Test("T1 idle --start--> working")
    func t1() {
        #expect(reduce(.idle, .start) == SessionTransition(state: .working, effects: [.startCycle]))
    }

    @Test("T2 working --warningReached--> preBreakPending")
    func t2() {
        #expect(reduce(.working, .warningReached) == SessionTransition(
            state: .preBreakPending,
            effects: [.closeResumePanel, .openNoteWindow(.pending)]
        ))
    }

    @Test("T3 preBreakPending --saveNote--> preBreakNoted: keep working")
    func t3() {
        #expect(reduce(.preBreakPending, .saveNote(markdown: "- [ ] a")) == SessionTransition(
            state: .preBreakNoted,
            effects: [.persistNote("- [ ] a"), .closeNoteWindow]
        ))
    }

    @Test("The note window offers no early break")
    func noEarlyBreakFromNoteWindow() {
        for event in [SessionEvent.saveNote(markdown: "- [ ] a"), .askLater] {
            #expect(reduce(.preBreakPending, event)?.state != .onBreak)
        }
        #expect(reduce(.preBreakPending, .takeBreakNow(draft: "- [ ] a")) == nil)
    }

    @Test("T5 with an empty draft: the break screen asks first, break timer not started", arguments: [
        SessionState.preBreakPending, .preBreakSnoozed,
    ])
    func t5EmptyDraft(from state: SessionState) {
        for draft in ["", TodoMarkdown.template, "- [ ] \n- [ ] "] {
            let transition = reduce(state, .workTimeUp(draft: draft))
            #expect(transition == SessionTransition(
                state: .breakNoteRequired,
                effects: [.closeNoteWindow, .showBreakOverlay(.noteRequired)]
            ))
            #expect(transition?.effects.contains(.startBreakTimer) == false)
        }
    }

    @Test("T5 with notes typed: they are saved and the break starts", arguments: [
        SessionState.preBreakPending, .preBreakSnoozed,
    ])
    func t5DraftWithText(from state: SessionState) {
        let draft = "- [ ] half-written thought\n- [ ] "
        #expect(reduce(state, .workTimeUp(draft: draft)) == SessionTransition(state: .onBreak, effects: breakEffects(draft)))
    }

    @Test("T6 preBreakNoted --workTimeUp--> onBreak, saving any edits")
    func t6() {
        #expect(reduce(.preBreakNoted, .workTimeUp(draft: "- [ ] a")) == SessionTransition(state: .onBreak, effects: breakEffects("- [ ] a")))
    }

    @Test("T7 preBreakNoted --takeBreakNow--> onBreak, saving any edits")
    func t7() {
        #expect(reduce(.preBreakNoted, .takeBreakNow(draft: "- [ ] a")) == SessionTransition(state: .onBreak, effects: breakEffects("- [ ] a")))
    }

    @Test("T8 preBreakNoted --editNote, then saveNote--> preBreakNoted")
    func t8() {
        #expect(reduce(.preBreakNoted, .editNote) == SessionTransition(state: .preBreakNoted, effects: [.openNoteWindow(.edit)]))
        #expect(reduce(.preBreakNoted, .saveNote(markdown: "- [ ] b")) == SessionTransition(
            state: .preBreakNoted,
            effects: [.persistNote("- [ ] b"), .closeNoteWindow]
        ))
    }

    @Test("T9 breakNoteRequired --saveRequiredNote--> onBreak")
    func t9() {
        #expect(reduce(.breakNoteRequired, .saveRequiredNote(markdown: "")) == SessionTransition(
            state: .onBreak,
            effects: [.persistNote(""), .showBreakOverlay(.running), .startBreakTimer]
        ))
    }

    @Test("T10 onBreak --breakTimeUp--> breakOver")
    func t10() {
        #expect(reduce(.onBreak, .breakTimeUp) == SessionTransition(state: .breakOver, effects: [.showBreakOverlay(.over), .playChime]))
    }

    @Test("T11 breakOver --letsGo--> working")
    func t11() {
        #expect(reduce(.breakOver, .letsGo) == SessionTransition(
            state: .working,
            effects: [.stopChime, .hideBreakOverlay, .showResumePanel, .startCycle]
        ))
    }

    @Test("T12 onBreak --skipBreakConfirmed--> working")
    func t12() {
        #expect(reduce(.onBreak, .skipBreakConfirmed) == SessionTransition(
            state: .working,
            effects: [.hideBreakOverlay, .showResumePanel, .startCycle]
        ))
    }

    @Test("T13 stop from work states --> idle", arguments: [
        SessionState.working, .preBreakPending, .preBreakSnoozed, .preBreakNoted, .preBreakSkipped,
    ])
    func t13(from state: SessionState) {
        #expect(reduce(state, .stop) == SessionTransition(state: .idle, effects: [.stopTimers, .closeNoteWindow]))
    }

    @Test("T14 preBreakPending --askLater--> preBreakSnoozed")
    func t14() {
        #expect(reduce(.preBreakPending, .askLater) == SessionTransition(
            state: .preBreakSnoozed,
            effects: [.closeNoteWindow, .scheduleNoteReminder]
        ))
    }

    @Test("T15 preBreakSnoozed --noteReminder--> preBreakPending")
    func t15() {
        #expect(reduce(.preBreakSnoozed, .noteReminder) == SessionTransition(state: .preBreakPending, effects: [.openNoteWindow(.pending)]))
    }

    @Test("T16 pause and T17 resume keep the work state", arguments: [
        SessionState.working, .preBreakPending, .preBreakSnoozed, .preBreakNoted, .preBreakSkipped,
    ])
    func t16t17(from state: SessionState) {
        #expect(reduce(state, .pause) == SessionTransition(state: state, effects: [.pauseWorkTimer]))
        #expect(reduce(state, .resume) == SessionTransition(state: state, effects: [.resumeWorkTimer]))
    }

    @Test("Pause and resume are ignored outside work", arguments: [
        SessionState.idle, .breakNoteRequired, .onBreak, .breakOver,
    ])
    func pauseOnlyWhileWorking(in state: SessionState) {
        #expect(reduce(state, .pause) == nil)
        #expect(reduce(state, .resume) == nil)
    }

    @Test("T18 preBreakPending --skipNote--> preBreakSkipped: keep working, nothing saved")
    func t18() {
        #expect(reduce(.preBreakPending, .skipNote) == SessionTransition(state: .preBreakSkipped, effects: [.closeNoteWindow]))
    }

    @Test("T19 preBreakSkipped --workTimeUp / takeBreakNow--> onBreak without saving", arguments: [
        SessionEvent.workTimeUp(draft: "- [ ] typed before skipping"), .takeBreakNow(draft: "- [ ] typed before skipping"),
    ])
    func t19(event: SessionEvent) {
        #expect(reduce(.preBreakSkipped, event) == SessionTransition(
            state: .onBreak,
            effects: [.showBreakOverlay(.running), .startBreakTimer]
        ))
    }

    @Test("T20 preBreakSkipped --noteReminder (Write note now)--> preBreakPending")
    func t20() {
        #expect(reduce(.preBreakSkipped, .noteReminder) == SessionTransition(state: .preBreakPending, effects: [.openNoteWindow(.pending)]))
    }

    @Test("T21 breakNoteRequired --skipNote--> onBreak without saving")
    func t21() {
        #expect(reduce(.breakNoteRequired, .skipNote) == SessionTransition(
            state: .onBreak,
            effects: [.showBreakOverlay(.running), .startBreakTimer]
        ))
    }

    @Test("Skipping the note is only offered where the note is asked for", arguments: [
        SessionState.idle, .working, .preBreakSnoozed, .preBreakNoted, .preBreakSkipped, .onBreak, .breakOver,
    ])
    func skipNoteOnlyWhenAsked(in state: SessionState) {
        #expect(reduce(state, .skipNote) == nil)
    }

    // MARK: - Rules

    @Test("Rule 2: Let's go is ignored while the break is running")
    func letsGoDisabledDuringBreak() {
        #expect(reduce(.onBreak, .letsGo) == nil)
        #expect(reduce(.breakNoteRequired, .letsGo) == nil)
    }

    @Test("Stop is ignored during a break")
    func stopIgnoredDuringBreak() {
        for state in [SessionState.breakNoteRequired, .onBreak, .breakOver, .idle] {
            #expect(reduce(state, .stop) == nil)
        }
    }

    @Test("Skipping is only possible from a running break")
    func skipOnlyFromBreak() {
        for state in [SessionState.idle, .working, .preBreakPending, .preBreakSnoozed, .preBreakNoted, .breakNoteRequired, .breakOver] {
            #expect(reduce(state, .skipBreakConfirmed) == nil)
        }
    }

    @Test("Rules 1 and 4: every path into a break saves a note (unless skipped), then starts the break timer")
    func everyBreakPathSavesANote() {
        let pathsIntoBreak: [(SessionState, SessionEvent)] = [
            (.preBreakPending, .workTimeUp(draft: "- [ ] x")),
            (.preBreakSnoozed, .workTimeUp(draft: "- [ ] x")),
            (.preBreakNoted, .workTimeUp(draft: "- [ ] x")),
            (.preBreakNoted, .takeBreakNow(draft: "- [ ] x")),
            (.breakNoteRequired, .saveRequiredNote(markdown: "")),
        ]
        for (state, event) in pathsIntoBreak {
            let transition = reduce(state, event)
            #expect(transition?.state == .onBreak)
            #expect(transition?.effects.first { if case .persistNote = $0 { true } else { false } } != nil)
            #expect(transition?.effects.last == .startBreakTimer)
        }

        let skippedPaths: [(SessionState, SessionEvent)] = [
            (.preBreakSkipped, .workTimeUp(draft: "- [ ] x")),
            (.preBreakSkipped, .takeBreakNow(draft: "- [ ] x")),
            (.breakNoteRequired, .skipNote),
        ]
        for (state, event) in skippedPaths {
            let transition = reduce(state, event)
            #expect(transition?.state == .onBreak)
            #expect(transition?.effects.contains { if case .persistNote = $0 { true } else { false } } == false)
            #expect(transition?.effects.last == .startBreakTimer)
        }
    }

    @Test("Unlisted pairs are ignored")
    func unlistedPairs() {
        #expect(reduce(.idle, .warningReached) == nil)
        #expect(reduce(.idle, .workTimeUp(draft: "")) == nil)
        #expect(reduce(.working, .start) == nil)
        #expect(reduce(.working, .workTimeUp(draft: "- [ ] x")) == nil)
        #expect(reduce(.working, .askLater) == nil)
        #expect(reduce(.working, .noteReminder) == nil)
        #expect(reduce(.working, .editNote) == nil)
        #expect(reduce(.preBreakPending, .noteReminder) == nil)
        #expect(reduce(.preBreakPending, .editNote) == nil)
        #expect(reduce(.preBreakSnoozed, .askLater) == nil)
        #expect(reduce(.preBreakSnoozed, .saveNote(markdown: "")) == nil)
        #expect(reduce(.preBreakNoted, .askLater) == nil)
        #expect(reduce(.preBreakNoted, .noteReminder) == nil)
        #expect(reduce(.onBreak, .saveRequiredNote(markdown: "")) == nil)
        #expect(reduce(.breakOver, .breakTimeUp) == nil)
        #expect(reduce(.preBreakSkipped, .askLater) == nil)
        #expect(reduce(.preBreakSkipped, .saveNote(markdown: "")) == nil)
        #expect(reduce(.preBreakSkipped, .editNote) == nil)
        #expect(reduce(.preBreakSkipped, .warningReached) == nil)
    }
}
