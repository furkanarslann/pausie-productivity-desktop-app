import SwiftUI

/// Markdown todo editor. Each line is a `- [ ]` row with its own text field:
/// Return starts a new row, Backspace in an empty row removes that todo, ↑/↓ move between rows.
/// The bound markdown is the single source of truth (the session draft), so a draft typed in the
/// note window shows up in the required-note editor (T5).
struct TodoEditor: View {
    @Binding var markdown: String
    let placeholder: String

    @State private var model = TodoEditorModel(markdown: "")
    @State private var focus: TodoEditorModel.Focus?

    var body: some View {
        EditorBox {
            VStack(alignment: .leading, spacing: Metrics.Editor.rowSpacing) {
                ForEach(model.rows) { row in
                    rowView(row)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: markdown) { _, newValue in
            // External change (e.g. a new cycle reset the draft): rebuild rows.
            if newValue != model.markdown { load() }
        }
    }

    private func rowView(_ row: TodoEditorModel.Row) -> some View {
        HStack(alignment: .top, spacing: Metrics.TodoRow.spacing) {
            TodoCheckbox()
            TodoTextField(
                text: Binding(
                    get: { row.text },
                    set: { newText in apply(model.setText(newText, for: row.id)) }
                ),
                placeholder: row.id == model.lastRowID ? placeholder : nil,
                accessibilityLabel: placeholder,
                focusCaret: focus?.rowID == row.id ? focus?.caret : nil,
                onCommand: { handle($0, in: row.id) },
                onFocusApplied: {
                    if focus?.rowID == row.id { focus = nil }
                }
            )
            .frame(minHeight: TypographyToken.body.spec.lineHeight)
        }
        .padding(.vertical, Metrics.TodoRow.verticalPadding)
    }

    // MARK: - Editing

    private func load() {
        model = TodoEditorModel(markdown: markdown)
        focus = TodoEditorModel.Focus(rowID: model.lastRowID, caret: .end)
    }

    private func handle(_ command: TodoTextField.Command, in rowID: UUID) -> Bool {
        let newFocus: TodoEditorModel.Focus?
        switch command {
        case .newline:
            newFocus = model.insertRow(after: rowID)
        case .deleteBackwardWhenEmpty:
            newFocus = model.deleteEmptyRow(rowID)
        case .deleteForwardWhenEmpty:
            newFocus = model.deleteEmptyRow(rowID, forward: true)
        case .moveUp:
            newFocus = model.neighbor(of: rowID, offset: -1)
        case .moveDown:
            newFocus = model.neighbor(of: rowID, offset: 1)
        }
        guard let newFocus else { return false }
        apply(newFocus)
        return true
    }

    /// Writes the rows back to the bound markdown and moves focus if an edit asked for it.
    private func apply(_ newFocus: TodoEditorModel.Focus?) {
        if let newFocus { focus = newFocus }
        let composed = model.markdown
        if composed != markdown { markdown = composed }
    }
}
