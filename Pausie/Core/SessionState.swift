import Foundation

/// The seven states of the spec's state machine.
enum SessionState: Equatable, Sendable {
    /// App open, no timer running.
    case idle
    /// New cycle, work timer running.
    case working
    /// 5 min or less left, no note yet, note window open.
    case preBreakPending
    /// "Ask me later": note window closed, it reopens at 3 and 1 min left.
    case preBreakSnoozed
    /// Work time ended without a note; break timer not started.
    case breakNoteRequired
    /// Break timer running.
    case onBreak
    /// Break ended, chime for at most 60 s.
    case breakOver

    /// States in which the work timer counts down.
    var isWorkPhase: Bool {
        switch self {
        case .working, .preBreakPending, .preBreakSnoozed: true
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
    /// "Ask me later" brings the note window back when this much work time is left (then at time up).
    static let noteReminderLeads: [TimeInterval] = [3 * 60, 1 * 60]
    /// A reminder closer than this to the moment "Ask me later" was pressed is skipped.
    static let noteReminderMinimumGap: TimeInterval = 10
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
