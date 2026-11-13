import SwiftUI

/// Screen 09. Durations apply on Save (from the next cycle, rule 9); the break sound and appearance
/// apply right away. Picking a sound plays a preview.
struct SettingsView: View {
    let store: SettingsStore
    let player: ChimePlayer
    let onClose: () -> Void

    @State private var workMinutes: Int
    @State private var breakMinutes: Int

    init(store: SettingsStore, player: ChimePlayer, onClose: @escaping () -> Void) {
        self.store = store
        self.player = player
        self.onClose = onClose
        _workMinutes = State(initialValue: store.settings.workMinutes)
        _breakMinutes = State(initialValue: store.settings.breakMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Settings.contentSpacing) {
            header
            VStack(alignment: .leading, spacing: Metrics.Settings.groupSpacing) {
                row(L10n.t(.settingsWorkLabel)) {
                    DurationStepper(
                        minutes: $workMinutes,
                        range: Settings.workMinutesRange,
                        step: SettingsStep.work,
                        accessibilityLabel: L10n.t(.settingsWorkLabel)
                    )
                }
                helpText(L10n.t(.settingsWorkHelp, ["minutes": TimeFormat.number(SessionRules.warningLeadMinutes)]))
            }
            row(L10n.t(.settingsBreakLabel)) {
                DurationStepper(
                    minutes: $breakMinutes,
                    range: Settings.breakMinutesRange,
                    step: SettingsStep.breakTime,
                    accessibilityLabel: L10n.t(.settingsBreakLabel)
                )
            }
            VStack(alignment: .leading, spacing: Metrics.Settings.groupSpacing) {
                row(L10n.t(.settingsSoundLabel)) {
                    HStack(spacing: Metrics.Settings.soundControlSpacing) {
                        soundPicker
                        previewButton
                    }
                }
                helpText(L10n.t(.settingsSoundHelp))
            }
            VStack(alignment: .leading, spacing: Metrics.Settings.groupSpacing) {
                row(L10n.t(.settingsAppearanceLabel)) {
                    SegmentedPicker(selection: appearance, options: [
                        (AppearancePreference.system, L10n.t(.settingsAppearanceSystem)),
                        (.light, L10n.t(.settingsAppearanceLight)),
                        (.dark, L10n.t(.settingsAppearanceDark)),
                    ])
                }
                helpText(L10n.t(.settingsAppearanceHelp))
            }
            Text(L10n.t(.settingsInfo))
                .typography(.body)
                .foregroundStyle(Color(.brandPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(Metrics.Settings.infoPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color(.brandLavenderTint)))
            actions
        }
        .padding(Metrics.Settings.contentPadding)
        .frame(width: Metrics.Settings.width)
        .background(Color(.surfaceWindow))
        .onDisappear { player.stopPreview() }
    }

    /// Appearance is bound straight to the store so it applies immediately.
    private var appearance: Binding<AppearancePreference> {
        Binding(get: { store.settings.appearance }, set: { store.setAppearance($0) })
    }

    /// The break sound is saved as soon as it's picked, and plays once so the user hears it.
    private var breakSound: Binding<BreakSound> {
        Binding(get: { store.settings.breakSound }, set: { sound in
            store.setBreakSound(sound)
            player.preview(sound)
        })
    }

    private var soundPicker: some View {
        Picker(L10n.t(.settingsSoundLabel), selection: breakSound) {
            Section(L10n.t(.settingsSoundMusic)) {
                ForEach(BreakSound.music, id: \.self) { sound in
                    Text(L10n.t(sound.nameKey)).tag(sound)
                }
            }
            Section(L10n.t(.settingsSoundChimes)) {
                ForEach(BreakSound.chimes, id: \.self) { sound in
                    Text(L10n.t(sound.nameKey)).tag(sound)
                }
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }

    private var previewButton: some View {
        let isPreviewing = player.previewing != nil
        let label = L10n.t(isPreviewing ? .settingsSoundStopPreview : .settingsSoundPreview)
        return Button {
            if isPreviewing {
                player.stopPreview()
            } else {
                player.preview(store.settings.breakSound)
            }
        } label: {
            Image(systemName: isPreviewing ? Icon.previewStop : Icon.previewPlay)
                .font(.system(size: Metrics.Stepper.iconSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(.brandPrimary))
                .frame(width: Metrics.Stepper.buttonSize, height: Metrics.Stepper.height)
                .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color(.brandLavenderTint)))
                .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var header: some View {
        HStack(spacing: Metrics.Settings.headerSpacing) {
            PausiePoseView(pose: .focused, size: Metrics.Settings.poseSize)
            VStack(alignment: .leading, spacing: Metrics.Settings.headerTextSpacing) {
                Text(L10n.t(.settingsHeaderTitle))
                    .typography(.headline)
                    .foregroundStyle(Color(.textPrimary))
                Text(L10n.t(.settingsHeaderSubtitle))
                    .typography(.caption)
                    .foregroundStyle(Color(.textSecondary))
            }
        }
    }

    private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: Metrics.Settings.rowSpacing) {
            Text(label)
                .typography(.bodyEmphasis)
                .foregroundStyle(Color(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
            control()
                .fixedSize()
        }
    }

    private func helpText(_ text: String) -> some View {
        Text(text)
            .typography(.caption)
            .foregroundStyle(Color(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        HStack(spacing: Metrics.Settings.actionSpacing) {
            Spacer(minLength: 0)
            Button(L10n.t(.settingsActionCancel), action: onClose)
                .buttonStyle(.pausieGhost)
                .keyboardShortcut(.cancelAction)
            Button(L10n.t(.settingsActionSave)) {
                var updated = store.settings
                updated.workMinutes = workMinutes
                updated.breakMinutes = breakMinutes
                store.update(updated)
                onClose()
            }
            .buttonStyle(.pausiePrimary)
            .keyboardShortcut(.defaultAction)
        }
    }
}

/// Stepper increments.
enum SettingsStep {
    static let work = 5
    static let breakTime = 1
}
