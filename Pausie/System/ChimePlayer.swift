import AVFoundation
import Observation
import os

/// Plays the break-over sound picked in Settings (rule 3): a chime repeats every `chimeRepeatInterval`,
/// music plays once; both stop after `chimeMaxDuration` or when "Let's go!" is pressed.
/// Settings previews go through the same player, so two sounds never play at once.
@MainActor
@Observable
final class ChimePlayer: ChimePlaying {
    /// True while the break-over sound plays.
    private(set) var isPlaying = false
    /// The sound being previewed from Settings, if any.
    private(set) var previewing: BreakSound?

    @ObservationIgnored private let selectedSound: @MainActor () -> BreakSound
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var repeatTimer: Timer?
    @ObservationIgnored private var stopTimer: Timer?
    @ObservationIgnored private let logger = Logger(subsystem: "com.furkanarslan.Pausie", category: "Sound")

    init(sound: @escaping @MainActor () -> BreakSound = { .default }) {
        selectedSound = sound
    }

    /// The break is over: plays the selected sound.
    func play() {
        stop()
        let sound = selectedSound()
        guard let player = makePlayer(sound) else { return }
        self.player = player
        isPlaying = true
        player.play()

        if sound.kind == .chime {
            schedule(&repeatTimer, after: SessionRules.chimeRepeatInterval, repeats: true) { [weak self] in
                self?.restart()
            }
        }
        schedule(&stopTimer, after: SessionRules.chimeMaxDuration) { [weak self] in
            self?.stop()
        }
    }

    /// Plays a sound once from Settings, for at most `soundPreviewDuration`. Stops anything playing.
    func preview(_ sound: BreakSound) {
        stop()
        guard let player = makePlayer(sound) else { return }
        self.player = player
        previewing = sound
        player.play()

        let length = min(player.duration, SessionRules.soundPreviewDuration)
        schedule(&stopTimer, after: length) { [weak self] in
            self?.endPreview()
        }
    }

    /// Stops a preview; the break-over sound, if it is playing, is left alone.
    func stopPreview() {
        guard previewing != nil else { return }
        stop()
    }

    func stop() {
        repeatTimer?.invalidate()
        stopTimer?.invalidate()
        repeatTimer = nil
        stopTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        previewing = nil
    }

    // MARK: - Private

    private func makePlayer(_ sound: BreakSound) -> AVAudioPlayer? {
        guard let url = sound.url() else {
            logger.error("Missing sound file for \(sound.rawValue, privacy: .public)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            logger.error("Can't play \(sound.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func restart() {
        guard let player else { return }
        player.stop()
        player.currentTime = 0
        player.play()
    }

    /// Music that is cut short fades out instead of stopping mid-phrase.
    private func endPreview() {
        guard let player, player.isPlaying, previewing?.kind == .music else {
            stop()
            return
        }
        player.setVolume(0, fadeDuration: SessionRules.soundPreviewFadeOut)
        schedule(&stopTimer, after: SessionRules.soundPreviewFadeOut) { [weak self] in
            self?.stop()
        }
    }

    private func schedule(_ slot: inout Timer?, after interval: TimeInterval, repeats: Bool = false, _ action: @escaping @MainActor @Sendable () -> Void) {
        slot?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        slot = timer
    }
}
