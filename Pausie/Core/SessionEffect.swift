import Foundation

enum NoteWindowMode: Equatable, Sendable {
    /// T2: two buttons ("Save & keep working", "Save & take a break").
    case pending
    /// T8: only "Save".
    case edit
}

enum BreakOverlayMode: Equatable, Sendable {
    /// Screen 04: break layer + required-note card; break timer not started.
    case noteRequired
    /// Screen 05: break timer running, "Let's go!" disabled.
    case running
    /// Screen 07: break over, chime, "Let's go!" enabled.
    case over
}

/// Side effects returned by `SessionMachine`. `SessionController` applies them.
enum SessionEffect: Equatable, Sendable {
    /// Snapshot settings, reset the note, set the work deadline.
    case startCycle
    /// Set the break deadline.
    case startBreakTimer
    case stopTimers
    case openNoteWindow(NoteWindowMode)
    case closeNoteWindow
    case showBreakOverlay(BreakOverlayMode)
    case hideBreakOverlay
    /// Saving again in the same cycle updates the same record.
    case persistNote(String)
    case playChime
    case stopChime
    case showResumePanel
    case closeResumePanel
}
