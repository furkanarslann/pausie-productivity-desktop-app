import Foundation

enum NoteWindowMode: Equatable, Sendable {
    /// T2, T15: "Ask me later" and "Save".
    case pending
    /// T8: the saved note, "Save" only.
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
    /// The menu's Pause (T16): freeze the work timer until Resume.
    case pauseWorkTimer
    /// The menu's Resume (T17).
    case resumeWorkTimer
    case openNoteWindow(NoteWindowMode)
    case closeNoteWindow
    /// Pick the next "Ask me later" reminder (3 or 1 min left) after the time left now.
    case scheduleNoteReminder
    case showBreakOverlay(BreakOverlayMode)
    case hideBreakOverlay
    /// Saving again in the same cycle updates the same record; saving identical text changes nothing.
    case persistNote(String)
    case playChime
    case stopChime
    case showResumePanel
    case closeResumePanel
    /// "Snooze for 5 min" (T22): clear the break timer and give `SessionRules.breakPostpone` more work time;
    /// it can't be used again this cycle.
    case postponeBreak
}
