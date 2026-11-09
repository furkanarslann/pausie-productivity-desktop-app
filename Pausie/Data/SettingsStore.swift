import Foundation
import Observation

/// Persists `Settings` in `UserDefaults`. Durations are read by `SessionController` at the start of
/// each cycle (spec rule 11); appearance is applied by the app as soon as it changes.
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

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
