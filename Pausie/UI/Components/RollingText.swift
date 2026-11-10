import SwiftUI

/// Text whose changed characters roll in vertically, like an odometer. Each character has its own
/// clipped slot, and only slots whose character changed animate.
///
/// Unlike `.contentTransition(.numericText())`, which scales and blurs glyphs while they change (they
/// visibly grew and shrank in the menu bar every second), the glyphs here keep their exact size; they
/// only slide.
struct RollingText: View {
    let text: String
    let font: Font

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                ZStack {
                    Text(String(character))
                        .font(font)
                        // A different character is a different view, so the slot transitions.
                        .id(character)
                        .transition(.push(from: .top))
                }
                .clipped()
            }
        }
        .animation(.easeInOut(duration: Motion.digitRoll), value: text)
    }
}
