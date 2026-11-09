import Foundation

/// Time and duration formats. They come from the system locale, never from the JSON catalog.
enum TimeFormat {
    /// `mm:ss` countdown. Rounds up so a fresh 50 min cycle shows `50:00` and the last second shows `00:01`.
    static func countdown(_ seconds: TimeInterval) -> String {
        let whole = Int(max(0, seconds).rounded(.up))
        return Duration.seconds(whole).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }

    /// Short clock time in the user's locale, e.g. "14:35" or "2:35 PM".
    static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Whole minutes left, rounded up, as a localized number.
    static func minutesLeft(_ seconds: TimeInterval) -> Int {
        Int((max(0, seconds) / 60).rounded(.up))
    }

    /// A localized integer.
    static func number(_ value: Int) -> String {
        value.formatted()
    }
}
