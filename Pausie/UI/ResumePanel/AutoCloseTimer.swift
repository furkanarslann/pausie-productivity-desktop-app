import Foundation

/// Runs an action after a delay unless paused, e.g. while the pointer is over the panel.
/// Resuming starts the full delay again.
@MainActor
final class AutoCloseTimer {
    private let delay: TimeInterval
    private let action: @MainActor () -> Void
    private var timer: Timer?

    init(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        self.delay = delay
        self.action = action
    }

    var isScheduled: Bool { timer != nil }

    func start() {
        cancel()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func pause() {
        cancel()
    }

    func resume() {
        start()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func fire() {
        timer = nil
        action()
    }
}
