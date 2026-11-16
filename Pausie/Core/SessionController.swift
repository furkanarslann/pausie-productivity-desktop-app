import Foundation
import Observation
import os

/// UI side of the effects. Implemented by the app coordinator, which owns the window controllers.
@MainActor
protocol SessionPresenting: AnyObject {
    func openNoteWindow(mode: NoteWindowMode)
    func closeNoteWindow()
    func showBreakOverlay(mode: BreakOverlayMode)
    func hideBreakOverlay()
    func showResumePanel(note: Note)
    func closeResumePanel()
}

@MainActor
protocol ChimePlaying: AnyObject {
    func play()
    func stop()
}

/// Why the work timer is paused: sleep and screen lock (rule 8) or the menu's Pause (T16).
/// The timer runs again only when every reason is gone.
enum PauseReason: Hashable, Sendable {
    case sleep
    case screenLocked
    case user
}

/// Owns the timers, asks `SessionMachine` what to do and applies the returned effects.
/// Views and window controllers only send events here; they make no decisions.
@MainActor
@Observable
final class SessionController {
    private(set) var state: SessionState = .idle
    /// Refreshed every tick; views read it to update countdowns.
    private(set) var now: Date
    /// The note being written in this cycle. Shared by the note window and the required-note editor;
    /// it survives "Ask me later" and is saved automatically when work time runs out (T5, T6).
    var draft: String = TodoMarkdown.template
    /// The note saved in this cycle, if any. Saving again updates the same record.
    private(set) var currentNote: Note?
    /// False during a break whose note was skipped (T19, T21): the break cards don't mention a note.
    var hasNoteThisCycle: Bool { currentNote != nil }
    /// Settings copied at the start of the cycle; changes made mid-cycle apply from the next one (rule 11).
    private(set) var cycleSettings: Settings
    /// "Skip break…" confirmation shown on top of the break card.
    private(set) var isSkipConfirmationPresented = false

    private(set) var workDeadline: Date?
    private(set) var pausedWorkRemaining: TimeInterval?
    private(set) var breakDeadline: Date?
    private(set) var pauseReasons: Set<PauseReason> = []
    /// After "Ask me later": the note window comes back when this much work time is left.
    private(set) var noteReminderAt: TimeInterval?
    /// "Snooze for 5 min" was used in this cycle (T22); it can be used once.
    private(set) var hasPostponedBreak = false

    @ObservationIgnored weak var presenter: SessionPresenting?
    @ObservationIgnored private let clock: SessionClock
    @ObservationIgnored private let settingsProvider: @MainActor () -> Settings
    @ObservationIgnored private let noteStore: NoteStore
    @ObservationIgnored private let chime: ChimePlaying
    @ObservationIgnored private let autoTick: Bool
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private let logger = Logger(subsystem: "com.furkanarslan.Pausie", category: "Session")

    init(
        clock: SessionClock = SystemClock(),
        settings: @escaping @MainActor () -> Settings,
        noteStore: NoteStore,
        chime: ChimePlaying,
        autoTick: Bool = true
    ) {
        self.clock = clock
        self.settingsProvider = settings
        self.noteStore = noteStore
        self.chime = chime
        self.autoTick = autoTick
        now = clock.now
        cycleSettings = settings()
    }

    // MARK: - Derived values

    var isWorkPaused: Bool { !pauseReasons.isEmpty && state.isWorkPhase }

    /// Paused from the menu (T16): the menu offers Resume and the menu bar shows a pause sign.
    var isPausedByUser: Bool { pauseReasons.contains(.user) && state.isWorkPhase }

    /// Remaining work time while a work-phase state is active.
    var workRemaining: TimeInterval? {
        guard state.isWorkPhase else { return nil }
        if let pausedWorkRemaining { return pausedWorkRemaining }
        guard let workDeadline else { return nil }
        return Self.remaining(until: workDeadline, from: now)
    }

    /// When the current work block ends (moves forward while paused).
    var workEndsAt: Date? {
        workRemaining.map { now.addingTimeInterval($0) }
    }

    /// Remaining break time while `onBreak`.
    var breakRemaining: TimeInterval? {
        guard state == .onBreak, let breakDeadline else { return nil }
        return Self.remaining(until: breakDeadline, from: now)
    }

    /// Time left, rounded to the millisecond so `Date` arithmetic noise can't turn 3000 s into 3000.0000002
    /// (which a rounded-up countdown would show as 50:01).
    static func remaining(until deadline: Date, from now: Date) -> TimeInterval {
        max(0, (deadline.timeIntervalSince(now) * 1000).rounded() / 1000)
    }

