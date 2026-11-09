import SwiftUI

/// Screen 07: the break is over, the chime plays for at most 1 min, and the screen waits for the user.
struct BreakOverView: View {
    let session: SessionController
    let settings: SettingsStore

    var body: some View {
        VStack(spacing: Metrics.BreakCard.spacing) {
            PausiePoseView(pose: .backToWork, size: Metrics.BreakCard.backToWorkPoseSize)
            Text(L10n.t(.breakOverTitle))
                .typography(.title)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)
            Text(L10n.t(.breakOverBody))
                .typography(.body)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            chimeChip
            Spacer().frame(height: Metrics.BreakCard.buttonTopSpacer)
            Button(L10n.t(.breakActionLetsGo)) {
                session.send(.letsGo)
            }
            .buttonStyle(.pausie(.primary, fullWidth: true))
            .keyboardShortcut(.defaultAction)
            // The next cycle snapshots the settings when it starts, so the current value is what it will use.
            Text(L10n.t(.breakOverNextSession, ["minutes": TimeFormat.number(settings.settings.workMinutes)]))
                .typography(.caption)
                .foregroundStyle(Color(.textSecondary))
        }
        .padding(Metrics.BreakCard.padding)
        .frame(width: Metrics.BreakCard.width)
        .pausieSurface(radius: Radius.lg)
    }

    private var chimeChip: some View {
        HStack(spacing: Metrics.BreakCard.chipSpacing) {
            Image(systemName: Icon.chime)
                .font(TypographyToken.bodyEmphasis.font)
                .accessibilityHidden(true)
            Text(L10n.t(.breakOverChime))
                .typography(.caption)
        }
        .foregroundStyle(Color(.brandPrimary))
        .padding(Metrics.BreakCard.chipPadding)
        .background(Capsule().fill(Color(.brandLavenderTint)))
    }
}
