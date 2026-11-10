import SwiftUI

/// Figma `Todo row` checkbox: 16x16, radius 5, 1.5pt lavender stroke. Read-only.
struct TodoCheckbox: View {
    var checked = false

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.checkbox)
            .fill(checked ? Color(.brandPrimary) : Color(.surfaceWindow))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.checkbox)
                    .strokeBorder(checked ? Color(.brandPrimary) : Color(.brandLavender), lineWidth: BorderWidth.checkbox)
            }
            .overlay {
                if checked {
                    Image(systemName: Icon.checkmark)
                        .font(.system(size: Metrics.TodoRow.checkmarkSize, weight: .bold))
                        .foregroundStyle(Color(.textOnPrimary))
                }
            }
            .frame(width: Metrics.TodoRow.checkboxSize, height: Metrics.TodoRow.checkboxSize)
            .padding(.top, Metrics.TodoRow.checkboxTopInset)
            .accessibilityHidden(true)
    }
}

/// One markdown todo line (`- [ ] …`), read-only. Used by the resume panel.
struct TodoRow: View {
    let text: String
    var checked = false
    var isPlaceholder = false

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.TodoRow.spacing) {
            TodoCheckbox(checked: checked)
            Text(text)
                .typography(.body)
                .foregroundStyle(Color(isPlaceholder ? .textSecondary : .textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.vertical, Metrics.TodoRow.verticalPadding)
    }
}

/// Renders a note's markdown: todo lines as `TodoRow`, other lines as plain text.
struct NoteMarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.ResumePanel.todoSpacing) {
            ForEach(Array(TodoMarkdown.displayLines(markdown).enumerated()), id: \.offset) { _, line in
                switch line {
                case let .todo(text, checked):
                    TodoRow(text: text, checked: checked)
                case let .text(text):
                    Text(text)
                        .typography(.body)
                        .foregroundStyle(Color(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, Metrics.TodoRow.verticalPadding)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
