import AppKit
import SwiftUI

/// One editable todo line. An `NSTextField` wrapper because AppKit's field editor consumes Backspace,
/// Return and the arrow keys before SwiftUI's `onKeyPress` sees them; the delegate's
/// `control(_:textView:doCommandBy:)` gets them reliably.
///
/// Long todos wrap and the row grows (Figma `Todo row`), so the whole text and the caret stay visible.
/// ↑ / ↓ move between the wrapped lines of a todo first, and to the neighbouring todo from its first / last line.
struct TodoTextField: NSViewRepresentable {
    enum Command {
        case newline
        case deleteBackwardWhenEmpty
        case deleteForwardWhenEmpty
        case moveUp
        case moveDown
    }

    @Binding var text: String
    /// Shown while empty (Figma shows it only on the last row).
    let placeholder: String?
    let accessibilityLabel: String
    /// Non-nil when this row should take keyboard focus, with the caret at the start or end.
    let focusCaret: TodoEditorModel.Caret?
    /// Returns `true` if the command was handled; otherwise the field editor does its default.
    let onCommand: (Command) -> Bool
    let onFocusApplied: () -> Void
    /// The field started (`true`) or stopped editing; drives the editor's focused style.
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusReportingTextField()
        let coordinator = context.coordinator
        field.onBecomeFirstResponder = { [weak coordinator] in coordinator?.reportFocus(true) }
        field.onMoveToWindow = { [weak coordinator, weak field] in
            guard let field else { return }
            coordinator?.applyPendingFocus(to: field)
        }
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = TypographyToken.body.nsFont
        field.textColor = .pausie(.textPrimary)
        field.usesSingleLineMode = false
        field.maximumNumberOfLines = 0
        field.lineBreakMode = .byWordWrapping
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        // Only touch the field when something changed: resetting properties of the field being edited
        // can disturb the field editor.
        let current = field.currentEditor()?.string ?? field.stringValue
        if current != text {
            field.stringValue = text
        }
        if coordinator.appliedPlaceholder != placeholder {
            coordinator.appliedPlaceholder = placeholder
            field.placeholderAttributedString = placeholder.map {
                NSAttributedString(string: $0, attributes: [
                    .font: TypographyToken.body.nsFont,
                    .foregroundColor: NSColor.pausie(.textSecondary),
                ])
            }
        }
        if coordinator.appliedAccessibilityLabel != accessibilityLabel {
            coordinator.appliedAccessibilityLabel = accessibilityLabel
            field.setAccessibilityLabel(accessibilityLabel)
        }
        if let focusCaret {
            coordinator.requestFocus(of: field, caret: focusCaret)
        }
    }

    /// Height for the text wrapped at the proposed width.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: NSTextField, context: Context) -> CGSize? {
        let width = proposal.width ?? field.bounds.width
        guard width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: Self.height(for: text, width: width))
    }

    @MainActor
    static func height(for text: String, width: CGFloat) -> CGFloat {
        let cell = NSTextFieldCell(textCell: text.isEmpty ? " " : text)
        cell.font = TypographyToken.body.nsFont
        cell.wraps = true
        cell.lineBreakMode = .byWordWrapping
        cell.isBordered = false
        cell.isBezeled = false
        let size = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))
        return max(TypographyToken.body.spec.lineHeight, size.height.rounded(.up))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TodoTextField
        var appliedPlaceholder: String??
        var appliedAccessibilityLabel: String?
        /// Focus asked for before the field was in a window; applied when it gets one.
        private var pendingCaret: TodoEditorModel.Caret?
        private var isScheduled = false

        init(_ parent: TodoTextField) {
            self.parent = parent
        }

        func requestFocus(of field: NSTextField, caret: TodoEditorModel.Caret) {
            pendingCaret = caret
            guard !isScheduled else { return }
            isScheduled = true
            // Next run loop turn: a newly inserted row isn't in the window yet. If it still isn't,
            // `viewDidMoveToWindow` applies the request.
            Task { @MainActor [weak self, weak field] in
                guard let self else { return }
                self.isScheduled = false
                if let field { self.applyPendingFocus(to: field) }
            }
        }

        func applyPendingFocus(to field: NSTextField) {
            guard let caret = pendingCaret, let window = field.window else { return }
            pendingCaret = nil
            if field.currentEditor() == nil {
                window.makeFirstResponder(field)
            }
            // makeFirstResponder selects everything; put the caret where the edit continues, and make sure
            // it is in view.
            if let editor = field.currentEditor() as? NSTextView {
                let length = (editor.string as NSString).length
                let range = NSRange(location: caret == .start ? 0 : length, length: 0)
                editor.selectedRange = range
                editor.scrollRangeToVisible(range)
            }
            parent.onFocusApplied()
        }

        /// Deferred so a focus change during a SwiftUI update (e.g. a row being removed) doesn't mutate state mid-update.
        func reportFocus(_ focused: Bool) {
            Task { @MainActor [weak self] in self?.parent.onFocusChange(focused) }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            reportFocus(false)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.currentEditor()?.string ?? field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                return parent.onCommand(.newline)
            case #selector(NSResponder.deleteBackward(_:)) where textView.string.isEmpty:
                return parent.onCommand(.deleteBackwardWhenEmpty)
            case #selector(NSResponder.deleteForward(_:)) where textView.string.isEmpty:
                return parent.onCommand(.deleteForwardWhenEmpty)
            case #selector(NSResponder.moveUp(_:)) where CaretLine.isOnFirstLine(textView):
                return parent.onCommand(.moveUp)
            case #selector(NSResponder.moveDown(_:)) where CaretLine.isOnLastLine(textView):
                return parent.onCommand(.moveDown)
            default:
                return false
            }
        }
    }
}

/// Which wrapped line of a field editor the caret is on.
@MainActor
enum CaretLine {
    static func isOnFirstLine(_ textView: NSTextView) -> Bool {
        guard let lines = lineTops(textView) else { return true }
        return abs(lines.caret - lines.first) < 1
    }

    static func isOnLastLine(_ textView: NSTextView) -> Bool {
        guard let lines = lineTops(textView) else { return true }
        return abs(lines.caret - lines.last) < 1
    }

    /// Top of the first line, the last line and the caret's line.
    private static func lineTops(_ textView: NSTextView) -> (first: CGFloat, last: CGFloat, caret: CGFloat)? {
        guard let layout = textView.layoutManager, let container = textView.textContainer else { return nil }
        layout.ensureLayout(for: container)
        let glyphCount = layout.numberOfGlyphs
        guard glyphCount > 0 else { return nil }
        let length = (textView.string as NSString).length
        let location = min(textView.selectedRange.location, length)
        // The caret belongs to the line of the character after it; at the very end, to the last character's line.
        let character = location < length ? location : max(0, length - 1)
        let caretGlyph = min(layout.glyphIndexForCharacter(at: character), glyphCount - 1)
        return (
            layout.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).minY,
            layout.lineFragmentRect(forGlyphAt: glyphCount - 1, effectiveRange: nil).minY,
            layout.lineFragmentRect(forGlyphAt: caretGlyph, effectiveRange: nil).minY
        )
    }
}

/// Reports when the field takes keyboard focus (the end is reported by the delegate) and when it
/// lands in a window, so a focus request made before that can be applied.
private final class FocusReportingTextField: NSTextField {
    var onBecomeFirstResponder: (() -> Void)?
    var onMoveToWindow: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onBecomeFirstResponder?() }
        return accepted
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { onMoveToWindow?() }
    }
}
