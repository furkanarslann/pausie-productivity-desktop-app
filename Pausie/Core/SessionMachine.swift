import Foundation

/// The result of a handled event.
struct SessionTransition: Equatable, Sendable {
    let state: SessionState
    let effects: [SessionEffect]
}

/// Pure reducer: `(state, event) -> (state, [effect])`. It never touches UI, timers or disk.
/// Pairs not listed return `nil` and are ignored.
///
/// Transition numbers follow the spec, with these changes: the note window no longer offers an early
/// break (T4 removed; "Save" is T3), "Ask me later" and its reminders are T14 and T15, and notes typed so
/// far are saved when work time runs out (T5, T6) or the break is taken from the menu (T7).
enum SessionMachine {
    static func reduce(_ state: SessionState, _ event: SessionEvent) -> SessionTransition? {
        switch (state, event) {
        // T1
        case (.idle, .start):
            return SessionTransition(state: .working, effects: [.startCycle])

        // T2
        case (.working, .warningReached):
            return SessionTransition(state: .preBreakPending, effects: [.closeResumePanel, .openNoteWindow(.pending)])

        // T3 (save), T8 (save after "Edit note"): keep working; the break starts on time.
        case let (.preBreakPending, .saveNote(markdown)), let (.preBreakNoted, .saveNote(markdown)):
            return SessionTransition(state: .preBreakNoted, effects: [.persistNote(markdown), .closeNoteWindow])

        // T14
        case (.preBreakPending, .askLater):
            return SessionTransition(state: .preBreakSnoozed, effects: [.closeNoteWindow, .scheduleNoteReminder])

        // T15
        case (.preBreakSnoozed, .noteReminder):
            return SessionTransition(state: .preBreakPending, effects: [.openNoteWindow(.pending)])

        // T5: notes typed so far are never lost. With text they are saved and the break starts; an empty
        // draft means the user hasn't answered yet, so the break screen asks (the break timer waits, rule 1).
        case let (.preBreakPending, .workTimeUp(draft)), let (.preBreakSnoozed, .workTimeUp(draft)):
            if TodoMarkdown.hasContent(draft) {
                return startBreak(saving: draft)
            }
            return SessionTransition(state: .breakNoteRequired, effects: [.closeNoteWindow, .showBreakOverlay(.noteRequired)])

        // T6 (time up), T7 ("Take a break now"): the note is already saved; unsaved edits from an open
        // "Edit note" window are saved too.
        case let (.preBreakNoted, .workTimeUp(draft)), let (.preBreakNoted, .takeBreakNow(draft)):
            return startBreak(saving: draft)

        // T8: open
        case (.preBreakNoted, .editNote):
            return SessionTransition(state: .preBreakNoted, effects: [.openNoteWindow(.edit)])

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
        case (.working, .stop), (.preBreakPending, .stop), (.preBreakSnoozed, .stop), (.preBreakNoted, .stop):
            return SessionTransition(state: .idle, effects: [.stopTimers, .closeNoteWindow])

        default:
            return nil
        }
    }

    /// Every path into a break saves a note first (rule 4); the break timer starts after the save (rule 1).
    private static func startBreak(saving markdown: String) -> SessionTransition {
        SessionTransition(state: .onBreak, effects: [
            .persistNote(markdown), .closeNoteWindow, .showBreakOverlay(.running), .startBreakTimer,
        ])
    }
}
