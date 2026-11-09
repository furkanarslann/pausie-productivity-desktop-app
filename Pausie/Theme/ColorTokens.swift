import AppKit
import SwiftUI

/// Semantic color tokens. Raw values match the variable names of the Figma `Pausie` collection.
enum ColorToken: String, CaseIterable, Sendable {
    case brandPrimary = "brand/primary"
    case brandLavender = "brand/lavender"
    case brandLavenderTint = "brand/lavender-tint"
    case brandYellow = "brand/yellow"
    case brandCream = "brand/cream"
    case brandInk = "brand/ink"
    case surfaceWindow = "surface/window"
    case surfaceCanvas = "surface/canvas"
    case textPrimary = "text/primary"
    case textSecondary = "text/secondary"
    case textOnPrimary = "text/on-primary"
    case borderSubtle = "border/subtle"
    case overlayDim = "overlay/dim"
}

/// The single source of color values (Light / Dark modes of the Figma `Pausie` collection).
/// Changing a color is one line here; nothing else in the app contains a hex value.
enum Palette {
    struct Pair: Equatable, Sendable {
        let light: UInt32
        let dark: UInt32
    }

    static func pair(for token: ColorToken) -> Pair {
        switch token {
        case .brandPrimary: Pair(light: 0x7C3AED, dark: 0x8B5CF6)
        case .brandLavender: Pair(light: 0xA78BFA, dark: 0xA78BFA)
        case .brandLavenderTint: Pair(light: 0xF3EEFF, dark: 0x2E2445)
        case .brandYellow: Pair(light: 0xFFCA15, dark: 0xFFCA15)
        case .brandCream: Pair(light: 0xFFF4D6, dark: 0x3A3122)
        case .brandInk: Pair(light: 0x2D1B4E, dark: 0xF3EEFF)
        case .surfaceWindow: Pair(light: 0xFFFFFF, dark: 0x221A31)
        case .surfaceCanvas: Pair(light: 0xFFFBF2, dark: 0x1A1426)
        case .textPrimary: Pair(light: 0x2D1B4E, dark: 0xF3EEFF)
        case .textSecondary: Pair(light: 0x6E5F89, dark: 0xB7A9D1)
        case .textOnPrimary: Pair(light: 0xFFFFFF, dark: 0xFFFFFF)
        case .borderSubtle: Pair(light: 0xECE4F7, dark: 0x3A2F52)
        case .overlayDim: Pair(light: 0x1B1030, dark: 0x000000)
        }
    }

    static func rgb(_ token: ColorToken, dark: Bool) -> UInt32 {
        let pair = pair(for: token)
        return dark ? pair.dark : pair.light
    }

    static func nsColor(_ token: ColorToken, dark: Bool) -> NSColor {
        let value = rgb(token, dark: dark)
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Opacity tokens used together with color tokens (Figma uses the same variable with an alpha).
enum OpacityToken {
    /// Break layer dim (overlay/dim at 45%).
    static let breakDim: Double = 0.45
    /// Skip-confirmation scrim on top of the break card (overlay/dim at 30%).
    static let skipScrim: Double = 0.30
    /// Note editor border (brand/lavender at 50%).
    static let editorBorder: Double = 0.5
    /// Placeholder text (text/secondary at 60%).
    static let placeholder: Double = 0.6
    /// Disabled controls.
    static let disabled: Double = 0.45
    /// Window shadow layers (brand/ink).
    static let shadowLarge: Double = 0.16
    static let shadowSmall: Double = 0.08
}

extension NSColor {
    /// Dynamic color that resolves light/dark from the drawing appearance, so it updates
    /// instantly when `NSApp.appearance` or the system appearance changes.
    static func pausie(_ token: ColorToken) -> NSColor {
        DynamicColorCache.color(for: token)
    }
}

extension Color {
    init(_ token: ColorToken) {
        self.init(nsColor: .pausie(token))
    }
}

extension ShapeStyle where Self == Color {
    static func token(_ token: ColorToken) -> Color { Color(token) }
}

private enum DynamicColorCache {
    private static let colors: [ColorToken: NSColor] = Dictionary(
        uniqueKeysWithValues: ColorToken.allCases.map { token in
            let color = NSColor(name: NSColor.Name(token.rawValue)) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return Palette.nsColor(token, dark: isDark)
            }
            return (token, color)
        }
    )

    static func color(for token: ColorToken) -> NSColor {
        colors[token] ?? .labelColor
    }
}
