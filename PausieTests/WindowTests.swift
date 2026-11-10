import AppKit
import Foundation
import Testing
@testable import Pausie

/// Shows real windows on screen, so it runs only when `PAUSIE_WINDOW_TESTS` is set:
/// `TEST_RUNNER_PAUSIE_WINDOW_TESTS=1 xcodebuild test … -only-testing:PausieTests/WindowTests`
@Suite("Windows", .enabled(if: ProcessInfo.processInfo.environment["PAUSIE_WINDOW_TESTS"] != nil), .serialized)
@MainActor
struct WindowTests {
    /// Lines as long as the note that crashed the resume panel (108, 91, 72, 160 and 163 characters).
    private static let longNote: String = [108, 91, 72, 160, 163]
        .map { length in
            TodoMarkdown.uncheckedPrefix + String(repeating: "lorem ipsum ", count: length / 12 + 1).prefix(length)
        }
        .joined(separator: "\n")

    /// Runs a nested run loop, like the status menu's event loop that called `show(note:)` when the app
    /// crashed. Inside a nested loop AppKit lays out synchronously during a window resize, which is where
    /// the old sizing recursed; yielding to the outer run loop instead hides the bug.
    private func spinRunLoop(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    @Test("Opening a long note in the resume panel lays out without looping")
    func resumePanelWithLongNote() throws {
        let note = Note(id: UUID(), markdown: Self.longNote, createdAt: Date(), updatedAt: Date())
        let controller = ResumePanelController(autoCloseDelay: 60)
        controller.show(note: note)
        spinRunLoop(0.5)
        #expect(controller.isVisible)

        // Showing another note in the same panel resizes it again.
        controller.show(note: Note(id: UUID(), markdown: "- [ ] short", createdAt: Date(), updatedAt: Date()))
        spinRunLoop(0.3)
        controller.show(note: note)
        spinRunLoop(0.3)
        controller.close()
        #expect(!controller.isVisible)
    }

    /// Notes whose lines wrap at many different points, to hit the widths where layout and window
    /// size used to feed each other until the stack overflowed.
    static func wrappingNotes() -> [Note] {
        let words = ["save", "and", "keep", "working", "molaya", "çıkalım", "todolar", "arasında", "cursor",
                     "kayboluyor", "sayaç", "fontu", "daha", "ince", "otomatik", "kaydetsin", "break", "starts"]
        return stride(from: 60, through: 170, by: 3).map { length in
            var line = ""
            var index = length
            while line.count < length {
                line += (line.isEmpty ? "" : " ") + words[index % words.count]
                index += 7
            }
            let markdown = (0..<5).map { TodoMarkdown.uncheckedPrefix + line.prefix(length - $0 * 9) }.joined(separator: "\n")
            return Note(id: UUID(), markdown: markdown, createdAt: Date(), updatedAt: Date())
        }
    }

    @Test("Notes that wrap at many widths open without looping and the panel settles")
    func resumePanelWithWrappingNotes() throws {
        let controller = ResumePanelController(autoCloseDelay: 60)
        for note in Self.wrappingNotes() {
            controller.show(note: note)
            spinRunLoop(0.15)
            #expect(controller.isVisible)
            let settled = controller.frame
            spinRunLoop(0.1)
            #expect(controller.frame == settled, "The panel kept resizing")
        }
        controller.close()
    }

    /// Local reproduction against a real notes file; the path comes from the environment, so no note
    /// content lives in the repository.
    @Test("Every note in a notes file opens in the resume panel",
          .enabled(if: ProcessInfo.processInfo.environment["PAUSIE_REPRO_NOTES"] != nil))
    func resumePanelWithNotesFile() throws {
        let path = try #require(ProcessInfo.processInfo.environment["PAUSIE_REPRO_NOTES"])
        let notes = NoteStore(fileURL: URL(fileURLWithPath: path)).notes
        let controller = ResumePanelController(autoCloseDelay: 60)
        for note in notes {
            controller.show(note: note)
            spinRunLoop(0.4)
            #expect(controller.isVisible)
        }
        controller.close()
    }

    @Test("The settings window opens at its content size and stays there")
    func settingsWindow() throws {
        let suite = "PausieWindowTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = SettingsWindowController(store: SettingsStore(defaults: defaults))
        controller.show()
        spinRunLoop(0.4)
        let frame = try #require(controller.frame)
        #expect(frame.width >= Metrics.Settings.width)
        #expect(frame.height > 300 && frame.height < 700)
        spinRunLoop(0.2)
        #expect(controller.frame == frame)
        controller.close()
    }

    @Test("The note window lays out with long lines and many rows")
    func noteWindowWithLongNote() throws {
        let h = SessionHarness()
        h.controller.send(.start)
        h.advance(minutes: 45)
        h.controller.draft = Self.longNote
        let window = NoteWindowController(session: h.controller)
        window.show(mode: .pending)
        spinRunLoop(0.5)
        #expect(window.isVisible)
        let before = try #require(window.frame)

        // More rows than the editor's minimum height holds: the window grows downward, top fixed.
        h.controller.draft = (1...12).map { TodoMarkdown.uncheckedPrefix + "item \($0)" }.joined(separator: "\n")
        spinRunLoop(0.5)
        let after = try #require(window.frame)
        #expect(after.height > before.height)
        #expect(abs(after.maxY - before.maxY) < 1)
        window.close()
    }
}
