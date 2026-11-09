import Foundation

/// Inputs to the state machine. Comments name the spec transitions they drive.
enum SessionEvent: Equatable, Sendable {
    /// T1
    case start
    /// T2
    case warningReached
    /// T3; also the save in T8
    case saveNoteAndContinue(markdown: String)
    /// T4
    case saveNoteAndBreak(markdown: String)
    /// T5, T6
    case workTimeUp
    /// T7
    case takeBreakNow
    /// Opening in T8
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
