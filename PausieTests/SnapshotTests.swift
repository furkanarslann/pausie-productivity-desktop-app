import AppKit
import SwiftUI
import Testing
@testable import Pausie

/// Renders every screen in light and dark to PNG for visual review against Figma, at Retina (2x) and
/// at 1x (`-1x` suffix), since thin strokes can look right on one and wrong on the other.
/// Runs only when `PAUSIE_SNAPSHOT_DIR` is set, e.g.
/// `TEST_RUNNER_PAUSIE_SNAPSHOT_DIR=/tmp/pausie-snapshots xcodebuild test …`
@Suite("Snapshots", .enabled(if: ProcessInfo.processInfo.environment["PAUSIE_SNAPSHOT_DIR"] != nil))
@MainActor
struct SnapshotTests {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PAUSIE_SNAPSHOT_DIR"] ?? NSTemporaryDirectory())

    private func render(_ name: String, _ view: some View) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for dark in [false, true] {
            for scale in [2.0, 1.0] {
                let appearance = try #require(NSAppearance(named: dark ? .darkAqua : .aqua))
                var data: Data?
                appearance.performAsCurrentDrawingAppearance {
                    let content = view
                        .padding(48)
                        .background(Color(.surfaceCanvas))
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .environment(\.displayScale, scale)
                    let renderer = ImageRenderer(content: content)
                    renderer.scale = scale
                    if let image = renderer.cgImage {
                        data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
                    }
                }
                let suffix = scale == 1 ? "-1x" : ""
                let file = directory.appending(path: "\(name)-\(dark ? "dark" : "light")\(suffix).png")
                try #require(data).write(to: file)
            }
        }
    }

    private func harness(at state: SessionState) -> SessionHarness {
        let h = SessionHarness()
        h.controller.send(.start)
        switch state {
        case .idle:
            h.controller.send(.stop)
        case .working:
            h.advance(minutes: 7.7)
        case .preBreakPending:
            h.advance(minutes: 45.13)
            h.controller.draft = "- [ ] Finish validation on the login screen\n- [ ] Reply to PR review comments\n- [ ] "
        case .preBreakSnoozed:
            h.advance(minutes: 45)
            h.controller.askLater()
            h.advance(minutes: 1.8)
        case .preBreakNoted:
            h.advance(minutes: 45)
            h.controller.send(.saveNote(markdown: "- [ ] Finish validation"))
            h.advance(minutes: 1.8)
        case .breakNoteRequired:
            h.advance(minutes: 50)
            h.controller.draft = "- [ ] Continue the settings screen layout\n- [ ] "
        case .onBreak:
            h.advance(minutes: 45)
            h.saveNoteAndTakeBreak("- [ ] Finish validation on the login screen\n- [ ] Reply to PR review comments")
            h.advance(minutes: 1.3)
        case .breakOver:
            h.advance(minutes: 45)
            h.saveNoteAndTakeBreak("- [ ] a")
            h.advance(minutes: 10)
        }
        return h
    }

    @Test func menuHeaders() throws {
        for state in [SessionState.idle, .working, .preBreakSnoozed, .preBreakNoted, .onBreak, .breakNoteRequired, .breakOver] {
            let h = harness(at: state)
            try render("01-menu-header-\(state)", MenuHeaderContent(header: MenuPresentation(session: h.controller).header)
                .background(Color(.surfaceWindow)))
        }
    }

    @Test func statusItemLabel() throws {
        let icon = PausieAsset.menuBarIcon()
        try render("00-status-item-working", StatusItemLabel(session: harness(at: .working).controller, icon: icon)
            .frame(height: 24))
        try render("00-status-item-note-required", StatusItemLabel(session: harness(at: .breakNoteRequired).controller, icon: icon)
            .frame(height: 24))
    }

    @Test func noteWindow() throws {
        let h = harness(at: .preBreakPending)
        try render("03-note-window-pending", NoteWindowView(session: h.controller, mode: .pending))
        try render("03-note-window-edit", NoteWindowView(session: h.controller, mode: .edit))
    }

    @Test func breakCards() throws {
        try render("04-break-note-required", BreakCardView(session: harness(at: .breakNoteRequired).controller, mode: .noteRequired))
        try render("05-break-running", BreakCardView(session: harness(at: .onBreak).controller, mode: .running))
        let h = harness(at: .onBreak)
        try render("06-skip-confirm", SkipConfirmView(session: h.controller))
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "PausieSnapshots-\(UUID().uuidString)")!)
        try render("07-break-over", BreakOverView(session: harness(at: .breakOver).controller, settings: settings))
    }

    @Test func resumePanel() throws {
        let note = Note(
            id: UUID(),
            markdown: "- [ ] Finish validation on the login screen\n- [ ] Reply to PR review comments",
            createdAt: Date(),
            updatedAt: Date()
        )
        try render("08-resume-panel", ResumePanelView(note: note) {})
        let empty = Note(id: UUID(), markdown: "", createdAt: Date(), updatedAt: Date())
        try render("08-resume-panel-empty", ResumePanelView(note: empty) {})
    }

    @Test func settings() throws {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "PausieSnapshots-\(UUID().uuidString)")!)
        try render("09-settings", SettingsView(store: store) {})
    }

    @Test func components() throws {
        try render("components-buttons", VStack(spacing: 12) {
            Button("Primary") {}.buttonStyle(.pausiePrimary)
            Button("Disabled") {}.buttonStyle(.pausiePrimary).disabled(true)
            Button("Secondary") {}.buttonStyle(.pausieSecondary)
            Button("Ghost") {}.buttonStyle(.pausieGhost)
            TodoRow(text: "Where I left off")
            TodoRow(text: "Done thing", checked: true)
            PausieBubble(text: "Take a real break. I have your note.")
        })
        try render("components-editor-focused", EditorBox(style: Metrics.Editor.roomy, isFocused: true) {
            VStack(alignment: .leading, spacing: Metrics.Editor.roomy.rowSpacing) {
                TodoRow(text: "Finish validation on the login screen")
                TodoRow(text: "Reply to PR review comments")
                TodoRow(text: "Check the API error states")
            }
        }
        .frame(width: Metrics.NoteWindow.width - Metrics.NoteWindow.contentPadding.leading - Metrics.NoteWindow.contentPadding.trailing))
    }
}
