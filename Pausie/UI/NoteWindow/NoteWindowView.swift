import SwiftUI

/// Screen 03b: centered on the main display, editor focused on open. There is no early break here:
/// "Save" (T3) keeps working until the break starts on time; "Ask me later" (T14) closes it until the
/// next reminder; "Skip note for this session" (T18) means there is nothing to note this time.
/// Opened from "Edit note" (T8) it only has "Save".
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
            if mode == .pending {
                // Nothing to note this cycle: the break starts on time and no note is saved.
                Button(L10n.t(.noteWindowActionSkip)) {
                    session.skipNote()
                }
                .buttonStyle(.pausieGhost)
            }
            Spacer(minLength: 0)
            if mode == .pending {
                // Not ready yet: the window comes back at 3 and 1 min left, then the break screen asks.
                Button(L10n.t(.noteWindowActionAskLater)) {
                    session.askLater()
                }
                .buttonStyle(.pausieSecondary)
                .keyboardShortcut(.cancelAction)
            }

            Button(L10n.t(.noteWindowActionSave)) {
                session.send(.saveNote(markdown: session.draft))
            }
            .buttonStyle(.pausiePrimary)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}
