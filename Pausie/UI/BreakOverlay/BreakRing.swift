import SwiftUI

/// Screen 05 break ring: a `brand/lavender` track at 30% and a `brand/primary` arc for the time left.
/// The arc ends at 12 o'clock and its start moves clockwise as the break runs, around the relaxed pose.
struct BreakRing: View {
    /// Elapsed share of the break, 0...1.
    let progress: Double

    var body: some View {
        let lineWidth = Metrics.BreakCard.ringLineWidth
        ZStack {
            Circle()
                .stroke(Color(.brandLavender).opacity(OpacityToken.ringTrack), lineWidth: lineWidth)
            Circle()
                .trim(from: min(1, max(0, progress)), to: 1)
                .stroke(Color(.brandPrimary), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                // Circle paths start at 3 o'clock; start the ring at 12.
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .frame(width: Metrics.BreakCard.ringDiameter, height: Metrics.BreakCard.ringDiameter)
        .frame(width: Metrics.BreakCard.ringSize, height: Metrics.BreakCard.ringSize)
        .overlay {
            PausiePoseView(pose: .relaxed, size: Metrics.BreakCard.ringPoseSize)
                .offset(y: Metrics.BreakCard.ringPoseOffsetY)
        }
        .accessibilityHidden(true)
    }
}
