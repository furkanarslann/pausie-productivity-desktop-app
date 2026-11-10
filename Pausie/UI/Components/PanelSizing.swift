import AppKit
import SwiftUI

// Windows here follow their SwiftUI content's height without AppKit's
// `sizingOptions = .preferredContentSize`. That option resizes the window synchronously during layout;
// with wrapped text each resize re-measured the content and resized again, recursing until the stack
// overflowed (opening a long note from Recent notes crashed the app). Instead the window is sized once
// up front, then only asynchronously and only when the content's height changes by at least a point.

/// Root view of a sized window: lays the content out at its ideal height (independent of the window's
/// height, so there is no feedback) and reports that height.
struct SizeReportingRoot<Content: View>: View {
    let content: Content
    let onHeightChange: (CGFloat) -> Void

    var body: some View {
        // No max-height frame here: it would make the ideal-size measurement return the (infinite) proposal.
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
            .frame(maxWidth: .infinity)
    }
}

extension NSHostingController {
    /// The content's ideal size at a fixed width, rounded up to whole points and capped at `maxHeight`.
    func idealContentSize(width: CGFloat, maxHeight: CGFloat) -> NSSize {
        let size = sizeThatFits(in: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return NSSize(width: width, height: PanelSizing.clampedHeight(size.height, maxHeight: maxHeight))
    }
}

enum PanelSizing {
    /// Whole points, never infinite or larger than the screen (AppKit asserts on out-of-range frames).
    static func clampedHeight(_ height: CGFloat, maxHeight: CGFloat) -> CGFloat {
        guard height.isFinite, height > 0 else { return 0 }
        return min(height.rounded(.up), maxHeight)
    }

    /// The tallest content a Pausie window may get: the main screen's visible height.
    @MainActor
    static var maxContentHeight: CGFloat {
        NSScreen.screens.first?.visibleFrame.height ?? 800
    }
}

extension NSWindow {
    /// Hosts `content` with no AppKit-driven sizing; the window grows or shrinks with the content's height
    /// on the next run loop turn. Returns the controller and the size to start with.
    @MainActor
    func hostSizedContent<Content: View>(_ content: Content, width: CGFloat) -> (NSHostingController<SizeReportingRoot<Content>>, NSSize) {
        let root = SizeReportingRoot(content: content) { [weak self] height in
            Task { @MainActor in self?.setContentHeightIfNeeded(height) }
        }
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = []
        contentViewController = hosting
        return (hosting, hosting.idealContentSize(width: width, maxHeight: PanelSizing.maxContentHeight))
    }

    /// Changes the content height (keeping the width) when it differs by at least a point.
    func setContentHeightIfNeeded(_ height: CGFloat) {
        let target = PanelSizing.clampedHeight(height, maxHeight: PanelSizing.maxContentHeight)
        let current = contentRect(forFrameRect: frame)
        guard target > 0, abs(target - current.height) >= 1 else { return }
        setContentSize(NSSize(width: current.width, height: target))
    }
}
