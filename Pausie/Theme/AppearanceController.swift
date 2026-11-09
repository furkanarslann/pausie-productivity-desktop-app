import AppKit

/// Applies the user's appearance choice. `nil` follows the system.
@MainActor
enum AppearanceController {
    static func apply(_ preference: AppearancePreference) {
        NSApp.appearance = appearance(for: preference)
    }

    static func appearance(for preference: AppearancePreference) -> NSAppearance? {
        switch preference {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
