import AppKit
import SwiftUI

/// One editable todo line. An `NSTextField` wrapper because AppKit's field editor consumes Backspace,
/// Return and the arrow keys before SwiftUI's `onKeyPress` sees them; the delegate's
/// `control(_:textView:doCommandBy:)` gets them reliably.
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = TypographyToken.body.nsFont
        field.textColor = .pausie(.textPrimary)
        field.lineBreakMode = .byClipping
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderAttributedString = placeholder.map {
            NSAttributedString(string: $0, attributes: [
                .font: TypographyToken.body.nsFont,
                .foregroundColor: NSColor.pausie(.textSecondary),
            ])
        }
        field.setAccessibilityLabel(accessibilityLabel)
        if let focusCaret {
            context.coordinator.applyFocus(to: field, caret: focusCaret)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TodoTextField
        private var isApplyingFocus = false

        init(_ parent: TodoTextField) {
            self.parent = parent
        }

        /// Focuses on the next run loop turn: a newly inserted row isn't in the window yet.
        func applyFocus(to field: NSTextField, caret: TodoEditorModel.Caret, attempt: Int = 0) {
            guard !isApplyingFocus || attempt > 0 else { return }
            isApplyingFocus = true
            Task { @MainActor [weak self, weak field] in
                guard let self, let field else { return }
                guard let window = field.window else {
                    if attempt < 3 {
                        self.applyFocus(to: field, caret: caret, attempt: attempt + 1)
                    } else {
                        self.isApplyingFocus = false
                    }
                    return
                }
                self.isApplyingFocus = false
                if field.currentEditor() == nil {
                    window.makeFirstResponder(field)
                }
                // makeFirstResponder selects everything; put the caret where the edit continues instead.
                let length = (field.stringValue as NSString).length
                field.currentEditor()?.selectedRange = NSRange(location: caret == .start ? 0 : length, length: 0)
                self.parent.onFocusApplied()
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                return parent.onCommand(.newline)
            case #selector(NSResponder.deleteBackward(_:)) where textView.string.isEmpty:
                return parent.onCommand(.deleteBackwardWhenEmpty)
            case #selector(NSResponder.deleteForward(_:)) where textView.string.isEmpty:
                return parent.onCommand(.deleteForwardWhenEmpty)
            case #selector(NSResponder.moveUp(_:)):
                return parent.onCommand(.moveUp)
            case #selector(NSResponder.moveDown(_:)):
                return parent.onCommand(.moveDown)
            default:
                return false
            }
        }
    }
}
