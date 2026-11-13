import AppKit
import SwiftUI

/// Status item content: the template icon and the countdown, whose changing digits roll in. While paused
/// from the menu (T16) a pause sign sits before the frozen countdown.
struct StatusItemLabel: View {
    let session: SessionController
    let icon: NSImage?

    var body: some View {
        let presentation = MenuPresentation(session: session)
        HStack(spacing: Metrics.StatusItem.spacing) {
            if let icon {
                Image(nsImage: icon)
                    .renderingMode(.template)
            }
            if let title = presentation.title {
                HStack(spacing: Metrics.StatusItem.pausedSpacing) {
                    if presentation.isPaused {
                        Image(systemName: Icon.paused)
                            .font(.system(size: Metrics.StatusItem.pausedIconSize, weight: .bold))
                    }
                    RollingText(text: title, font: TypographyToken.menuBarTitle.font)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, Metrics.StatusItem.horizontalPadding)
        .fixedSize()
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

/// Hosts the label inside the status item button without taking its clicks.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
