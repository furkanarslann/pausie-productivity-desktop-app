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
        let height = ControlMetrics.menuBarIconHeight
        let aspect = source.size.height > 0 ? source.size.width / source.size.height : 1
        image.size = NSSize(width: (height * aspect).rounded(), height: height)
        image.isTemplate = true
        return image
    }
}

/// A pose sized by its largest dimension.
struct PausiePoseView: View {
    let pose: PausiePose
    let size: CGFloat

    var body: some View {
        pose.image
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
