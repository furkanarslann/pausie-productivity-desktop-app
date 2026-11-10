import SwiftUI

/// Screen 03b: centered on the main display, editor focused on open.
/// Pending mode (T2) has two buttons; edit mode (T8) has only Save.
struct NoteWindowView: View {
    @Bindable var session: SessionController
    let mode: NoteWindowMode

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.NoteWindow.contentSpacing) {
            header
            TodoEditor(markdown: $session.draft, placeholder: L10n.t(.noteWindowPlaceholder), style: Metrics.Editor.roomy)
            Text(L10n.t(.noteWindowHint))
                .typography(.caption)
                .foregroundStyle(Color(.textSecondary))
            actions
        }
        .padding(Metrics.NoteWindow.contentPadding)
        .frame(width: Metrics.NoteWindow.width)
        .background(Color(.surfaceWindow))
    }

    private var header: some View {
        HStack(spacing: Metrics.NoteWindow.headerSpacing) {
            PausiePoseView(pose: .takingNotes, size: Metrics.NoteWindow.poseSize)
            VStack(alignment: .leading, spacing: Metrics.NoteWindow.headerTextSpacing) {
                Text(L10n.t(.noteWindowQuestion))
                    .typography(.title)
                    .foregroundStyle(Color(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                if let remaining = session.workRemaining {
                    Text(L10n.t(.noteWindowCountdown, ["remaining": TimeFormat.shortCountdown(remaining)]))
                        .typography(.caption)
                        .foregroundStyle(Color(.textSecondary))
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        HStack(spacing: Metrics.NoteWindow.actionSpacing) {
            Spacer(minLength: 0)
            switch mode {
            case .pending:
                Button(L10n.t(.noteWindowActionSaveAndContinue)) {
                    session.send(.saveNoteAndContinue(markdown: session.draft))
                }
                .buttonStyle(.pausieSecondary)

                Button(L10n.t(.noteWindowActionSaveAndBreak)) {
                    session.send(.saveNoteAndBreak(markdown: session.draft))
                }
                .buttonStyle(.pausiePrimary)
                .keyboardShortcut(.return, modifiers: .command)

            case .edit:
                Button(L10n.t(.noteWindowActionSave)) {
                    session.send(.saveNoteAndContinue(markdown: session.draft))
                }
                .buttonStyle(.pausiePrimary)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}
