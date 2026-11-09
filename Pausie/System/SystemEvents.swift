import AppKit

/// Forwards sleep/wake, screen lock/unlock and display changes to the app.
@MainActor
final class SystemEvents {
    var onPause: ((PauseReason) -> Void)?
    var onResume: ((PauseReason) -> Void)?
    var onScreensChanged: (() -> Void)?

    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    private static let screenLocked = Notification.Name("com.apple.screenIsLocked")
    private static let screenUnlocked = Notification.Name("com.apple.screenIsUnlocked")

    func start() {
        guard tokens.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let local = NotificationCenter.default

        observe(workspace, NSWorkspace.willSleepNotification) { $0.onPause?(.sleep) }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.onResume?(.sleep) }
        observe(distributed, Self.screenLocked) { $0.onPause?(.screenLocked) }
        observe(distributed, Self.screenUnlocked) { $0.onResume?(.screenLocked) }
        observe(local, NSApplication.didChangeScreenParametersNotification) { $0.onScreensChanged?() }
    }

    func stop() {
        for (center, token) in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping @MainActor (SystemEvents) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        tokens.append((center, token))
    }
}
