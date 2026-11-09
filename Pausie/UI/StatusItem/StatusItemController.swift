import AppKit

/// Owns the `NSStatusItem`: template icon plus the countdown title.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private unowned let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = PausieAsset.menuBarIcon()
        button.imagePosition = .imageLeading
    }
}
