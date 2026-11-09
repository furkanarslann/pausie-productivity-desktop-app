import AppKit
import Testing
@testable import Pausie

@Suite("Theme tokens")
struct ThemeTests {
    @Test("Color tokens use the Figma variable names")
    func tokenNames() {
        #expect(ColorToken.brandPrimary.rawValue == "brand/primary")
        #expect(ColorToken.brandLavenderTint.rawValue == "brand/lavender-tint")
        #expect(ColorToken.textOnPrimary.rawValue == "text/on-primary")
        #expect(ColorToken.overlayDim.rawValue == "overlay/dim")
        #expect(Set(ColorToken.allCases.map(\.rawValue)).count == ColorToken.allCases.count)
    }

    @Test("Light and dark values match the Figma collection", arguments: [
        (ColorToken.brandPrimary, UInt32(0x7C3AED), UInt32(0x8B5CF6)),
        (.surfaceWindow, 0xFFFFFF, 0x221A31),
        (.surfaceCanvas, 0xFFFBF2, 0x1A1426),
        (.textPrimary, 0x2D1B4E, 0xF3EEFF),
        (.textSecondary, 0x6E5F89, 0xB7A9D1),
        (.borderSubtle, 0xECE4F7, 0x3A2F52),
        (.overlayDim, 0x1B1030, 0x000000),
    ])
    func paletteValues(token: ColorToken, light: UInt32, dark: UInt32) {
        #expect(Palette.rgb(token, dark: false) == light)
        #expect(Palette.rgb(token, dark: true) == dark)
    }

    @Test("Dynamic colors resolve per appearance")
    @MainActor
    func dynamicColors() throws {
        let color = NSColor.pausie(.surfaceWindow)
        var light: NSColor?
        var dark: NSColor?
        try #require(NSAppearance(named: .aqua)).performAsCurrentDrawingAppearance {
            light = color.usingColorSpace(.sRGB)
        }
        try #require(NSAppearance(named: .darkAqua)).performAsCurrentDrawingAppearance {
            dark = color.usingColorSpace(.sRGB)
        }
        #expect(light?.redComponent == 1)
        #expect(dark?.redComponent ?? 1 < 0.2)
    }

    @Test("Typography tokens mirror the Figma collection", arguments: [
        (TypographyToken.title, CGFloat(22), CGFloat(28), NSFont.Weight.bold),
        (.headline, 17, 22, .semibold),
        (.timer, 44, 52, .bold),
        (.button, 14, 18, .semibold),
        (.body, 14, 20, .regular),
        (.bodyEmphasis, 14, 20, .semibold),
        (.caption, 12, 16, .regular),
        (.menu, 13, 18, .regular),
    ])
    func typography(token: TypographyToken, size: CGFloat, lineHeight: CGFloat, weight: NSFont.Weight) {
        #expect(token.spec.size == size)
        #expect(token.spec.lineHeight == lineHeight)
        #expect(token.spec.weight == weight)
        #expect(token.nsFont.pointSize == size)
    }

    @Test("Display tokens use the rounded design")
    func displayFamily() {
        #expect(TypographyToken.title.spec.family == .display)
        #expect(TypographyToken.body.spec.family == .text)
    }

    @Test("Every pose and the menu bar icon are in the asset catalog")
    @MainActor
    func assets() {
        for pose in PausiePose.allCases {
            #expect(pose.nsImage != nil, "Missing \(pose.rawValue)")
        }
        let icon = PausieAsset.menuBarIcon()
        #expect(icon?.isTemplate == true)
        #expect(icon?.size.height == ControlMetrics.menuBarIconHeight)
    }

    @Test("Appearance preferences map to NSApp appearances")
    @MainActor
    func appearance() {
        #expect(AppearanceController.appearance(for: .system) == nil)
        #expect(AppearanceController.appearance(for: .light)?.name == .aqua)
        #expect(AppearanceController.appearance(for: .dark)?.name == .darkAqua)
    }
}