    var breakEndsAt: Date? {
        state == .onBreak ? breakDeadline : nil
    }

    /// The break cards offer "Snooze for 5 min" once per cycle (T22).
    var canPostponeBreak: Bool {
        (state == .breakNoteRequired || state == .onBreak) && !hasPostponedBreak && !isSkipConfirmationPresented
    }

    /// Elapsed share of the work block, 0...1, for the menu header progress bar.
    var workProgress: Double? {
        guard let workRemaining, cycleSettings.workDuration > 0 else { return nil }
        return min(1, max(0, 1 - workRemaining / cycleSettings.workDuration))
    }

    /// Elapsed share of the break, 0...1.
    var breakProgress: Double {
        switch state {
        case .onBreak:
            guard let breakRemaining, cycleSettings.breakDuration > 0 else { return 0 }
            return min(1, max(0, 1 - breakRemaining / cycleSettings.breakDuration))
        case .breakOver:
            return 1
        default:
            return 0
        }
    }

    // MARK: - Events

    /// Sends an event through the state machine and applies the resulting effects in order.
    func send(_ event: SessionEvent) {
        guard let transition = SessionMachine.reduce(state, event) else {
            logger.debug("Ignored event \(String(describing: event), privacy: .public) in state \(String(describing: self.state), privacy: .public)")
            return
        }
        logger.debug("\(String(describing: self.state), privacy: .public) --\(String(describing: event), privacy: .public)--> \(String(describing: transition.state), privacy: .public)")
        state = transition.state
        for effect in transition.effects {
            apply(effect)
        }
    }

    /// Called every second (and right after waking). Fires time-based events.
    func tick() {
        now = clock.now
        if state == .working, let remaining = workRemaining, remaining <= SessionRules.warningLead {
            send(.warningReached)
        }
        if state == .preBreakSnoozed, let reminder = noteReminderAt,
           let remaining = workRemaining, remaining <= reminder {
            send(.noteReminder)
        }
        if state.isWorkPhase, state != .working,
           !isWorkPaused, let remaining = workRemaining, remaining <= 0 {
            send(.workTimeUp(draft: draft))
        }
        if state == .onBreak, let remaining = breakRemaining, remaining <= 0 {
            send(.breakTimeUp)
        }
    }

    // MARK: - Pause (T16, T17)

    func pause() {
        send(.pause)
    }

    func resume() {
        send(.resume)
    }

    // MARK: - Note window

    /// "Skip note for this session" in the note window (T18) or "Skip note & start break" on the break
    /// note card (T21).
    func skipNote() {
        send(.skipNote)
    }

    /// "Ask me later" (T14).
    func askLater() {
        send(.askLater)
    }

    /// "Write note now" in the menu while snoozed (T15) or after skipping the note (T20).
    func writeNoteNow() {
        send(.noteReminder)
    }

    /// "Take a break now" in the menu after saving (T7) or skipping (T19) the note.
    func takeBreakNow() {
        send(.takeBreakNow(draft: draft))
    }

    /// "Edit note" in the menu after saving (T8).
    func editNote() {
        send(.editNote)
    }

    // MARK: - Snooze the break (T22)

    /// "Snooze for 5 min" on a break card: 5 more minutes of work, then the break starts again.
    func postponeBreak() {
        guard canPostponeBreak else { return }
        send(.postponeBreak(noteSkipped: !hasNoteThisCycle))
    }

    // MARK: - Skip break (T12)

    /// "Skip break…" in the menu: asks for confirmation first.
    func requestSkipBreak() {
        guard state == .onBreak else { return }
        isSkipConfirmationPresented = true
    }

    /// "Keep resting".
    func cancelSkipBreak() {
        isSkipConfirmationPresented = false
    }

    /// "Skip break" in the confirmation.
    func confirmSkipBreak() {
        guard isSkipConfirmationPresented else { return }
        isSkipConfirmationPresented = false
        send(.skipBreakConfirmed)
    }

    // MARK: - Sleep and lock (rule 8)

    /// The work timer freezes; the break timer keeps running.
    func systemPaused(_ reason: PauseReason) {
        addPause(reason)
    }

    /// Sets a new work end time; if the break ended while away, "Break's over" opens right away.
    func systemResumed(_ reason: PauseReason) {
        if removePause(reason) { tick() }
    }

    /// The first reason freezes the work timer at the time left.
    private func addPause(_ reason: PauseReason) {
        let wasPaused = !pauseReasons.isEmpty
        pauseReasons.insert(reason)
        guard !wasPaused else { return }
        now = clock.now
        if state.isWorkPhase, let workDeadline {
            pausedWorkRemaining = Self.remaining(until: workDeadline, from: now)
            self.workDeadline = nil
        }
    }

