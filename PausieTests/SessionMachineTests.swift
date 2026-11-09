import Testing
@testable import Pausie

/// Every row of the transition table (T1-T13) is a test.
@Suite("SessionMachine transitions")
struct SessionMachineTests {
    private func reduce(_ state: SessionState, _ event: SessionEvent) -> SessionTransition? {
        SessionMachine.reduce(state, event)
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

    @Test("T3 preBreakPending --saveNoteAndContinue--> preBreakNoted")
    func t3() {
        #expect(reduce(.preBreakPending, .saveNoteAndContinue(markdown: "- [ ] a")) == SessionTransition(
            state: .preBreakNoted,
            effects: [.persistNote("- [ ] a"), .closeNoteWindow]
        ))
    }

    @Test("T4 preBreakPending --saveNoteAndBreak--> onBreak")
    func t4() {
        #expect(reduce(.preBreakPending, .saveNoteAndBreak(markdown: "- [ ] a")) == SessionTransition(
            state: .onBreak,
            effects: [.persistNote("- [ ] a"), .closeNoteWindow, .showBreakOverlay(.running), .startBreakTimer]
        ))
    }

    @Test("T5 preBreakPending --workTimeUp--> breakNoteRequired, break timer not started")
    func t5() {
        let transition = reduce(.preBreakPending, .workTimeUp)
        #expect(transition == SessionTransition(
            state: .breakNoteRequired,
            effects: [.closeNoteWindow, .showBreakOverlay(.noteRequired)]
        ))
        #expect(transition?.effects.contains(.startBreakTimer) == false)
    }

    @Test("T6 preBreakNoted --workTimeUp--> onBreak")
    func t6() {
        #expect(reduce(.preBreakNoted, .workTimeUp) == SessionTransition(
            state: .onBreak,
            effects: [.closeNoteWindow, .showBreakOverlay(.running), .startBreakTimer]
        ))
    }

    @Test("T7 preBreakNoted --takeBreakNow--> onBreak")
    func t7() {
        #expect(reduce(.preBreakNoted, .takeBreakNow) == SessionTransition(
            state: .onBreak,
            effects: [.closeNoteWindow, .showBreakOverlay(.running), .startBreakTimer]
        ))
    }

    @Test("T8 preBreakNoted --editNote, then save--> preBreakNoted")
    func t8() {
        #expect(reduce(.preBreakNoted, .editNote) == SessionTransition(state: .preBreakNoted, effects: [.openNoteWindow(.edit)]))
        #expect(reduce(.preBreakNoted, .saveNoteAndContinue(markdown: "- [ ] b")) == SessionTransition(
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

    @Test("T13 stop from work states --> idle", arguments: [SessionState.working, .preBreakPending, .preBreakNoted])
    func t13(from state: SessionState) {
        #expect(reduce(state, .stop) == SessionTransition(state: .idle, effects: [.stopTimers, .closeNoteWindow]))
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
        for state in [SessionState.idle, .working, .preBreakPending, .preBreakNoted, .breakNoteRequired, .breakOver] {
            #expect(reduce(state, .skipBreakConfirmed) == nil)
        }
    }

    @Test("Rule 1/4: every path into onBreak saves a note or already has one")
    func everyBreakPathHasANote() {
        let pathsIntoBreak: [(SessionState, SessionEvent)] = [
            (.preBreakPending, .saveNoteAndBreak(markdown: "")),
            (.breakNoteRequired, .saveRequiredNote(markdown: "")),
            (.preBreakNoted, .workTimeUp),
            (.preBreakNoted, .takeBreakNow),
        ]
        for (state, event) in pathsIntoBreak {
            let transition = reduce(state, event)
            #expect(transition?.state == .onBreak)
            let savesNote = transition?.effects.contains { if case .persistNote = $0 { true } else { false } } ?? false
            #expect(savesNote || state == .preBreakNoted)
            #expect(transition?.effects.last == .startBreakTimer)
        }
        // Work time can't skip the note: without one it lands in breakNoteRequired.
        #expect(reduce(.preBreakPending, .workTimeUp)?.state == .breakNoteRequired)
    }

    @Test("Unlisted pairs are ignored")
    func unlistedPairs() {
        #expect(reduce(.idle, .warningReached) == nil)
        #expect(reduce(.idle, .workTimeUp) == nil)
        #expect(reduce(.working, .start) == nil)
        #expect(reduce(.working, .workTimeUp) == nil)
        #expect(reduce(.working, .editNote) == nil)
        #expect(reduce(.preBreakPending, .takeBreakNow) == nil)
        #expect(reduce(.preBreakPending, .editNote) == nil)
        #expect(reduce(.breakNoteRequired, .saveNoteAndContinue(markdown: "")) == nil)
        #expect(reduce(.onBreak, .saveRequiredNote(markdown: "")) == nil)
        #expect(reduce(.breakOver, .breakTimeUp) == nil)
    }
}
