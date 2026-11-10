import Foundation

struct Note: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var markdown: String
    let createdAt: Date
    var updatedAt: Date
}

/// Markdown todo helpers. The note is a markdown todo list both while writing and when shown back.
enum TodoMarkdown {
    static let uncheckedMarker = "- [ ]"
    static let checkedMarker = "- [x]"
    static let uncheckedPrefix = uncheckedMarker + " "
    static let checkedPrefix = checkedMarker + " "

    /// What a new note starts with.
    static let template = uncheckedPrefix

    enum Line: Equatable, Sendable {
        case todo(text: String, checked: Bool)
        case text(String)
    }

    /// Splits a note into display lines: `- [ ]` / `- [x]` lines become todos, the rest plain text.
    static func parse(_ markdown: String) -> [Line] {
        guard !markdown.isEmpty else { return [] }
        return lines(of: markdown).map(parseLine)
    }

    static func parseLine(_ raw: String) -> Line {
        let line = raw.trimmingCharacters(in: .whitespaces)
        for (marker, checked) in [(uncheckedMarker, false), (checkedMarker, true), ("- [X]", true)] where line.hasPrefix(marker) {
            let text = line.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
            return .todo(text: text, checked: checked)
        }
        return .text(raw)
    }

    /// Text of each todo row, used by the editor. Non-todo lines keep their full text.
    static func rowTexts(_ markdown: String) -> [String] {
        let rows = lines(of: markdown).map { line -> String in
            switch parseLine(line) {
            case let .todo(text, _): text
            case let .text(text): text
            }
        }
        return rows.isEmpty ? [""] : rows
    }

    /// Builds markdown from editor rows; every row is an unchecked todo.
    static func markdown(fromRows rows: [String]) -> String {
        rows.map { uncheckedPrefix + $0 }.joined(separator: "\n")
    }

    /// On save, empty todo lines and blank lines are dropped wherever they are, so a todo that was
    /// cleared doesn't come back as an empty checkbox. A completely empty note becomes `""` and is
    /// still a valid save.
    static func normalizedForSave(_ markdown: String) -> String {
        lines(of: markdown).filter { !isEmptyLine($0) }.joined(separator: "\n")
    }

    /// Whether a note has any todo text (an empty or template-only note has none).
    static func hasContent(_ markdown: String) -> Bool {
        !normalizedForSave(markdown).isEmpty
    }

    /// Lines shown in the resume panel: empty todos and blank lines are skipped
    /// (notes saved before empty todos were dropped may still contain them).
    static func displayLines(_ markdown: String) -> [Line] {
        parse(markdown).filter { line in
            switch line {
            case let .todo(text, _): !text.isEmpty
            case let .text(text): !text.trimmingCharacters(in: .whitespaces).isEmpty
            }
        }
    }

    static func isEmptyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed == uncheckedMarker || trimmed == checkedMarker
    }

    private static func lines(of markdown: String) -> [String] {
        markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
    }
}
