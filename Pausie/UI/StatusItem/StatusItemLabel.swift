import AppKit
import SwiftUI

/// Status item content: the template icon and the countdown, whose changing digits roll in.
struct StatusItemLabel: View {
    let session: SessionController
    let icon: NSImage?

    var body: some View {
        let title = MenuPresentation(session: session).title
        HStack(spacing: Metrics.StatusItem.spacing) {
            if let icon {
                Image(nsImage: icon)
                    .renderingMode(.template)
            }
            if let title {
                RollingText(text: title, font: TypographyToken.menuBarTitle.font)
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
