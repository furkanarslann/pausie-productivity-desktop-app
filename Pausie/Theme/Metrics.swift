import AppKit
import SwiftUI

// Every size, padding and radius used by the UI lives here, named after the Figma components and screens.
// Views never contain raw numbers.

/// Corner radius tokens (`radius/*` variables plus the literal radii used by components).
enum Radius {
    /// `radius/sm`: button, stepper, segmented track, copy button, info box.
    static let sm: CGFloat = 8
    /// `radius/md`: windows, note editor.
    static let md: CGFloat = 12
    /// `radius/lg`: break cards, skip dialog.
    static let lg: CGFloat = 20
    /// Status item menu panel.
    static let menuPanel: CGFloat = 10
    static let checkbox: CGFloat = 5
    static let segment: CGFloat = 6
    static let tooltip: CGFloat = 6
    static let progress: CGFloat = 2
    /// Speech bubble: 16 everywhere except the bottom-left "speech" corner.
    static let bubble: CGFloat = 16
    static let bubbleTail: CGFloat = 4
}

/// Border widths.
enum BorderWidth {
    static let hairline: CGFloat = 1
    static let checkbox: CGFloat = 1.5
}

/// `Pausie/Window shadow`: y 18, blur 44, ink 16% + y 2, blur 6, ink 8%. Not mode-dependent.
enum ShadowToken {
    struct Layer: Sendable {
        let y: CGFloat
        let blur: CGFloat
        let opacity: Double
    }

    static let window: [Layer] = [
        Layer(y: 18, blur: 44, opacity: OpacityToken.shadowLarge),
        Layer(y: 2, blur: 6, opacity: OpacityToken.shadowSmall),
    ]

    /// Selected segment: y 1, blur 1.5, ink 12%.
    static let segment = Layer(y: 1, blur: 1.5, opacity: OpacityToken.segmentShadow)
}

/// SF Symbols used instead of the Figma vector glyphs.
enum Icon {
    static let copy = "doc.on.doc"
    static let minus = "minus"
    static let plus = "plus"
    static let chime = "music.note"
    static let checkmark = "checkmark"
}

enum Metrics {
    enum Button {
        static let height: CGFloat = 36
        static let horizontalPadding: CGFloat = 18
        static let pressedOpacity: Double = 0.85
    }

    enum TodoRow {
        static let spacing: CGFloat = 10
        static let verticalPadding: CGFloat = 4
        static let checkboxSize: CGFloat = 16
        static let checkboxTopInset: CGFloat = 2
        static let checkmarkSize: CGFloat = 9
    }

    /// Note editor box (screens 03, 04).
    /// Note editor box. `compact` is the break card editor (screen 04); `roomy` is the centered
    /// note window editor (screen 03b).
    enum Editor {
        struct Style: Equatable, Sendable {
            let padding: EdgeInsets
            let rowSpacing: CGFloat
            let minHeight: CGFloat?
        }

