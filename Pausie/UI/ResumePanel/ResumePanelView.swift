import AppKit
import SwiftUI

/// Where the panel was opened from. The header follows it: "Welcome back!" only fits the return from a
/// break.
enum ResumePanelOrigin: Equatable, Sendable {
    /// "Let's go!" or a skipped break (T11, T12).
    case breakEnded
    /// A note picked from Recent notes in the menu.
    case recentNotes

    var pose: PausiePose {
        switch self {
        case .breakEnded: .happy
        case .recentNotes: .thinking
        }
    }

    var titleKey: L10nKey {
        switch self {
        case .breakEnded: .resumeTitle
        case .recentNotes: .resumeRecentTitle
        }
    }

    var subtitleKey: L10nKey {
        switch self {
        case .breakEnded: .resumeSubtitle
        case .recentNotes: .resumeRecentSubtitle
        }
    }
}

/// Screen 08: the saved note as a read-only todo list, with a copy button that puts the raw markdown
/// on the pasteboard and shows "Copied!" for 1.5 s.
struct ResumePanelView: View {
    let note: Note
    let origin: ResumePanelOrigin
    let onClose: () -> Void
    /// Pointer entered (`true`) or left the panel; pauses the auto-close countdown.
    var onHoverChange: (Bool) -> Void = { _ in }

    @State private var showsCopied = false
    @State private var copiedResetTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Above the rows so the "Copied!" tooltip isn't covered.
            header.zIndex(1)
            HairlineDivider()
            todos
            footer
        }
        .frame(width: Metrics.ResumePanel.width)
        .pausieSurface(radius: Radius.md, shadow: false)
        .onHover(perform: onHoverChange)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Metrics.ResumePanel.headerSpacing) {
            PausiePoseView(pose: origin.pose, size: Metrics.ResumePanel.poseSize)
            VStack(alignment: .leading, spacing: Metrics.ResumePanel.headerTextSpacing) {
                Text(L10n.t(origin.titleKey))
                    .typography(.headline)
                    .foregroundStyle(Color(.textPrimary))
                Text(L10n.t(origin.subtitleKey))
                    .typography(.caption)
                    .foregroundStyle(Color(.textSecondary))
            }
            .padding(.top, Metrics.ResumePanel.headerTextTopPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            copyButton
        }
        .padding(Metrics.ResumePanel.headerPadding)
    }

    private var copyButton: some View {
        Button(action: copy) {
            Image(systemName: Icon.copy)
                .font(.system(size: Metrics.ResumePanel.copyIconSize))
                .foregroundStyle(Color(.brandPrimary))
                .frame(width: Metrics.ResumePanel.copyButtonSize, height: Metrics.ResumePanel.copyButtonSize)
                .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color(.brandLavenderTint)))
                .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("c", modifiers: .command)
        .accessibilityLabel(L10n.t(.resumeCopyAccessibilityLabel))
        .help(L10n.t(.resumeCopyAccessibilityLabel))
        .overlay(alignment: .topTrailing) {
            if showsCopied {
                CopiedTooltip()
                    .fixedSize()
                    .offset(y: Metrics.ResumePanel.copyButtonSize + Metrics.ResumePanel.tooltipOffset)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var todos: some View {
        Group {
            if TodoMarkdown.displayLines(note.markdown).isEmpty {
                Text(L10n.t(.resumeEmptyNote))
                    .typography(.body)
                    .foregroundStyle(Color(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                NoteMarkdownView(markdown: note.markdown)
            }
        }
        .padding(Metrics.ResumePanel.todoPadding)
    }

    private var footer: some View {
        HStack(spacing: Metrics.ResumePanel.footerSpacing) {
            Text(L10n.t(.resumeSavedAt, ["time": TimeFormat.clockTime(note.updatedAt)]))
                .typography(.caption)
                .foregroundStyle(Color(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(L10n.t(.resumeActionClose), action: onClose)
                .buttonStyle(.pausieGhost)
                .keyboardShortcut(.cancelAction)
        }
        .padding(Metrics.ResumePanel.footerPadding)
        .background(Color(.surfaceCanvas))
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(note.markdown, forType: .string)
        withAnimation { showsCopied = true }
        copiedResetTask?.cancel()
        copiedResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(SessionRules.copiedFeedbackDuration))
            guard !Task.isCancelled else { return }
            withAnimation { showsCopied = false }
        }
    }
}

/// "Copied!" tooltip: `brand/ink` fill with `surface/window` text, so it inverts in dark mode.
private struct CopiedTooltip: View {
    var body: some View {
        Text(L10n.t(.resumeCopied))
            .typography(.caption)
            .foregroundStyle(Color(.surfaceWindow))
            .padding(Metrics.ResumePanel.tooltipPadding)
            .background(RoundedRectangle(cornerRadius: Radius.tooltip).fill(Color(.brandInk)))
            .accessibilityAddTraits(.updatesFrequently)
    }
}
