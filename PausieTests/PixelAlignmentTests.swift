import AppKit
import SwiftUI
import Testing
@testable import Pausie

/// Strokes must land on whole device pixels. A 1.5pt stroke is 3px on Retina, but on a 1x display it
/// blurs and comes out thicker on one side (D14).
@Suite("Pixel-aligned strokes")
@MainActor
struct PixelAlignmentTests {
    @Test("Stroke widths: Figma's value on Retina, whole pixels at 1x")
    func strokeWidths() {
        #expect(Metrics.Editor.focusedBorderWidth.resolved(forScale: 2) == 1.5)
        #expect(Metrics.Editor.focusedBorderWidth.resolved(forScale: 1) == 2)
        #expect(BorderWidth.checkbox.resolved(forScale: 2) == 1.5)
        #expect(BorderWidth.checkbox.resolved(forScale: 1) == 1)
        for width in [Metrics.Editor.focusedBorderWidth, BorderWidth.checkbox] {
            for scale in [1.0, 2.0] {
                let pixels = width.resolved(forScale: scale) * scale
                #expect(pixels == pixels.rounded())
            }
        }
    }

    @Test("At 1x the focused editor border is solid brand/primary, 2px on every side")
    func focusedEditorBorderAt1x() throws {
        // A 200x60 box with a 10px margin: the box spans x 10..<210, y 10..<70.
        let image = try render(
            EditorBox(isFocused: true) { Color.clear.frame(height: 36) }
                .frame(width: 200, height: 60)
                .padding(10)
                .background(Color(.surfaceWindow))
        )
        let midX = 110, midY = 40
        for (x, y) in [(10, midY), (11, midY), (208, midY), (209, midY), (midX, 10), (midX, 11), (midX, 68), (midX, 69)] {
            #expect(try pixel(image, x, y, is: .brandPrimary), "border pixel (\(x), \(y))")
        }
        for (x, y) in [(12, midY), (207, midY), (midX, 12), (midX, 67)] {
            #expect(try pixel(image, x, y, is: .surfaceCanvas), "inside pixel (\(x), \(y))")
        }
    }

    @Test("At 1x the checkbox border is a solid 1px brand/lavender line")
    func checkboxAt1x() throws {
        // The 16x16 box sits 2pt below its top inset: x 4..<20, y 6..<22.
        let image = try render(TodoCheckbox().padding(4).background(Color(.surfaceWindow)))
        for (x, y) in [(4, 14), (19, 14), (12, 6), (12, 21)] {
            #expect(try pixel(image, x, y, is: .brandLavender), "border pixel (\(x), \(y))")
        }
        for (x, y) in [(5, 14), (18, 14), (12, 7), (12, 20)] {
            #expect(try pixel(image, x, y, is: .surfaceWindow), "inside pixel (\(x), \(y))")
        }
    }

    // MARK: - Helpers

    private func render(_ view: some View) throws -> NSBitmapImageRep {
        var image: CGImage?
        try #require(NSAppearance(named: .aqua)).performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view
                .environment(\.colorScheme, .light)
                .environment(\.displayScale, 1))
            renderer.scale = 1
            image = renderer.cgImage
        }
        return NSBitmapImageRep(cgImage: try #require(image))
    }

    /// Whether the pixel is the token's solid color, not a blend with its neighbours. The expected value
    /// comes from a swatch rendered the same way, because the renderer's color matching depends on the
    /// machine's main display.
    private func pixel(_ image: NSBitmapImageRep, _ x: Int, _ y: Int, is token: ColorToken) throws -> Bool {
        let swatch = try render(Color(token).frame(width: 1, height: 1))
        let expected = try #require(swatch.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
        let actual = try #require(image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        let tolerance = 2.0 / 255
        return abs(actual.redComponent - expected.redComponent) <= tolerance
            && abs(actual.greenComponent - expected.greenComponent) <= tolerance
            && abs(actual.blueComponent - expected.blueComponent) <= tolerance
    }
}
