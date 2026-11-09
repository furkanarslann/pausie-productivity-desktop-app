import CoreGraphics
import SwiftUI

/// Corner radius tokens.
enum Radius {
    /// Button, stepper, segment, copy button.
    static let sm: CGFloat = 8
    /// Window, note editor.
    static let md: CGFloat = 12
    /// Break cards.
    static let lg: CGFloat = 20
    /// Status item menu panel.
    static let menuPanel: CGFloat = 10
}

/// Spacing scale (points).
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

/// Border widths.
enum BorderWidth {
    static let hairline: CGFloat = 1
    static let focus: CGFloat = 2
}

/// `shadow/window`: y 18, blur 44, ink 16% + y 2, blur 6, ink 8%.
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
}

/// Fixed widths of windows and cards from the Figma screens.
enum WindowWidth {
    static let noteWindow: CGFloat = 460
    static let requiredNoteCard: CGFloat = 480
    static let breakCard: CGFloat = 440
    static let skipCard: CGFloat = 360
    static let resumePanel: CGFloat = 380
    static let settings: CGFloat = 420
    static let menuHeader: CGFloat = 280
}

/// Control sizes.
enum ControlMetrics {
    static let buttonHeight: CGFloat = 36
    static let checkbox: CGFloat = 16
    static let progressBarHeight: CGFloat = 6
    static let copyButton: CGFloat = 28
    static let stepperButton: CGFloat = 28
    static let segmentHeight: CGFloat = 28
    /// Height of the status item template icon.
    static let menuBarIconHeight: CGFloat = 16
}

/// Distance of floating panels (note window, resume panel) from the top-right corner of the screen.
enum WindowPlacement {
    static let screenInset: CGFloat = 16
}

extension View {
    /// `shadow/window` token.
    func windowShadow() -> some View {
        let ink = Color(.brandInk)
        let layers = ShadowToken.window
        return shadow(color: ink.opacity(layers[0].opacity), radius: layers[0].blur / 2, x: 0, y: layers[0].y)
            .shadow(color: ink.opacity(layers[1].opacity), radius: layers[1].blur / 2, x: 0, y: layers[1].y)
    }
}
