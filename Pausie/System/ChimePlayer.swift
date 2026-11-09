import AppKit

/// Sound tokens. The MVP maps to a system sound; when a custom file arrives only this mapping changes.
enum SoundToken {
    case breakOver

    var sound: NSSound? {
        switch self {
        case .breakOver: NSSound(named: NSSound.Name("Glass"))
        }
    }
}

/// Plays the break-over chime every `chimeRepeatInterval` and stops after `chimeMaxDuration` (spec rule 3)
/// or when "Let's go!" is pressed.
@MainActor
final class ChimePlayer: ChimePlaying {
    private let token: SoundToken
    private var sound: NSSound?
    private var repeatTimer: Timer?
    private var stopTimer: Timer?

    init(token: SoundToken = .breakOver) {
        self.token = token
    }

    private(set) var isPlaying = false

    func play() {
        stop()
        isPlaying = true
        sound = token.sound
        ring()

        let repeatTimer = Timer(timeInterval: SessionRules.chimeRepeatInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.ring() }
        }
        let stopTimer = Timer(timeInterval: SessionRules.chimeMaxDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
        RunLoop.main.add(repeatTimer, forMode: .common)
        RunLoop.main.add(stopTimer, forMode: .common)
        self.repeatTimer = repeatTimer
        self.stopTimer = stopTimer
    }

    func stop() {
        repeatTimer?.invalidate()
        stopTimer?.invalidate()
        repeatTimer = nil
        stopTimer = nil
        sound?.stop()
        sound = nil
        isPlaying = false
    }

    private func ring() {
        guard let sound else { return }
        sound.stop()
        sound.play()
    }
}
