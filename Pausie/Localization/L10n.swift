import Foundation
import os

/// Every user-facing string key. Raw values are the flat, dotted keys of `Resources/Localization/<lang>.json`.
enum L10nKey: String, CaseIterable, Sendable {
    case menubarTitleBreak = "menubar.title.break"
    case menubarAccessibilityLabel = "menubar.accessibilityLabel"

    case menuHeaderIdleTitle = "menu.header.idle.title"
    case menuHeaderIdleSubtitle = "menu.header.idle.subtitle"
    case menuHeaderWorkingTitle = "menu.header.working.title"
    case menuHeaderWorkingSubtitle = "menu.header.working.subtitle"
    case menuHeaderNotedTitle = "menu.header.noted.title"
    case menuHeaderNotedSubtitle = "menu.header.noted.subtitle"
    case menuHeaderNoteRequiredTitle = "menu.header.noteRequired.title"
    case menuHeaderNoteRequiredSubtitle = "menu.header.noteRequired.subtitle"
    case menuHeaderBreakTitle = "menu.header.break.title"
    case menuHeaderBreakSubtitle = "menu.header.break.subtitle"
    case menuHeaderBreakOverTitle = "menu.header.breakOver.title"
    case menuHeaderBreakOverSubtitle = "menu.header.breakOver.subtitle"
    case menuItemStart = "menu.item.start"
    case menuItemStop = "menu.item.stop"
    case menuItemTakeBreakNow = "menu.item.takeBreakNow"
    case menuItemEditNote = "menu.item.editNote"
    case menuItemSkipBreak = "menu.item.skipBreak"
    case menuItemRecentNotes = "menu.item.recentNotes"
    case menuItemSettings = "menu.item.settings"
    case menuItemQuit = "menu.item.quit"
    case menuRecentNotesCaption = "menu.recentNotes.caption"
    case menuRecentNotesEmpty = "menu.recentNotes.empty"
    case menuRecentNotesEmptyNote = "menu.recentNotes.emptyNote"

    case noteWindowTitle = "noteWindow.title"
    case noteWindowQuestion = "noteWindow.question"
    case noteWindowCountdown = "noteWindow.countdown"
    case noteWindowPlaceholder = "noteWindow.placeholder"
    case noteWindowHint = "noteWindow.hint"
    case noteWindowActionSaveAndContinue = "noteWindow.action.saveAndContinue"
    case noteWindowActionSaveAndBreak = "noteWindow.action.saveAndBreak"
    case noteWindowActionSave = "noteWindow.action.save"

    case breakNoteRequiredTitle = "breakNoteRequired.title"
    case breakNoteRequiredBody = "breakNoteRequired.body"
    case breakNoteRequiredPlaceholder = "breakNoteRequired.placeholder"
    case breakNoteRequiredAction = "breakNoteRequired.action"

    case breakBubble = "break.bubble"
    case breakEndsAt = "break.endsAt"
    case breakActionLetsGo = "break.action.letsGo"
    case breakActionDisabledHint = "break.action.disabledHint"

    case skipBreakTitle = "skipBreak.title"
    case skipBreakBody = "skipBreak.body"
    case skipBreakActionSkip = "skipBreak.action.skip"
    case skipBreakActionKeepResting = "skipBreak.action.keepResting"

    case breakOverTitle = "breakOver.title"
    case breakOverBody = "breakOver.body"
    case breakOverChime = "breakOver.chime"
    case breakOverNextSession = "breakOver.nextSession"

    case resumeTitle = "resume.title"
    case resumeSubtitle = "resume.subtitle"
    case resumeSavedAt = "resume.savedAt"
    case resumeCopyAccessibilityLabel = "resume.copy.accessibilityLabel"
    case resumeCopied = "resume.copied"
    case resumeEmptyNote = "resume.emptyNote"
    case resumeActionClose = "resume.action.close"

    case settingsWindowTitle = "settings.window.title"
    case settingsHeaderTitle = "settings.header.title"
    case settingsHeaderSubtitle = "settings.header.subtitle"
    case settingsWorkLabel = "settings.work.label"
    case settingsWorkHelp = "settings.work.help"
    case settingsBreakLabel = "settings.break.label"
    case settingsDurationValue = "settings.duration.value"
    case settingsAppearanceLabel = "settings.appearance.label"
    case settingsAppearanceSystem = "settings.appearance.system"
    case settingsAppearanceLight = "settings.appearance.light"
    case settingsAppearanceDark = "settings.appearance.dark"
    case settingsAppearanceHelp = "settings.appearance.help"
    case settingsInfo = "settings.info"
    case settingsActionCancel = "settings.action.cancel"
    case settingsActionSave = "settings.action.save"
}

/// A loaded string table: the active language plus the English fallback.
struct L10nCatalog: Sendable {
    static let fallbackLanguage = "en"

    let languageCode: String
    private let strings: [String: String]
    private let fallback: [String: String]

    init(languageCode: String, strings: [String: String], fallback: [String: String]) {
        self.languageCode = languageCode
        self.strings = strings
        self.fallback = fallback
    }

    /// Loads `<lang>.json` for the first preferred language that has a file, with `en.json` as fallback.
    static func load(bundle: Bundle = .main, preferredLanguages: [String] = Locale.preferredLanguages) -> L10nCatalog {
        let fallback = table(named: fallbackLanguage, in: bundle) ?? [:]
        for identifier in preferredLanguages {
            guard let code = Locale(identifier: identifier).language.languageCode?.identifier else { continue }
            if code == fallbackLanguage { break }
            if let strings = table(named: code, in: bundle) {
                return L10nCatalog(languageCode: code, strings: strings, fallback: fallback)
            }
        }
        return L10nCatalog(languageCode: fallbackLanguage, strings: fallback, fallback: fallback)
    }

    static func table(named language: String, in bundle: Bundle) -> [String: String]? {
        guard let url = bundle.url(forResource: language, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// Raw template for a key, falling back to English. `nil` if the key is missing everywhere.
    func template(for key: L10nKey) -> String? {
        strings[key.rawValue] ?? fallback[key.rawValue]
    }

    func string(_ key: L10nKey, _ arguments: [String: String] = [:]) -> String {
        guard let template = template(for: key) else {
            assertionFailure("Missing localization key: \(key.rawValue)")
            L10n.logger.error("Missing localization key \(key.rawValue, privacy: .public)")
            return key.rawValue
        }
        return L10n.fill(template, arguments)
    }
}

/// Entry point for user-facing text: `L10n.t(.breakEndsAt, ["time": time])`.
enum L10n {
    static let logger = Logger(subsystem: "com.furkanarslan.Pausie", category: "L10n")

    static let catalog = L10nCatalog.load()

    static func t(_ key: L10nKey, _ arguments: [String: String] = [:]) -> String {
        catalog.string(key, arguments)
    }

    /// Replaces `{name}` placeholders with the given values. Unknown placeholders are left as they are.
    static func fill(_ template: String, _ arguments: [String: String]) -> String {
        guard !arguments.isEmpty else { return template }
        var result = template
        for (name, value) in arguments {
            result = result.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return result
    }
}
