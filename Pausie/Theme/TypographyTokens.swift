import AppKit
import SwiftUI

/// Font family roles from the Figma `Pausie Typography` collection.
/// If a custom font arrives later, only this mapping changes.
enum FontFamilyToken: Sendable {
    /// SF Pro Rounded: titles, buttons, timer.
    case display
    /// SF Pro Text: body copy.
    case text

    var design: Font.Design {
        switch self {
        case .display: .rounded
        case .text: .default
        }
    }

    var systemDesign: NSFontDescriptor.SystemDesign {
        switch self {
        case .display: .rounded
        case .text: .default
        }
    }
}

/// Text styles. Values mirror the Figma `Pausie Typography` collection.
enum TypographyToken: CaseIterable, Sendable {
    case title
    case headline
    case timer
    case button
    case body
    case bodyEmphasis
    case caption
    case menu
    /// Status item countdown (desktop component in Figma: SF Pro Text Semibold 13).
    case menuBarTitle

    struct Spec: Equatable, Sendable {
        let family: FontFamilyToken
        let size: CGFloat
        let lineHeight: CGFloat
        let weight: NSFont.Weight
        var monospacedDigits = false
    }

    var spec: Spec {
        switch self {
        case .title: Spec(family: .display, size: 22, lineHeight: 28, weight: .bold)
        case .headline: Spec(family: .display, size: 17, lineHeight: 22, weight: .semibold)
        case .timer: Spec(family: .display, size: 44, lineHeight: 52, weight: .bold, monospacedDigits: true)
        case .button: Spec(family: .display, size: 14, lineHeight: 18, weight: .semibold)
        case .body: Spec(family: .text, size: 14, lineHeight: 20, weight: .regular)
        case .bodyEmphasis: Spec(family: .text, size: 14, lineHeight: 20, weight: .semibold)
        case .caption: Spec(family: .text, size: 12, lineHeight: 16, weight: .regular)
        case .menu: Spec(family: .text, size: 13, lineHeight: 18, weight: .regular)
        case .menuBarTitle: Spec(family: .text, size: 13, lineHeight: 18, weight: .semibold, monospacedDigits: true)
        }
    }

    /// AppKit font for this token (used by NSTextView, the status item title, etc.).
    var nsFont: NSFont {
        let spec = spec
        var font = NSFont.systemFont(ofSize: spec.size, weight: spec.weight)
        if let descriptor = font.fontDescriptor.withDesign(spec.family.systemDesign),
           let designed = NSFont(descriptor: descriptor, size: spec.size) {
            font = designed
        }
        if spec.monospacedDigits {
            let descriptor = font.fontDescriptor.addingAttributes([
                .featureSettings: [[
                    NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                    NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
                ]],
            ])
            font = NSFont(descriptor: descriptor, size: spec.size) ?? font
        }
        return font
    }

    var font: Font {
        let spec = spec
        let font = Font.system(size: spec.size, weight: Font.Weight(spec.weight), design: spec.family.design)
        return spec.monospacedDigits ? font.monospacedDigit() : font
    }

    /// Extra spacing between lines so the rendered line height matches the token.
    var lineSpacing: CGFloat {
        let font = nsFont
        let natural = font.ascender - font.descender + font.leading
        return max(0, spec.lineHeight - natural)
    }
}

extension Font.Weight {
    init(_ weight: NSFont.Weight) {
        switch weight {
        case .ultraLight: self = .ultraLight
        case .thin: self = .thin
        case .light: self = .light
        case .medium: self = .medium
        case .semibold: self = .semibold
        case .bold: self = .bold
        case .heavy: self = .heavy
        case .black: self = .black
        default: self = .regular
        }
    }
}

extension View {
    /// Applies a typography token: font plus the token's line height.
    func typography(_ token: TypographyToken) -> some View {
        font(token.font).lineSpacing(token.lineSpacing)
    }
}
