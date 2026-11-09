import Foundation

/// The result of a handled event.
struct SessionTransition: Equatable, Sendable {
    let state: SessionState
    let effects: [SessionEffect]
}

/// Pure reducer: `(state, event) -> (state, [effect])`. It never touches UI, timers or disk.
/// Every row maps to a spec transition (T1-T13). Pairs not listed return `nil` and are ignored.
enum SessionMachine {
    static func reduce(_ state: SessionState, _ event: SessionEvent) -> SessionTransition? {
        switch (state, event) {
        // T1
        case (.idle, .start):
            return SessionTransition(state: .working, effects: [.startCycle])

        // T2
        case (.working, .warningReached):
            return SessionTransition(state: .preBreakPending, effects: [.closeResumePanel, .openNoteWindow(.pending)])

        // T3
        case let (.preBreakPending, .saveNoteAndContinue(markdown)):
            return SessionTransition(state: .preBreakNoted, effects: [.persistNote(markdown), .closeNoteWindow])

        // T4
        case let (.preBreakPending, .saveNoteAndBreak(markdown)):
            return SessionTransition(state: .onBreak, effects: [
                .persistNote(markdown), .closeNoteWindow, .showBreakOverlay(.running), .startBreakTimer,
            ])

        // T5: the unsaved draft stays in the controller and moves into the overlay editor.
        case (.preBreakPending, .workTimeUp):
            return SessionTransition(state: .breakNoteRequired, effects: [.closeNoteWindow, .showBreakOverlay(.noteRequired)])

        // T6, T7. `closeNoteWindow` also closes an open "Edit note" window (T8) so it can't sit above the break.
        case (.preBreakNoted, .workTimeUp), (.preBreakNoted, .takeBreakNow):
            return SessionTransition(state: .onBreak, effects: [
                .closeNoteWindow, .showBreakOverlay(.running), .startBreakTimer,
            ])

        // T8: open
        case (.preBreakNoted, .editNote):
            return SessionTransition(state: .preBreakNoted, effects: [.openNoteWindow(.edit)])

        // T8: save
        case let (.preBreakNoted, .saveNoteAndContinue(markdown)):
            return SessionTransition(state: .preBreakNoted, effects: [.persistNote(markdown), .closeNoteWindow])

        // T9
        case let (.breakNoteRequired, .saveRequiredNote(markdown)):
            return SessionTransition(state: .onBreak, effects: [
                .persistNote(markdown), .showBreakOverlay(.running), .startBreakTimer,
            ])

        // T10
        case (.onBreak, .breakTimeUp):
            return SessionTransition(state: .breakOver, effects: [.showBreakOverlay(.over), .playChime])

        // T11. `showResumePanel` runs before `startCycle` so it shows the note of the cycle that just ended.
        case (.breakOver, .letsGo):
            return SessionTransition(state: .working, effects: [
                .stopChime, .hideBreakOverlay, .showResumePanel, .startCycle,
            ])

        // T12
        case (.onBreak, .skipBreakConfirmed):
            return SessionTransition(state: .working, effects: [.hideBreakOverlay, .showResumePanel, .startCycle])

        // T13
        case (.working, .stop), (.preBreakPending, .stop), (.preBreakNoted, .stop):
            return SessionTransition(state: .idle, effects: [.stopTimers, .closeNoteWindow])

        default:
            return nil
        }
    }
}
