import SwiftUI

/// Screen 04 (`.noteRequired`) and screen 05 (`.running`).
struct BreakCardView: View {
    enum Mode {
        case noteRequired
        case running
    }

    @Bindable var session: SessionController
    let mode: Mode

    var body: some View {
        switch mode {
        case .noteRequired: noteRequired
        case .running: running
        }
    }

    // MARK: - Screen 04

    private var noteRequired: some View {
        VStack(spacing: Metrics.BreakCard.requiredSpacing) {
            PausiePoseView(pose: .takingNotes, size: Metrics.BreakCard.requiredPoseSize)
            Text(L10n.t(.breakNoteRequiredTitle))
                .typography(.title)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)
            Text(L10n.t(.breakNoteRequiredBody))
                .typography(.body)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            TodoEditor(markdown: $session.draft, placeholder: L10n.t(.breakNoteRequiredPlaceholder))
            Button(L10n.t(.breakNoteRequiredAction)) {
                session.send(.saveRequiredNote(markdown: session.draft))
            }
            .buttonStyle(.pausie(.primary, fullWidth: true))
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(Metrics.BreakCard.padding)
        .frame(width: Metrics.BreakCard.requiredWidth)
        .pausieSurface(radius: Radius.lg)
    }

    // MARK: - Screen 05

    private var running: some View {
        VStack(spacing: Metrics.BreakCard.spacing) {
            PausiePoseView(pose: .relaxed, size: Metrics.BreakCard.relaxedPoseSize)
            PausieBubble(text: L10n.t(.breakBubble))
            Text(TimeFormat.countdown(session.breakRemaining ?? 0))
                .typography(.timer)
                .foregroundStyle(Color(.textPrimary))
                .contentTransition(.numericText(countsDown: true))
            if let endsAt = session.breakEndsAt {
                Text(L10n.t(.breakEndsAt, ["time": TimeFormat.clockTime(endsAt)]))
                    .typography(.caption)
                    .foregroundStyle(Color(.textSecondary))
            }
            Spacer().frame(height: Metrics.BreakCard.buttonTopSpacer)
            // Rule 2: disabled until the break ends; the only early exit is "Skip break…" in the menu bar.
            Button(L10n.t(.breakActionLetsGo)) {
                session.send(.letsGo)
            }
            .buttonStyle(.pausie(.primary, fullWidth: true))
            .disabled(true)
            Text(L10n.t(.breakActionDisabledHint))
                .typography(.caption)
                .foregroundStyle(Color(.textSecondary))
        }
        .padding(Metrics.BreakCard.padding)
        .frame(width: Metrics.BreakCard.width)
        .pausieSurface(radius: Radius.lg)
    }
}
