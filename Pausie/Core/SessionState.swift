import Foundation

/// The seven states of the spec's state machine.
enum SessionState: Equatable, Sendable {
    /// App open, no timer running.
    case idle
    /// New cycle, work timer running.
    case working
    /// 5 min or less left, no note yet, note window open.
    case preBreakPending
    /// Note saved within the last 5 min.
    case preBreakNoted
    /// Work time ended without a note; break timer not started.
    case breakNoteRequired
    /// Break timer running.
    case onBreak
    /// Break ended, chime for at most 60 s.
    case breakOver

    /// States in which the work timer counts down.
    var isWorkPhase: Bool {
        switch self {
        case .working, .preBreakPending, .preBreakNoted: true
        default: false
        }
    }

    /// States in which the break layer is on screen.
    var isBreakPhase: Bool {
        switch self {
        case .breakNoteRequired, .onBreak, .breakOver: true
        default: false
        }
    }
}

/// Fixed rules from the spec.
enum SessionRules {
    /// The note window opens this many minutes before the work time ends (`warningLead`).
    static let warningLeadMinutes = 5
    static var warningLead: TimeInterval { TimeInterval(warningLeadMinutes * 60) }
    /// The break-over chime stops after this long (rule 3).
    static let chimeMaxDuration: TimeInterval = 60
    /// The chime repeats at this interval while it plays.
    static let chimeRepeatInterval: TimeInterval = 10
    /// The resume ("Welcome back!") panel closes itself after this long; the note stays in Recent notes.
    /// The countdown pauses while the pointer is over the panel.
    static let resumePanelAutoCloseDelay: TimeInterval = 15
    /// How long "Copied!" stays visible in the resume panel.
    static let copiedFeedbackDuration: TimeInterval = 1.5
}
