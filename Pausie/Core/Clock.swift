import Foundation

/// Source of the current time. Named `SessionClock` to avoid clashing with the standard library's `Clock`.
/// Tests inject a fake clock to move time forward.
protocol SessionClock: Sendable {
    var now: Date { get }
}

struct SystemClock: SessionClock {
    var now: Date { Date() }
}
