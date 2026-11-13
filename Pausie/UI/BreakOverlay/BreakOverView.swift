import SwiftUI

/// Screen 07: the break is over, the sound plays for at most 1 min, and the screen waits for the user.
/// The sound chip names the sound and opens Settings to change it.
struct BreakOverView: View {
    let session: SessionController
    let settings: SettingsStore
    let onChangeSound: () -> Void

    var body: some View {
        VStack(spacing: Metrics.BreakCard.spacing) {
            PausiePoseView(pose: .backToWork, size: Metrics.BreakCard.backToWorkPoseSize)
            Text(L10n.t(.breakOverTitle))
                .typography(.title)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)
            Text(L10n.t(session.hasNoteThisCycle ? .breakOverBody : .breakOverBodyNoNote))
                .typography(.body)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            soundChip
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

    private var soundChip: some View {
        let name = L10n.t(settings.settings.breakSound.nameKey)
        return Button(action: onChangeSound) {
            HStack(spacing: Metrics.BreakCard.chipSpacing) {
                Image(systemName: Icon.chime)
                    .font(TypographyToken.bodyEmphasis.font)
                    .accessibilityHidden(true)
                Text(L10n.t(.breakOverSound, ["sound": name]))
                    .typography(.caption)
                Image(systemName: Icon.disclosure)
                    .font(.system(size: Metrics.BreakCard.chipDisclosureSize, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color(.brandPrimary))
            .padding(Metrics.BreakCard.chipPadding)
            .background(Capsule().fill(Color(.brandLavenderTint)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(L10n.t(.breakOverSoundHelp))
        .accessibilityHint(L10n.t(.breakOverSoundHelp))
    }
}
