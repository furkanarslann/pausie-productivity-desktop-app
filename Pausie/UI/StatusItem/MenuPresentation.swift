import Foundation

/// What the status item and its menu show for a session snapshot. Pure, so it is unit-tested.
struct MenuPresentation: Equatable {
    enum Row: Equatable {
        case start
        case pause
        case resume
        case stop
        case writeNote
        case takeBreakNow
        case editNote
        case skipBreak
        case recentNotes
        case settings
        case quit
        case separator
    }

    struct Header: Equatable {
        let pose: PausiePose
        let title: String
        let subtitle: String
        /// Elapsed share of the work block; `nil` hides the progress bar.
        let progress: Double?
    }

    /// Menu bar title next to the icon. `nil` = icon only.
    let title: String?
    /// Paused from the menu (T16): the menu bar shows a pause sign before the countdown.
    let isPaused: Bool
    let header: Header
    let rows: [Row]

    struct Snapshot: Equatable {
        var state: SessionState
        var workRemaining: TimeInterval?
        var workEndsAt: Date?
        var workProgress: Double?
        var breakRemaining: TimeInterval?
        var breakEndsAt: Date?
        /// Paused from the menu; only meaningful in work states.
        var isPaused = false
    }

    init(_ snapshot: Snapshot) {
        title = Self.makeTitle(snapshot)
        isPaused = snapshot.isPaused && snapshot.state.isWorkPhase
        header = Self.makeHeader(snapshot)
        rows = Self.makeRows(for: snapshot.state, isPaused: isPaused)
    }

    @MainActor
    init(session: SessionController) {
        self.init(Snapshot(
            state: session.state,
            workRemaining: session.workRemaining,
            workEndsAt: session.workEndsAt,
            workProgress: session.workProgress,
            breakRemaining: session.breakRemaining,
            breakEndsAt: session.breakEndsAt,
            isPaused: session.isPausedByUser
        ))
    }

    /// What VoiceOver reads for the status item.
    var accessibilityValue: String? {
        guard isPaused, let title else { return title }
        return L10n.t(.menubarAccessibilityPaused, ["remaining": title])
    }

    // MARK: - Title

    /// Icon only in `idle`; `mm:ss` while working or on break; "Break" while the note is required; `00:00` when over.
    static func makeTitle(_ snapshot: Snapshot) -> String? {
        switch snapshot.state {
        case .idle:
            nil
        case .working, .preBreakPending, .preBreakSnoozed, .preBreakNoted, .preBreakSkipped:
            snapshot.workRemaining.map(TimeFormat.countdown)
        case .breakNoteRequired:
            L10n.t(.menubarTitleBreak)
        case .onBreak:
            snapshot.breakRemaining.map(TimeFormat.countdown)
        case .breakOver:
            TimeFormat.countdown(0)
        }
    }

    // MARK: - Header

    static func makeHeader(_ snapshot: Snapshot) -> Header {
        let remaining = TimeFormat.countdown(snapshot.workRemaining ?? 0)
        let workEnd = snapshot.workEndsAt.map(TimeFormat.clockTime) ?? ""
        // Paused from the menu: the break time isn't known until Resume, so only the time left is shown.
        if snapshot.isPaused, snapshot.state.isWorkPhase {
            return Header(
                pose: .sleepy,
                title: L10n.t(.menuHeaderPausedTitle),
                subtitle: L10n.t(.menuHeaderPausedSubtitle, ["remaining": remaining]),
                progress: snapshot.workProgress ?? 0
            )
        }
        switch snapshot.state {
        case .idle:
            return Header(
                pose: .sleepy,
                title: L10n.t(.menuHeaderIdleTitle),
                subtitle: L10n.t(.menuHeaderIdleSubtitle),
                progress: nil
            )
        case .working, .preBreakPending, .preBreakSnoozed:
            return Header(
                pose: .focused,
                title: L10n.t(.menuHeaderWorkingTitle),
                subtitle: L10n.t(.menuHeaderWorkingSubtitle, ["remaining": remaining, "time": workEnd]),
                progress: snapshot.workProgress ?? 0
            )
        case .preBreakNoted:
            return Header(
                pose: .takingNotes,
                title: L10n.t(.menuHeaderNotedTitle),
                subtitle: L10n.t(.menuHeaderNotedSubtitle, ["remaining": remaining]),
                progress: snapshot.workProgress ?? 0
            )
        case .preBreakSkipped:
            return Header(
                pose: .focused,
                title: L10n.t(.menuHeaderSkippedTitle),
                subtitle: L10n.t(.menuHeaderSkippedSubtitle, ["remaining": remaining]),
                progress: snapshot.workProgress ?? 0
            )
        case .breakNoteRequired:
            return Header(
                pose: .takingNotes,
                title: L10n.t(.menuHeaderNoteRequiredTitle),
                subtitle: L10n.t(.menuHeaderNoteRequiredSubtitle),
                progress: nil
            )
        case .onBreak:
            return Header(
                pose: .breakTime,
                title: L10n.t(.menuHeaderBreakTitle),
                subtitle: L10n.t(.menuHeaderBreakSubtitle, [
                    "remaining": TimeFormat.countdown(snapshot.breakRemaining ?? 0),
                    "time": snapshot.breakEndsAt.map(TimeFormat.clockTime) ?? "",
                ]),
                progress: nil
            )
        case .breakOver:
            return Header(
                pose: .backToWork,
                title: L10n.t(.menuHeaderBreakOverTitle),
                subtitle: L10n.t(.menuHeaderBreakOverSubtitle),
                progress: nil
            )
        }
    }

    // MARK: - Rows (screen 01)

    /// In work states Pause (or Resume) is the first row, where idle has "Start focus session".
    static func makeRows(for state: SessionState, isPaused: Bool = false) -> [Row] {
        let common: [Row] = [.recentNotes, .settings]
        let pauseRow: Row = isPaused ? .resume : .pause
        let workTail: [Row] = [.separator] + common + [.separator, .stop, .separator, .quit]
        switch state {
        case .idle:
            return [.separator, .start, .separator] + common + [.separator, .quit]
        case .working, .preBreakPending:
            return [.separator, pauseRow] + workTail
        case .preBreakSnoozed:
            return [.separator, pauseRow, .writeNote] + workTail
        case .preBreakNoted:
            return [.separator, pauseRow, .takeBreakNow, .editNote] + workTail
        case .preBreakSkipped:
            return [.separator, pauseRow, .takeBreakNow, .writeNote] + workTail
        case .onBreak:
            return [.separator, .skipBreak, .separator] + common + [.separator, .quit]
        case .breakNoteRequired, .breakOver:
            return [.separator] + common + [.separator, .quit]
        }
    }

    // MARK: - Recent notes (screen 02)

    /// Label for a note in the Recent notes submenu: its first non-empty line, without the todo marker.
    static func recentNoteLabel(_ note: Note) -> String {
        for line in TodoMarkdown.parse(note.markdown) {
            let text: String
            switch line {
            case let .todo(value, _): text = value
            case let .text(value): text = value.trimmingCharacters(in: .whitespaces)
            }
            if !text.isEmpty { return text }
        }
        return L10n.t(.menuRecentNotesEmptyNote)
    }
}
