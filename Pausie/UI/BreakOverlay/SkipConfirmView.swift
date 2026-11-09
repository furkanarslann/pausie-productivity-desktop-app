import SwiftUI

/// Screen 06: asks once before skipping; the gentle option ("Keep resting") is primary and the Return default.
struct SkipConfirmView: View {
    let session: SessionController

    var body: some View {
        VStack(spacing: Metrics.SkipDialog.spacing) {
            PausiePoseView(pose: .thinking, size: Metrics.SkipDialog.poseSize)
            Text(L10n.t(.skipBreakTitle))
                .typography(.headline)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)
            Text(L10n.t(.skipBreakBody))
                .typography(.body)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Metrics.SkipDialog.actionSpacing) {
                Button(L10n.t(.skipBreakActionSkip)) {
                    session.confirmSkipBreak()
                }
                .buttonStyle(.pausie(.secondary, fullWidth: true))

                Button(L10n.t(.skipBreakActionKeepResting)) {
                    session.cancelSkipBreak()
                }
                .buttonStyle(.pausie(.primary, fullWidth: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Metrics.SkipDialog.padding)
        .frame(width: Metrics.SkipDialog.width)
        .pausieSurface(radius: Radius.lg)
        .onExitCommand { session.cancelSkipBreak() }
    }
}