    /// Removing the last reason sets a new work end time. Returns whether the timer runs again.
    @discardableResult
    private func removePause(_ reason: PauseReason) -> Bool {
        guard pauseReasons.remove(reason) != nil, pauseReasons.isEmpty else { return false }
        now = clock.now
        if let pausedWorkRemaining {
            workDeadline = now.addingTimeInterval(pausedWorkRemaining)
            self.pausedWorkRemaining = nil
        }
        return true
    }

    // MARK: - Effects

    private func apply(_ effect: SessionEffect) {
        switch effect {
        case .startCycle:
            now = clock.now
            pauseReasons.remove(.user)
            cycleSettings = settingsProvider()
            breakDeadline = nil
            if pauseReasons.isEmpty {
                workDeadline = now.addingTimeInterval(cycleSettings.workDuration)
                pausedWorkRemaining = nil
            } else {
                workDeadline = nil
                pausedWorkRemaining = cycleSettings.workDuration
            }
            draft = TodoMarkdown.template
            currentNote = nil
            noteReminderAt = nil
            hasPostponedBreak = false
            isSkipConfirmationPresented = false
            startTicking()

        case .startBreakTimer:
            now = clock.now
            breakDeadline = now.addingTimeInterval(cycleSettings.breakDuration)
            workDeadline = nil
            pausedWorkRemaining = nil
            // A pause from the menu belongs to the work block it was made in.
            pauseReasons.remove(.user)

        case .stopTimers:
            workDeadline = nil
            pausedWorkRemaining = nil
            breakDeadline = nil
            pauseReasons.remove(.user)
            draft = TodoMarkdown.template
            currentNote = nil
            noteReminderAt = nil
            hasPostponedBreak = false
            stopTicking()

        case .pauseWorkTimer:
            addPause(.user)

        case .resumeWorkTimer:
            removePause(.user)

        case let .openNoteWindow(mode):
            noteReminderAt = nil
            if mode == .edit {
                let saved = currentNote?.markdown ?? ""
                draft = saved.isEmpty ? TodoMarkdown.template : saved
            }
            presenter?.openNoteWindow(mode: mode)

        case .scheduleNoteReminder:
            // The first reminder still ahead (with a little gap); none left means the next prompt is at time up.
            let remaining = workRemaining ?? 0
            noteReminderAt = SessionRules.noteReminderLeads.first { $0 < remaining - SessionRules.noteReminderMinimumGap }

        case .closeNoteWindow:
            presenter?.closeNoteWindow()

        case let .showBreakOverlay(mode):
            if mode != .running { isSkipConfirmationPresented = false }
            presenter?.showBreakOverlay(mode: mode)

        case .hideBreakOverlay:
            isSkipConfirmationPresented = false
            presenter?.hideBreakOverlay()

        case let .persistNote(markdown):
            let date = clock.now
            let normalized = TodoMarkdown.normalizedForSave(markdown)
            // Saving the same text again (e.g. at time up after "Save") keeps the original save time.
            if let currentNote, currentNote.markdown == normalized { break }
            var note = currentNote ?? Note(id: UUID(), markdown: normalized, createdAt: date, updatedAt: date)
            note.markdown = normalized
            note.updatedAt = date
            noteStore.upsert(note)
            currentNote = note
            // The draft now matches what was saved, so a later save of it (time up, T7) changes nothing.
            draft = note.markdown.isEmpty ? TodoMarkdown.template : note.markdown

        case .playChime:
            chime.play()

        case .stopChime:
            chime.stop()

        case .showResumePanel:
            // Only this cycle's note; after a skipped note (T19, T21) there is nothing to show.
            if let currentNote {
                presenter?.showResumePanel(note: currentNote)
            }

        case .closeResumePanel:
            presenter?.closeResumePanel()

        case .postponeBreak:
            now = clock.now
            hasPostponedBreak = true
            breakDeadline = nil
            // No "Ask me later" reminders during the 5 min: with no note yet, the break screen asks at time up.
            noteReminderAt = nil
            if pauseReasons.isEmpty {
                workDeadline = now.addingTimeInterval(SessionRules.breakPostpone)
                pausedWorkRemaining = nil
            } else {
                workDeadline = nil
                pausedWorkRemaining = SessionRules.breakPostpone
            }
        }
    }

    // MARK: - Ticker

    private func startTicking() {
        guard autoTick, ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        // `.common` keeps the countdown moving while the status menu is open.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}
