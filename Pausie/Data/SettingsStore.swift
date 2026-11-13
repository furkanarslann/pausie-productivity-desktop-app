import Foundation
import Observation

/// Persists `Settings` in `UserDefaults`. Durations are read by `SessionController` at the start of
/// each cycle (spec rule 11); appearance and the break sound apply as soon as they change.
@MainActor
@Observable
final class SettingsStore {
    static let defaultsKey = "settings"

    private(set) var settings: Settings

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onAppearanceChange: ((AppearancePreference) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = stored.validated()
        } else {
            settings = .default
        }
    }

    /// Saves durations (validated) and appearance.
    func update(_ newValue: Settings) {
        let validated = newValue.validated()
        let appearanceChanged = validated.appearance != settings.appearance
        settings = validated
        persist()
        if appearanceChanged { onAppearanceChange?(validated.appearance) }
    }

    /// Appearance applies right away, independent of the Save button.
    func setAppearance(_ appearance: AppearancePreference) {
        guard appearance != settings.appearance else { return }
        settings.appearance = appearance
        persist()
        onAppearanceChange?(appearance)
    }

    /// The break sound applies right away, independent of the Save button.
    func setBreakSound(_ sound: BreakSound) {
        guard sound != settings.breakSound else { return }
        settings.breakSound = sound
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
