import Foundation

/// The sound that plays when a break ends, picked in Settings. Raw values are stored in the settings:
/// never rename them.
enum BreakSound: String, Codable, CaseIterable, Sendable {
    // Public-domain music bundled in `Resources/Sounds` (credits: docs/SOUNDS.md).
    case gymnopedie
    case traumerei
    case preludeInC
    case nocturne

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

    static var music: [BreakSound] { allCases.filter { $0.kind == .music } }
    static var chimes: [BreakSound] { allCases.filter { $0.kind == .chime } }

    var kind: Kind {
        switch self {
        case .gymnopedie, .traumerei, .preludeInC, .nocturne: .music
        case .glass, .hero, .ping, .purr, .submarine, .tink, .bottle, .blow: .chime
        }
    }

    /// Bundled file name (music, `.m4a`) or macOS system sound name (chime, `.aiff`).
    var resourceName: String {
        switch self {
        case .gymnopedie: "gymnopedie"
        case .traumerei: "traumerei"
        case .preludeInC: "prelude-in-c"
        case .nocturne: "nocturne"
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
        case .gymnopedie: .soundGymnopedie
        case .traumerei: .soundTraumerei
        case .preludeInC: .soundPreludeInC
        case .nocturne: .soundNocturne
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