        static let compact = Style(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14), rowSpacing: 2, minHeight: nil)
        static let roomy = Style(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16), rowSpacing: 4, minHeight: 190)
        /// Focused editor: 1.5pt `brand/primary` border plus a 4pt `brand/lavender` ring outside it.
        static let focusedBorderWidth: CGFloat = 1.5
        static let focusRingWidth: CGFloat = 4
    }

    enum Bubble {
        static let verticalPadding: CGFloat = 10
        static let horizontalPadding: CGFloat = 16
    }

    /// Status item (menu bar extra).
    enum StatusItem {
        static let iconHeight: CGFloat = 16
    }

    /// Status item menu (screens 01, 02).
    enum Menu {
        static let width: CGFloat = 280
        static let headerSpacing: CGFloat = 10
        static let headerHorizontalPadding: CGFloat = 16
        static let headerTopPadding: CGFloat = 6
        static let headerBottomPadding: CGFloat = 6
        static let headerBottomPaddingWithProgress: CGFloat = 4
        static let headerTextSpacing: CGFloat = 1
        static let poseWidth: CGFloat = 40
        static let progressHeight: CGFloat = 4
        static let progressBottomPadding: CGFloat = 6
        static let recentNotesTimeTab: CGFloat = 270
        static let recentNotesLabelMaxWidth: CGFloat = 220
    }

    /// Screen 03.
    /// Screen 03b: centered on the main display.
    enum NoteWindow {
        static let width: CGFloat = 600
        static let contentPadding = EdgeInsets(top: 8, leading: 28, bottom: 24, trailing: 28)
        static let contentSpacing: CGFloat = 18
        static let headerSpacing: CGFloat = 18
        static let headerTextSpacing: CGFloat = 6
        static let poseSize = CGSize(width: 120, height: 125)
        static let actionSpacing: CGFloat = 10
    }

    /// Screens 04, 05, 07.
    enum BreakCard {
        static let padding = EdgeInsets(top: 24, leading: 28, bottom: 28, trailing: 28)
        static let requiredWidth: CGFloat = 480
        static let requiredSpacing: CGFloat = 14
        static let width: CGFloat = 440
        static let spacing: CGFloat = 12
        static let buttonTopSpacer: CGFloat = 4
        static let requiredPoseSize = CGSize(width: 150, height: 156)
        /// Break ring (screen 05): the remaining-time arc around the relaxed pose.
        static let ringSize: CGFloat = 232
        static let ringDiameter: CGFloat = 216
        static let ringLineWidth: CGFloat = 8
        static let ringPoseSize = CGSize(width: 150, height: 168)
        static let ringPoseOffsetY: CGFloat = 4
        static let backToWorkPoseSize = CGSize(width: 180, height: 207)
        static let chipSpacing: CGFloat = 6
        static let chipPadding = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    }

    /// Screen 06.
    enum SkipDialog {
        static let width: CGFloat = 360
        static let padding = EdgeInsets(top: 20, leading: 24, bottom: 22, trailing: 24)
        static let spacing: CGFloat = 10
        static let actionSpacing: CGFloat = 10
        static let poseSize = CGSize(width: 84, height: 100)
    }

    /// Screen 08.
    enum ResumePanel {
        static let width: CGFloat = 380
        static let headerPadding = EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 12)
        static let headerSpacing: CGFloat = 12
        static let headerTextSpacing: CGFloat = 2
        static let headerTextTopPadding: CGFloat = 6
        static let poseSize = CGSize(width: 52, height: 61)
        static let copyButtonSize: CGFloat = 32
        static let copyIconSize: CGFloat = 14
        static let tooltipOffset: CGFloat = 6
        static let tooltipPadding = EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        static let todoPadding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        static let todoSpacing: CGFloat = 2
        static let footerPadding = EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 8)
        static let footerSpacing: CGFloat = 8
        static let screenInset = CGSize(width: 16, height: 12)
    }

    /// Screen 09.
    enum Settings {
        static let width: CGFloat = 420
        static let contentPadding = EdgeInsets(top: 8, leading: 24, bottom: 22, trailing: 24)
        static let contentSpacing: CGFloat = 18
        static let headerSpacing: CGFloat = 12
        static let headerTextSpacing: CGFloat = 2
        static let poseSize = CGSize(width: 56, height: 51)
        static let groupSpacing: CGFloat = 4
        static let rowSpacing: CGFloat = 12
        static let infoPadding = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        static let actionSpacing: CGFloat = 8
    }

    enum Stepper {
        static let buttonSize: CGFloat = 32
        static let valueWidth: CGFloat = 72
        static let height: CGFloat = 34
        static let iconSize: CGFloat = 12
    }

    enum Segment {
        static let trackPadding: CGFloat = 2
        static let spacing: CGFloat = 2
        static let padding = EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14)
    }
}

/// Window levels. The break layer sits below the menu bar so it stays reachable (rule 6);
/// Pausie's own panels sit above the break layer.
enum WindowLevel {
    static let breakOverlay = NSWindow.Level.floating
    static let panel = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
}

extension View {
    /// `Pausie/Window shadow`.
    func windowShadow() -> some View {
        let ink = Color.shadowInk
        let large = ShadowToken.window[0]
        let small = ShadowToken.window[1]
        return shadow(color: ink.opacity(large.opacity), radius: large.blur / 2, x: 0, y: large.y)
            .shadow(color: ink.opacity(small.opacity), radius: small.blur / 2, x: 0, y: small.y)
    }

    func frame(_ size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
}
