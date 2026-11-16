import Foundation

/// The sound that plays when a break ends, picked in Settings. Raw values are stored in the settings:
/// never rename them.
enum BreakSound: String, Codable, CaseIterable, Sendable {
    // Upbeat music written and synthesized for Pausie, bundled in `Resources/Sounds` (docs/SOUNDS.md).
    case morningMarimba
    case ukuleleBounce
    case riseAndShine
    case happyGroove

    // Short macOS system sounds; they aren't bundled, every Mac has them.
    case glass
    case hero
    case ping
    case purr
    case submarine
    case tink
    case bottle
    case blow

    enum Kind: Sendable {
        /// Plays once, at most `SessionRules.chimeMaxDuration`; the clip fades out by itself.
        case music
        /// Repeats every `SessionRules.chimeRepeatInterval` until `SessionRules.chimeMaxDuration`.
        case chime
    }

    /// The sound used until the user picks another one (D1).
    static let `default`: BreakSound = .glass

    /// Classical clips bundled until D20. A setting that still names one gets the first new track, so a
    /// user who picked music keeps music.
    static let retiredMusic: Set<String> = ["gymnopedie", "traumerei", "preludeInC", "nocturne"]

    /// The sound a stored settings value names, or nil when it names nothing Pausie has (anymore).
    init?(storedValue: String) {
        if let sound = BreakSound(rawValue: storedValue) {
            self = sound
        } else if Self.retiredMusic.contains(storedValue) {
            self = .morningMarimba
        } else {
            return nil
        }
    }

    static var music: [BreakSound] { allCases.filter { $0.kind == .music } }
    static var chimes: [BreakSound] { allCases.filter { $0.kind == .chime } }

    var kind: Kind {
        switch self {
        case .morningMarimba, .ukuleleBounce, .riseAndShine, .happyGroove: .music
        case .glass, .hero, .ping, .purr, .submarine, .tink, .bottle, .blow: .chime
        }
    }

    /// Bundled file name (music, `.m4a`) or macOS system sound name (chime, `.aiff`).
    var resourceName: String {
        switch self {
        case .morningMarimba: "morning-marimba"
        case .ukuleleBounce: "ukulele-bounce"
        case .riseAndShine: "rise-and-shine"
        case .happyGroove: "happy-groove"
        case .glass: "Glass"
        case .hero: "Hero"
        case .ping: "Ping"
        case .purr: "Purr"
        case .submarine: "Submarine"
        case .tink: "Tink"
        case .bottle: "Bottle"
        case .blow: "Blow"
        }
    }

    /// Name shown in Settings and on the break-over card.
    var nameKey: L10nKey {
        switch self {
        case .morningMarimba: .soundMorningMarimba
        case .ukuleleBounce: .soundUkuleleBounce
        case .riseAndShine: .soundRiseAndShine
        case .happyGroove: .soundHappyGroove
        case .glass: .soundGlass
        case .hero: .soundHero
        case .ping: .soundPing
        case .purr: .soundPurr
        case .submarine: .soundSubmarine
        case .tink: .soundTink
        case .bottle: .soundBottle
        case .blow: .soundBlow
        }
    }

    static let musicExtension = "m4a"
    static let systemSoundsDirectory = URL(filePath: "/System/Library/Sounds", directoryHint: .isDirectory)
    static let systemSoundExtension = "aiff"

    /// Where the audio file is: the app bundle for music, the system sounds folder for chimes.
    func url(in bundle: Bundle = .main) -> URL? {
        switch kind {
        case .music:
            return bundle.url(forResource: resourceName, withExtension: Self.musicExtension)
        case .chime:
            let url = Self.systemSoundsDirectory.appending(path: "\(resourceName).\(Self.systemSoundExtension)")
            return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
        }
    }
}
