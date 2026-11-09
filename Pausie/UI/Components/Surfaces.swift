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

/// Note editor box: `surface/canvas`, 1pt `brand/lavender` stroke, radius 12.
struct EditorBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        content
            .padding(.vertical, Metrics.Editor.verticalPadding)
            .padding(.horizontal, Metrics.Editor.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Color(.surfaceCanvas)))
            .overlay(shape.strokeBorder(Color(.brandLavender), lineWidth: BorderWidth.hairline))
    }
}
