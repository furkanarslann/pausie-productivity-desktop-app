import SwiftUI

/// Figma `Button`: Primary, Secondary, Ghost; Disabled = the whole button at 40%.
/// Secondary also has a 1pt `brand/lavender` edge at 50%, which Figma doesn't have (D14).
struct PausieButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case ghost
    }

    let variant: Variant
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        PausieButtonBody(configuration: configuration, variant: variant, fullWidth: fullWidth)
    }
}

private struct PausieButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: PausieButtonStyle.Variant
    let fullWidth: Bool

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(TypographyToken.button.font)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, Metrics.Button.horizontalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: Metrics.Button.height)
            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(background))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(border, lineWidth: BorderWidth.hairline)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
            .opacity(opacity)
    }

    private var border: Color? {
        switch variant {
        case .secondary: Color(.brandLavender).opacity(OpacityToken.secondaryButtonBorder)
        case .primary, .ghost: nil
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary: Color(.textOnPrimary)
        case .secondary: Color(.brandPrimary)
        case .ghost: Color(.textSecondary)
        }
    }

    private var background: Color {
        switch variant {
        case .primary: Color(.brandPrimary)
        case .secondary: Color(.brandLavenderTint)
        case .ghost: .clear
        }
    }

    private var opacity: Double {
        if !isEnabled { return OpacityToken.disabled }
        return configuration.isPressed ? Metrics.Button.pressedOpacity : 1
    }
}

extension ButtonStyle where Self == PausieButtonStyle {
    static var pausiePrimary: PausieButtonStyle { PausieButtonStyle(variant: .primary) }
    static var pausieSecondary: PausieButtonStyle { PausieButtonStyle(variant: .secondary) }
    static var pausieGhost: PausieButtonStyle { PausieButtonStyle(variant: .ghost) }

    static func pausie(_ variant: PausieButtonStyle.Variant, fullWidth: Bool = false) -> PausieButtonStyle {
        PausieButtonStyle(variant: variant, fullWidth: fullWidth)
    }
}
