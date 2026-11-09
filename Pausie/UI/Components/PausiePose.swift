import AppKit
import SwiftUI

/// Mascot artwork. Views use this enum and never type asset names.
enum PausiePose: String, CaseIterable, Sendable {
    case takingNotes = "pausie.takingNotes"
    case relaxed = "pausie.relaxed"
    case backToWork = "pausie.backToWork"
    case thinking = "pausie.thinking"
    case focused = "pausie.focused"
    case happy = "pausie.happy"
    case sleepy = "pausie.sleepy"
    case breakTime = "pausie.breakTime"

    var image: Image { Image(rawValue) }
    var nsImage: NSImage? { NSImage(named: NSImage.Name(rawValue)) }
}

enum PausieAsset {
    static let menuBarTemplateName = "menubar.template"

    /// Status item icon, 16 pt tall, rendered as a template so the system colors it.
    @MainActor
    static func menuBarIcon() -> NSImage? {
        guard let source = NSImage(named: NSImage.Name(menuBarTemplateName)),
              let image = source.copy() as? NSImage else { return nil }
        let height = Metrics.StatusItem.iconHeight
        let aspect = source.size.height > 0 ? source.size.width / source.size.height : 1
        image.size = NSSize(width: (height * aspect).rounded(), height: height)
        image.isTemplate = true
        return image
    }
}

/// A pose drawn aspect-fit in its Figma box. Pass only a width to let the height follow the aspect ratio.
struct PausiePoseView: View {
    let pose: PausiePose
    var width: CGFloat
    var height: CGFloat?

    init(pose: PausiePose, size: CGSize) {
        self.pose = pose
        width = size.width
        height = size.height
    }

    init(pose: PausiePose, width: CGFloat) {
        self.pose = pose
        self.width = width
        height = nil
    }

    var body: some View {
        pose.image
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}
