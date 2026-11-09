import Foundation
import Observation
import os

/// Keeps the last 5 notes, newest first, in `~/Library/Application Support/Pausie/notes.json`.
@MainActor
@Observable
final class NoteStore {
    static let capacity = 5

    private(set) var notes: [Note] = []

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let logger = Logger(subsystem: "com.furkanarslan.Pausie", category: "NoteStore")

    init(fileURL: URL = NoteStore.defaultFileURL) {
        self.fileURL = fileURL
        notes = Self.load(from: fileURL)
    }

    nonisolated static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return support.appending(path: "Pausie", directoryHint: .isDirectory).appending(path: "notes.json")
    }

    var latest: Note? { notes.first }

    func note(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    /// Inserts a new note or updates the record with the same id; keeps at most `capacity` notes.
    func upsert(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.insert(note, at: 0)
        }
        if notes.count > Self.capacity {
            notes.removeLast(notes.count - Self.capacity)
        }
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try Self.encoder.encode(notes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Saving notes failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from url: URL) -> [Note] {
        guard let data = try? Data(contentsOf: url),
              let notes = try? decoder.decode([Note].self, from: data) else { return [] }
        return Array(notes.sorted { $0.createdAt > $1.createdAt }.prefix(capacity))
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
