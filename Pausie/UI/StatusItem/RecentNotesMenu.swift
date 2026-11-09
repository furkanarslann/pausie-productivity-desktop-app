import AppKit

/// "Recent notes" submenu (screen 02): caption, then the last 5 notes, newest first, with their save time on the right.
@MainActor
enum RecentNotesMenu {
    static func make(notes: [Note], target: AnyObject, action: Selector) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let caption = NSMenuItem(title: L10n.t(.menuRecentNotesCaption), action: nil, keyEquivalent: "")
        caption.attributedTitle = NSAttributedString(string: caption.title, attributes: [
            .font: TypographyToken.caption.nsFont,
            .foregroundColor: NSColor.pausie(.textSecondary),
        ])
        caption.isEnabled = false
        menu.addItem(caption)

        guard !notes.isEmpty else {
            let empty = NSMenuItem(title: L10n.t(.menuRecentNotesEmpty), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return menu
        }

        for note in notes {
            let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
            item.target = target
            item.representedObject = note.id
            item.attributedTitle = title(for: note)
            item.toolTip = note.markdown
            menu.addItem(item)
        }
        return menu
    }

    /// First line of the note, truncated to fit, then a right-aligned tab with the save time.
    private static func title(for note: Note) -> NSAttributedString {
        let font = TypographyToken.menu.nsFont
        let label = truncated(MenuPresentation.recentNoteLabel(note), font: font, maxWidth: Metrics.Menu.recentNotesLabelMaxWidth)
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: Metrics.Menu.recentNotesTimeTab)]
        let text = NSMutableAttributedString(string: label, attributes: [.font: font, .paragraphStyle: paragraph])
        text.append(NSAttributedString(string: "\t" + TimeFormat.clockTime(note.updatedAt), attributes: [
            .font: font,
            .paragraphStyle: paragraph,
        ]))
        return text
    }

    private static func truncated(_ text: String, font: NSFont, maxWidth: CGFloat) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        guard (text as NSString).size(withAttributes: attributes).width > maxWidth else { return text }
        let ellipsis = "…"
        var characters = Array(text)
        while !characters.isEmpty {
            characters.removeLast()
            let candidate = String(characters).trimmingCharacters(in: .whitespaces) + ellipsis
            if (candidate as NSString).size(withAttributes: attributes).width <= maxWidth { return candidate }
        }
        return ellipsis
    }
}
