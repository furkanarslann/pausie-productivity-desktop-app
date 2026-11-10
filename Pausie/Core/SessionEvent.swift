import Foundation

/// Inputs to the state machine. Comments name the transitions they drive.
enum SessionEvent: Equatable, Sendable {
    /// T1
    case start
    /// T2: 5 min left, the note window opens.
    case warningReached
    /// T4: save the note and start the break now.
    case saveNoteAndBreak(markdown: String)
    /// T14: "Ask me later" closes the note window; it comes back at 3 and 1 min left.
    case askLater
    /// T15: a reminder (3 or 1 min left) or "Write note now" in the menu reopens the note window.
    case noteReminder
    /// T5: work time is over. A draft with text is saved and the break starts; otherwise the
    /// break screen asks for the note first.
    case workTimeUp(draft: String)
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
