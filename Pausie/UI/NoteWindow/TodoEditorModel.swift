import Foundation

/// Rows of the todo editor and the edits on them. Pure, so the editing rules are unit-tested.
nonisolated struct TodoEditorModel: Equatable, Sendable {
    struct Row: Identifiable, Equatable, Sendable {
        let id: UUID
        var text: String

        init(id: UUID = UUID(), text: String) {
            self.id = id
            self.text = text
        }
    }

    /// Where the caret goes in the row that receives focus.
    enum Caret: Equatable, Sendable {
        case start
        case end
    }

    struct Focus: Equatable, Sendable {
        let rowID: UUID
        let caret: Caret
    }

    /// Never empty: an empty editor is one empty row.
    private(set) var rows: [Row]

    init(markdown: String) {
        self.init(rows: TodoMarkdown.rowTexts(markdown).map { Row(text: $0) })
    }

    init(rows: [Row]) {
        self.rows = rows.isEmpty ? [Row(text: "")] : rows
    }

    var markdown: String {
        TodoMarkdown.markdown(fromRows: rows.map(\.text))
    }

    var lastRowID: UUID {
        rows[rows.count - 1].id
    }

    /// Typing in a row. Pasted multi-line text is split into rows; the returned focus is the last new row.
    mutating func setText(_ text: String, for id: UUID) -> Focus? {
        guard let index = index(of: id) else { return nil }
        rows[index].text = text
        return normalize()
    }

    /// Return: a new empty row right below.
    mutating func insertRow(after id: UUID) -> Focus? {
        guard let index = index(of: id) else { return nil }
        let row = Row(text: "")
        rows.insert(row, at: index + 1)
        return Focus(rowID: row.id, caret: .end)
    }

    /// Backspace (or forward delete) in an empty row removes the whole todo.
    /// The caret moves to the end of the row above (forward delete: the start of the row below).
    /// The last remaining row is never removed.
    mutating func deleteEmptyRow(_ id: UUID, forward: Bool = false) -> Focus? {
        guard rows.count > 1, let index = index(of: id), rows[index].text.isEmpty else { return nil }
        rows.remove(at: index)
        if forward {
            return index < rows.count
                ? Focus(rowID: rows[index].id, caret: .start)
                : Focus(rowID: rows[index - 1].id, caret: .end)
        }
        return index > 0
            ? Focus(rowID: rows[index - 1].id, caret: .end)
            : Focus(rowID: rows[0].id, caret: .start)
    }

    /// ↑ / ↓ between rows.
    func neighbor(of id: UUID, offset: Int) -> Focus? {
        guard let index = index(of: id), rows.indices.contains(index + offset) else { return nil }
        return Focus(rowID: rows[index + offset].id, caret: .end)
    }

    /// Splits multi-line text and strips typed `- [ ]` markers so every row holds plain text.
    mutating func normalize() -> Focus? {
        var result: [Row] = []
        var lastNewRow: UUID?
        for row in rows {
            let texts = TodoMarkdown.rowTexts(row.text)
            if texts == [row.text] {
                result.append(row)
                continue
            }
            result.append(Row(id: row.id, text: texts.first ?? ""))
            for text in texts.dropFirst() {
                let newRow = Row(text: text)
                result.append(newRow)
                lastNewRow = newRow.id
            }
        }
        rows = result.isEmpty ? [Row(text: "")] : result
        return lastNewRow.map { Focus(rowID: $0, caret: .end) }
    }

    private func index(of id: UUID) -> Int? {
        rows.firstIndex { $0.id == id }
    }
}
