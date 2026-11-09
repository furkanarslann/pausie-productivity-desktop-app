import Foundation
import Testing
@testable import Pausie

@Suite("L10n")
struct L10nTests {
    private var english: [String: String] {
        L10nCatalog.table(named: "en", in: .main) ?? [:]
    }

    @Test("en.json is bundled and parses")
    func catalogLoads() {
        #expect(!english.isEmpty)
    }

    @Test("Every L10nKey exists in en.json")
    func everyKeyExists() {
        let missing = L10nKey.allCases.filter { english[$0.rawValue] == nil }
        #expect(missing.isEmpty, "Missing keys: \(missing.map(\.rawValue))")
    }

    @Test("Every en.json entry has an L10nKey")
    func noOrphanEntries() {
        let known = Set(L10nKey.allCases.map(\.rawValue))
        let orphans = english.keys.filter { !known.contains($0) }.sorted()
        #expect(orphans.isEmpty, "Unused keys: \(orphans)")
    }

    @Test("No entry is empty")
    func noEmptyValues() {
        let empty = english.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }.keys.sorted()
        #expect(empty.isEmpty)
    }

    @Test("Placeholders are filled")
    func placeholders() {
        #expect(L10n.t(.breakEndsAt, ["time": "14:35"]) == "Break ends at 14:35")
        #expect(L10n.t(.menuHeaderWorkingSubtitle, ["remaining": "42 min", "time": "15:00"]) == "42 min left · break at 15:00")
        #expect(L10n.fill("{a} and {b}", ["a": "1"]) == "1 and {b}")
    }

    @Test("A key missing in the active language falls back to English")
    func fallback() {
        let catalog = L10nCatalog(languageCode: "tr", strings: [L10nKey.resumeCopied.rawValue: "Kopyalandı!"], fallback: english)
        #expect(catalog.string(.resumeCopied) == "Kopyalandı!")
        #expect(catalog.string(.resumeActionClose) == "Close")
    }

    @Test("Unknown preferred languages load English")
    func unknownLanguage() {
        let catalog = L10nCatalog.load(bundle: .main, preferredLanguages: ["xx-YY"])
        #expect(catalog.languageCode == "en")
        #expect(catalog.string(.menuItemQuit) == "Quit Pausie")
    }
}
