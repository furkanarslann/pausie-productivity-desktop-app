import Foundation

/// Inputs to the state machine. Comments name the transitions they drive.
enum SessionEvent: Equatable, Sendable {
    /// T1
    case start
    /// T2: 5 min left, the note window opens.
    case warningReached
    /// T3: "Save" in the note window; keep working until the break. Also the save in T8 ("Edit note").
    case saveNote(markdown: String)
    /// T14: "Ask me later" closes the note window; it comes back at 3 and 1 min left.
    case askLater
    /// T15: a reminder (3 or 1 min left) or "Write note now" in the menu reopens the note window.
    case noteReminder
    /// T5, T6: work time is over. Notes typed so far are saved and the break starts; with nothing
    /// written yet, the break screen asks for the note first.
    case workTimeUp(draft: String)
    /// T7: "Take a break now" in the menu after the note was saved; unsaved edits are kept.
    case takeBreakNow(draft: String)
    /// T8: "Edit note" in the menu reopens the saved note.
    case editNote
    /// T9
    case saveRequiredNote(markdown: String)
    /// T10
    case breakTimeUp
    /// T11
    case letsGo
    /// T12
    case skipBreakConfirmed
    /// T13
    case stop
}
