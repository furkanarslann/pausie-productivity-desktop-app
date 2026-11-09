import Foundation

enum AppearancePreference: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

struct Settings: Codable, Equatable, Sendable {
    /// Must be greater than the note reminder lead (`SessionRules.warningLeadMinutes`).
    var workMinutes = 50
    /// At least 1.
    var breakMinutes = 10
    var appearance: AppearancePreference = .system

    static let `default` = Settings()

    static let workMinutesRange = (SessionRules.warningLeadMinutes + 1)...180
    static let breakMinutesRange = 1...60

    var isValid: Bool {
        Self.workMinutesRange.contains(workMinutes) && Self.breakMinutesRange.contains(breakMinutes)
    }

    /// Clamps durations into their valid ranges.
    func validated() -> Settings {
        var copy = self
        copy.workMinutes = min(max(workMinutes, Self.workMinutesRange.lowerBound), Self.workMinutesRange.upperBound)
        copy.breakMinutes = min(max(breakMinutes, Self.breakMinutesRange.lowerBound), Self.breakMinutesRange.upperBound)
        return copy
    }

    var workDuration: TimeInterval { TimeInterval(workMinutes * 60) }
    var breakDuration: TimeInterval { TimeInterval(breakMinutes * 60) }
}
