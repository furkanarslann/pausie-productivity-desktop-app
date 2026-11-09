import SwiftUI

/// Markdown todo editor. Each line is a `- [ ]` row with its own text field:
/// Return starts a new row, Backspace on an empty row removes it, ↑/↓ move between rows.
/// The bound markdown is the single source of truth (the session draft), so a draft typed in the
/// note window shows up in the required-note editor (T5).
struct TodoEditor: View {
    @Binding var markdown: String
    let placeholder: String

    @State private var rows: [EditorRow] = []
    @FocusState private var focusedRow: EditorRow.ID?

    nonisolated struct EditorRow: Identifiable, Equatable, Sendable {
        let id: UUID
        var text: String

        init(id: UUID = UUID(), text: String) {
            self.id = id
            self.text = text
        }
    }

    var body: some View {
        EditorBox {
            VStack(alignment: .leading, spacing: Metrics.Editor.rowSpacing) {
                ForEach($rows) { $row in
                    rowView($row)
                }
            }
        }
        .onAppear(perform: loadRows)
        .onChange(of: rows) { _, newRows in
            let normalized = Self.normalize(newRows)
            if normalized != newRows {
                rows = normalized
                return
            }
            let composed = TodoMarkdown.markdown(fromRows: newRows.map(\.text))
            if composed != markdown { markdown = composed }
        }
        .onChange(of: markdown) { _, newValue in
            // External change (e.g. a new cycle reset the draft): rebuild rows.
            if newValue != TodoMarkdown.markdown(fromRows: rows.map(\.text)) { loadRows() }
        }
    }

    private func rowView(_ row: Binding<EditorRow>) -> some View {
        let id = row.wrappedValue.id
        let isLast = rows.last?.id == id
        return HStack(alignment: .top, spacing: Metrics.TodoRow.spacing) {
            TodoCheckbox()
            TextField(text: row.text, prompt: nil) {
                Text(placeholder)
            }
            .textFieldStyle(.plain)
            .font(TypographyToken.body.font)
            .foregroundStyle(Color(.textPrimary))
            .frame(minHeight: TypographyToken.body.spec.lineHeight)
            .overlay(alignment: .leading) {
                if row.wrappedValue.text.isEmpty && isLast {
                    Text(placeholder)
                        .font(TypographyToken.body.font)
                        .foregroundStyle(Color(.textSecondary))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .focused($focusedRow, equals: id)
            .onSubmit { insertRow(after: id) }
            .onKeyPress(.delete) { removeIfEmpty(id) ? .handled : .ignored }
            .onKeyPress(.upArrow) { moveFocus(from: id, by: -1) ? .handled : .ignored }
            .onKeyPress(.downArrow) { moveFocus(from: id, by: 1) ? .handled : .ignored }
        }
        .padding(.vertical, Metrics.TodoRow.verticalPadding)
    }

    // MARK: - Editing

    private func loadRows() {
        rows = TodoMarkdown.rowTexts(markdown).map { EditorRow(text: $0) }
        focus(rows.last?.id)
    }

    private func insertRow(after id: EditorRow.ID) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        let row = EditorRow(text: "")
        rows.insert(row, at: index + 1)
        focus(row.id)
    }

    private func removeIfEmpty(_ id: EditorRow.ID) -> Bool {
        guard rows.count > 1,
              let index = rows.firstIndex(where: { $0.id == id }),
              rows[index].text.isEmpty else { return false }
        rows.remove(at: index)
        focus(rows[max(0, index - 1)].id)
        return true
    }

    private func moveFocus(from id: EditorRow.ID, by offset: Int) -> Bool {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return false }
        let target = index + offset
        guard rows.indices.contains(target) else { return false }
        focus(rows[target].id)
        return true
    }

    private func focus(_ id: EditorRow.ID?) {
        // The new field may not be in the hierarchy yet; focus on the next run loop turn.
        DispatchQueue.main.async { focusedRow = id }
    }

    /// Splits pasted multi-line text and strips typed `- [ ]` markers so every row holds plain text.
    nonisolated static func normalize(_ rows: [EditorRow]) -> [EditorRow] {
        var result: [EditorRow] = []
        for row in rows {
            let texts = TodoMarkdown.rowTexts(row.text)
            if texts == [row.text] {
                result.append(row)
            } else {
                result.append(EditorRow(id: row.id, text: texts.first ?? ""))
                result.append(contentsOf: texts.dropFirst().map { EditorRow(text: $0) })
            }
        }
        return result.isEmpty ? [EditorRow(text: "")] : result
    }
}
