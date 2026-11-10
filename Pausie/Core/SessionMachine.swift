import Foundation

/// The result of a handled event.
struct SessionTransition: Equatable, Sendable {
    let state: SessionState
    let effects: [SessionEffect]
}

/// Pure reducer: `(state, event) -> (state, [effect])`. It never touches UI, timers or disk.
/// Pairs not listed return `nil` and are ignored.
///
/// Transition numbers follow the spec. T3, T6, T7 and T8 ("Save & keep working", the noted state, "Take a
/// break now", "Edit note") were removed; T14 and T15 ("Ask me later" and its reminders) were added, and T5
/// now saves a draft that has text instead of always asking.
enum SessionMachine {
    static func reduce(_ state: SessionState, _ event: SessionEvent) -> SessionTransition? {
        switch (state, event) {
        // T1
        case (.idle, .start):
            return SessionTransition(state: .working, effects: [.startCycle])

        // T2
        case (.working, .warningReached):
            return SessionTransition(state: .preBreakPending, effects: [.closeResumePanel, .openNoteWindow])

        // T4
        case let (.preBreakPending, .saveNoteAndBreak(markdown)):
            return startBreak(saving: markdown)

        // T14
        case (.preBreakPending, .askLater):
            return SessionTransition(state: .preBreakSnoozed, effects: [.closeNoteWindow, .scheduleNoteReminder])

        // T15
        case (.preBreakSnoozed, .noteReminder):
            return SessionTransition(state: .preBreakPending, effects: [.openNoteWindow])

        // T5: notes typed so far are never lost. With text they are saved and the break starts; an empty
        // draft means the user hasn't answered yet, so the break screen asks (the break timer waits, rule 1).
        case let (.preBreakPending, .workTimeUp(draft)), let (.preBreakSnoozed, .workTimeUp(draft)):
            if TodoMarkdown.hasContent(draft) {
                return startBreak(saving: draft)
            }
            return SessionTransition(state: .breakNoteRequired, effects: [.closeNoteWindow, .showBreakOverlay(.noteRequired)])

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
        case (.working, .stop), (.preBreakPending, .stop), (.preBreakSnoozed, .stop):
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
