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

/// Why the work timer is paused (spec rule 5).
enum PauseReason: Hashable, Sendable {
    case sleep
    case screenLocked
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
        if state == .preBreakPending || state == .preBreakSnoozed || state == .preBreakNoted,
           !isWorkPaused, let remaining = workRemaining, remaining <= 0 {
            send(.workTimeUp(draft: draft))
        }
        if state == .onBreak, let remaining = breakRemaining, remaining <= 0 {
            send(.breakTimeUp)
        }
    }

    // MARK: - Note window

    /// "Ask me later" (T14).
    func askLater() {
        send(.askLater)
    }

    /// "Write note now" in the menu while snoozed (T15).
    func writeNoteNow() {
        send(.noteReminder)
    }

    /// "Take a break now" in the menu after saving (T7).
    func takeBreakNow() {
        send(.takeBreakNow(draft: draft))
    }

    /// "Edit note" in the menu after saving (T8).
    func editNote() {
        send(.editNote)
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

    // MARK: - Sleep and lock (rule 5)

    /// The work timer freezes; the break timer keeps running.
    func systemPaused(_ reason: PauseReason) {
        let wasPaused = !pauseReasons.isEmpty
        pauseReasons.insert(reason)
        guard !wasPaused else { return }
        now = clock.now
        if state.isWorkPhase, let workDeadline {
            pausedWorkRemaining = Self.remaining(until: workDeadline, from: now)
            self.workDeadline = nil
        }
    }

    /// Sets a new work end time; if the break ended while away, "Break's over" opens right away.
    func systemResumed(_ reason: PauseReason) {
        guard pauseReasons.remove(reason) != nil, pauseReasons.isEmpty else { return }
        now = clock.now
        if let pausedWorkRemaining {
            workDeadline = now.addingTimeInterval(pausedWorkRemaining)
            self.pausedWorkRemaining = nil
        }
        tick()
    }

    // MARK: - Effects

    private func apply(_ effect: SessionEffect) {
        switch effect {
        case .startCycle:
            now = clock.now
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
            isSkipConfirmationPresented = false
            startTicking()

        case .startBreakTimer:
            now = clock.now
            breakDeadline = now.addingTimeInterval(cycleSettings.breakDuration)
            workDeadline = nil
            pausedWorkRemaining = nil

        case .stopTimers:
            workDeadline = nil
            pausedWorkRemaining = nil
            breakDeadline = nil
            draft = TodoMarkdown.template
            currentNote = nil
            noteReminderAt = nil
            stopTicking()

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
            if let note = currentNote ?? noteStore.latest {
                presenter?.showResumePanel(note: note)
            }

        case .closeResumePanel:
            presenter?.closeResumePanel()
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
