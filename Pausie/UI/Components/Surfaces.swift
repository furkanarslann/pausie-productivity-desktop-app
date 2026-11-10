import SwiftUI

extension View {
    /// Window, card and menu surface: `surface/window` fill, 1pt `border/subtle` stroke.
    func pausieSurface(radius: CGFloat, shadow: Bool = true) -> some View {
        modifier(SurfaceModifier(radius: radius, shadow: shadow))
    }
}

private struct SurfaceModifier: ViewModifier {
    let radius: CGFloat
    let shadow: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(Color(.surfaceWindow)))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color(.borderSubtle), lineWidth: BorderWidth.hairline))
            .modifier(OptionalShadow(enabled: shadow))
    }
}

private struct OptionalShadow: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            // Flatten first so the shadow follows the card outline, not every element inside it.
            content.compositingGroup().windowShadow()
        } else {
            content
        }
    }
}

/// A horizontal 1pt `border/subtle` line.
struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.borderSubtle))
            .frame(height: BorderWidth.hairline)
    }
}

/// Note editor box: `surface/canvas` fill, radius 12. Unfocused: 1pt `brand/lavender` border.
/// Focused (03b): 1.5pt `brand/primary` border (2px at 1x) and a 4pt `brand/lavender` ring at 35% around it.
struct EditorBox<Content: View>: View {
    var style: Metrics.Editor.Style = Metrics.Editor.compact
    var isFocused = false
    var onTapBackground: (() -> Void)?
    @ViewBuilder let content: Content

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        let ringShape = RoundedRectangle(cornerRadius: Radius.md + Metrics.Editor.focusRingWidth, style: .continuous)
        content
            .padding(style.padding)
            .frame(maxWidth: .infinity, minHeight: style.minHeight, alignment: .topLeading)
            .background {
                if let onTapBackground {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onTapBackground)
                        .accessibilityHidden(true)
                }
            }
            .background(shape.fill(Color(.surfaceCanvas)))
            .overlay(
                shape.strokeBorder(
                    Color(isFocused ? .brandPrimary : .brandLavender),
                    lineWidth: isFocused ? Metrics.Editor.focusedBorderWidth.resolved(forScale: displayScale) : BorderWidth.hairline
                )
            )
            .background {
                if isFocused {
                    ringShape
                        .fill(Color(.brandLavender).opacity(OpacityToken.focusRing))
                        .padding(-Metrics.Editor.focusRingWidth)
                }
            }
    }
}
