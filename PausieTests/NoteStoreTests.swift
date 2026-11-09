import Foundation
import Testing
@testable import Pausie

@Suite("NoteStore")
@MainActor
struct NoteStoreTests {
    private func makeNote(_ text: String, minutesAgo: Double = 0) -> Note {
        let date = Date(timeIntervalSince1970: 1_800_000_000 - minutesAgo * 60)
        return Note(id: UUID(), markdown: text, createdAt: date, updatedAt: date)
    }

    @Test("Newest first, at most 5; the sixth removes the oldest")
    func capacity() {
        let store = NoteStore(fileURL: TestFiles.temporaryNotesURL())
        for index in 1...6 {
            store.upsert(makeNote("- [ ] \(index)", minutesAgo: Double(10 - index)))
        }
        #expect(store.notes.count == 5)
        #expect(store.notes.map(\.markdown) == ["- [ ] 6", "- [ ] 5", "- [ ] 4", "- [ ] 3", "- [ ] 2"])
    }

    @Test("Saving the same id updates the record in place")
    func update() {
        let store = NoteStore(fileURL: TestFiles.temporaryNotesURL())
        var note = makeNote("- [ ] a")
        store.upsert(note)
        store.upsert(makeNote("- [ ] b"))
        note.markdown = "- [ ] a2"
        store.upsert(note)
        #expect(store.notes.count == 2)
        #expect(store.notes.map(\.markdown) == ["- [ ] b", "- [ ] a2"])
    }

    @Test("Notes survive a relaunch")
    func persistence() {
        let url = TestFiles.temporaryNotesURL()
        let store = NoteStore(fileURL: url)
        for index in 1...3 {
            store.upsert(makeNote("- [ ] \(index)", minutesAgo: Double(10 - index)))
        }
        let reloaded = NoteStore(fileURL: url)
        #expect(reloaded.notes.map(\.markdown) == ["- [ ] 3", "- [ ] 2", "- [ ] 1"])
        #expect(reloaded.notes.map(\.id) == store.notes.map(\.id))
    }

    @Test("A missing or corrupt file loads as empty")
    func corruptFile() throws {
        let url = TestFiles.temporaryNotesURL()
        #expect(NoteStore(fileURL: url).notes.isEmpty)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(NoteStore(fileURL: url).notes.isEmpty)
    }
}

@Suite("TodoMarkdown")
struct TodoMarkdownTests {
    @Test("Trailing empty todo lines are dropped on save")
    func normalize() {
        #expect(TodoMarkdown.normalizedForSave("- [ ] a\n- [ ] \n- [ ] ") == "- [ ] a")
        #expect(TodoMarkdown.normalizedForSave("- [ ] a\n- [ ] \n- [ ] b") == "- [ ] a\n- [ ] \n- [ ] b")
        #expect(TodoMarkdown.normalizedForSave("- [ ] a\r\n\n") == "- [ ] a")
    }

    @Test("A completely empty note is a valid save")
    func emptyNote() {
        #expect(TodoMarkdown.normalizedForSave("- [ ] ") == "")
        #expect(TodoMarkdown.normalizedForSave("") == "")
    }

    @Test("Todo and plain lines are parsed for display")
    func parse() {
        let lines = TodoMarkdown.parse("- [ ] open\n- [x] done\nplain text\n  - [ ]  spaced")
        #expect(lines == [
            .todo(text: "open", checked: false),
            .todo(text: "done", checked: true),
            .text("plain text"),
            .todo(text: "spaced", checked: false),
        ])
        #expect(TodoMarkdown.parse("").isEmpty)
    }

    @Test("Editor rows round-trip to markdown")
    func rows() {
        #expect(TodoMarkdown.rowTexts("- [ ] a\n- [ ] b") == ["a", "b"])
        #expect(TodoMarkdown.rowTexts("") == [""])
        #expect(TodoMarkdown.markdown(fromRows: ["a", "b"]) == "- [ ] a\n- [ ] b")
        #expect(TodoMarkdown.markdown(fromRows: [""]) == TodoMarkdown.template)
    }
}

@Suite("Settings")
struct SettingsTests {
    @Test("Defaults are 50/10, system appearance")
    func defaults() {
        let settings = Settings()
        #expect(settings.workMinutes == 50)
        #expect(settings.breakMinutes == 10)
        #expect(settings.appearance == .system)
    }

    @Test("Work can't be 5 min or less; break is at least 1")
    func validation() {
        #expect(!Settings(workMinutes: 5, breakMinutes: 10).isValid)
        #expect(Settings(workMinutes: 6, breakMinutes: 1).isValid)
        #expect(!Settings(workMinutes: 50, breakMinutes: 0).isValid)
        #expect(Settings(workMinutes: 3, breakMinutes: 0).validated() == Settings(workMinutes: 6, breakMinutes: 1))
    }

    @Test("SettingsStore persists and applies appearance immediately")
    @MainActor
    func store() throws {
        let suite = "PausieTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(defaults: defaults)
        var applied: [AppearancePreference] = []
        store.onAppearanceChange = { applied.append($0) }

        store.setAppearance(.dark)
        store.update(Settings(workMinutes: 25, breakMinutes: 5, appearance: .dark))
        #expect(applied == [.dark])

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.settings == Settings(workMinutes: 25, breakMinutes: 5, appearance: .dark))
    }
}
