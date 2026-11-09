import SwiftUI

/// Figma `Pausie bubble`: one short sentence, no tail; the small bottom-left corner is the speech cue.
struct PausieBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .typography(.headline)
            .foregroundStyle(Color(.brandInk))
            .multilineTextAlignment(.center)
            .padding(.vertical, Metrics.Bubble.verticalPadding)
            .padding(.horizontal, Metrics.Bubble.horizontalPadding)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: Radius.bubble,
                    bottomLeadingRadius: Radius.bubbleTail,
                    bottomTrailingRadius: Radius.bubble,
                    topTrailingRadius: Radius.bubble
                )
                .fill(Color(.brandLavenderTint))
            )
    }
}
