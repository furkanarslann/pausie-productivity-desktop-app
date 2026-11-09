import SwiftUI

/// Status header at the top of the status item menu (screen 01), hosted in an `NSMenuItem.view`.
/// Reads the session directly so the countdown keeps moving while the menu is open.
struct MenuHeaderView: View {
    let session: SessionController

    var body: some View {
        MenuHeaderContent(header: MenuPresentation(session: session).header)
    }
}

struct MenuHeaderContent: View {
    let header: MenuPresentation.Header

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Metrics.Menu.headerSpacing) {
                PausiePoseView(pose: header.pose, width: Metrics.Menu.poseWidth)
                VStack(alignment: .leading, spacing: Metrics.Menu.headerTextSpacing) {
                    Text(header.title)
                        .typography(.bodyEmphasis)
                        .foregroundStyle(Color(.textPrimary))
                    Text(header.subtitle)
                        .typography(.caption)
                        .foregroundStyle(Color(.textSecondary))
                        .monospacedDigit()
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.Menu.headerHorizontalPadding)
            .padding(.top, Metrics.Menu.headerTopPadding)
            .padding(.bottom, header.progress == nil ? Metrics.Menu.headerBottomPadding : Metrics.Menu.headerBottomPaddingWithProgress)

            if let progress = header.progress {
                ProgressTrack(value: progress)
                    .padding(.horizontal, Metrics.Menu.headerHorizontalPadding)
                    .padding(.bottom, Metrics.Menu.progressBottomPadding)
            }
        }
        .frame(width: Metrics.Menu.width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 4pt progress track: `brand/lavender-tint` track, `brand/primary` elapsed fill.
struct ProgressTrack: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.progress)
                    .fill(Color(.brandLavenderTint))
                RoundedRectangle(cornerRadius: Radius.progress)
                    .fill(Color(.brandPrimary))
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: Metrics.Menu.progressHeight)
        .accessibilityHidden(true)
    }
}
