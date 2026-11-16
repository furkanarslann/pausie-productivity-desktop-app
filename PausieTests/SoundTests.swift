import AVFoundation
import Foundation
import Testing
@testable import Pausie

@Suite("Break sounds and settings")
@MainActor
struct SoundTests {
    @Test("Every sound has a playable file: bundled music, or the system's own chime")
    func everySoundHasAFile() throws {
        for sound in BreakSound.allCases {
            let url = try #require(sound.url(), "No file for \(sound)")
            let player = try AVAudioPlayer(contentsOf: url)
            #expect(player.duration > 0)
            if sound.kind == .music {
                // Rule 3: music plays once and must end within the 1 min limit.
                #expect(player.duration <= SessionRules.chimeMaxDuration)
            }
        }
    }

    @Test("Settings list music first, then the macOS chimes; the default is Glass")
    func catalog() {
        #expect(BreakSound.music == [.morningMarimba, .ukuleleBounce, .riseAndShine, .happyGroove])
        #expect(BreakSound.chimes.first == .glass)
        #expect(BreakSound.default == .glass)
        #expect(Settings().breakSound == .glass)
    }

    @Test("Settings saved before the sound existed keep their durations and get the default sound")
    func decodeOldSettings() throws {
        let json = #"{"workMinutes":25,"breakMinutes":5,"appearance":"dark"}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(settings.workMinutes == 25)
        #expect(settings.breakMinutes == 5)
        #expect(settings.appearance == .dark)
        #expect(settings.breakSound == .glass)
    }

    @Test("A sound that no longer exists falls back to the default; the rest is kept")
    func decodeUnknownSound() throws {
        let json = #"{"workMinutes":30,"breakMinutes":10,"appearance":"light","breakSound":"clairDeLune"}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(settings.workMinutes == 30)
        #expect(settings.breakSound == .glass)
    }

    @Test("A setting naming a retired classical clip keeps music: it gets the first new track (D20)",
          arguments: ["gymnopedie", "traumerei", "preludeInC", "nocturne"])
    func decodeRetiredMusic(stored: String) throws {
        let json = #"{"workMinutes":30,"breakMinutes":10,"appearance":"light","breakSound":"\#(stored)"}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(settings.breakSound == .morningMarimba)
        #expect(settings.workMinutes == 30)
    }

    @Test("The sound applies at once and is saved")
    func storeSavesSound() throws {
        let suite = "PausieSoundTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        store.setBreakSound(.happyGroove)
        #expect(store.settings.breakSound == .happyGroove)
        #expect(SettingsStore(defaults: defaults).settings.breakSound == .happyGroove)
    }

    @Test("Stopping a preview leaves the break-over sound alone")
    func stopPreviewOnlyStopsPreviews() {
        let player = ChimePlayer(sound: { .glass })
        player.stopPreview()
        #expect(player.previewing == nil)
    }
}
