import SwiftUI

/// Screen 09. Durations apply on Save (from the next cycle, rule 11); appearance applies right away.
struct SettingsView: View {
    let store: SettingsStore
    let onClose: () -> Void

    @State private var workMinutes: Int
    @State private var breakMinutes: Int

    init(store: SettingsStore, onClose: @escaping () -> Void) {
        self.store = store
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
    }

    /// Appearance is bound straight to the store so it applies immediately.
    private var appearance: Binding<AppearancePreference> {
        Binding(get: { store.settings.appearance }, set: { store.setAppearance($0) })
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
