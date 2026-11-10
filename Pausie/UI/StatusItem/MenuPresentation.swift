import Foundation

/// What the status item and its menu show for a session snapshot. Pure, so it is unit-tested.
struct MenuPresentation: Equatable {
    enum Row: Equatable {
        case start
        case stop
        case writeNote
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
    let header: Header
    let rows: [Row]

    struct Snapshot: Equatable {
        var state: SessionState
        var workRemaining: TimeInterval?
        var workEndsAt: Date?
        var workProgress: Double?
        var breakRemaining: TimeInterval?
        var breakEndsAt: Date?
    }

    init(_ snapshot: Snapshot) {
        title = Self.makeTitle(snapshot)
        header = Self.makeHeader(snapshot)
        rows = Self.makeRows(for: snapshot.state)
    }

    @MainActor
    init(session: SessionController) {
        self.init(Snapshot(
            state: session.state,
            workRemaining: session.workRemaining,
            workEndsAt: session.workEndsAt,
            workProgress: session.workProgress,
            breakRemaining: session.breakRemaining,
            breakEndsAt: session.breakEndsAt
        ))
    }

    // MARK: - Title

    /// Icon only in `idle`; `mm:ss` while working or on break; "Break" while the note is required; `00:00` when over.
    static func makeTitle(_ snapshot: Snapshot) -> String? {
        switch snapshot.state {
        case .idle:
            nil
        case .working, .preBreakPending, .preBreakSnoozed:
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

    static func makeRows(for state: SessionState) -> [Row] {
        let common: [Row] = [.recentNotes, .settings]
        switch state {
        case .idle:
            return [.separator, .start, .separator] + common + [.separator, .quit]
        case .working, .preBreakPending:
            return [.separator] + common + [.separator, .stop, .separator, .quit]
        case .preBreakSnoozed:
            return [.separator, .writeNote, .separator] + common + [.separator, .stop, .separator, .quit]
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
