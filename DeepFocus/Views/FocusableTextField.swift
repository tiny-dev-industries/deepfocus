import AppKit
import SwiftUI

/// A text field that can receive keyboard focus inside a nonactivating NSPanel.
/// SwiftUI's @FocusState requires the window to already be key, which never happens
/// for .nonactivatingPanel. This wrapper calls window.makeFirstResponder() directly
/// from updateNSView so typing always works.
struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var isFocused: Bool
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.isBordered = false
        tf.focusRingType = .none
        tf.font = .systemFont(ofSize: 12, weight: .medium)
        tf.textColor = NSColor.white
        tf.alignment = .center

        // Set placeholder with white color
        let placeholderAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.5),
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ]
        tf.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: placeholderAttributes
        )

        tf.delegate = context.coordinator
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.submit(_:))
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        // Only set stringValue when the field editor is NOT active.
        // Setting stringValue while editing can reset/restart the field editor,
        // causing each typed character to overwrite the previous one.
        if tf.currentEditor() == nil, tf.stringValue != text {
            tf.stringValue = text
        }
        context.coordinator.parent = self
        if isFocused {
            // Defer to the next run-loop iteration so that NSHostingView has finished
            // inserting the NSTextField into the window hierarchy (tf.window is nil during
            // the synchronous updateNSView call for a newly-created view).
            DispatchQueue.main.async { [weak tf] in
                guard let tf, let win = tf.window else { return }
                // Skip if the field is already being edited. updateNSView is called
                // on every SwiftUI render — including renders triggered by
                // controlTextDidChange updates during typing. Calling makeFirstResponder
                // while the field editor is active restarts it and re-selects all text,
                // causing each typed character to replace the previous one. Guard with
                // currentEditor() to only run the focus acquisition once, on first render.
                guard tf.currentEditor() == nil else { return }
                if !NSApp.isActive {
                    NSApp.activate(ignoringOtherApps: true)
                }
                win.makeKeyAndOrderFront(nil)
                win.makeFirstResponder(tf)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleNSView(_ tf: NSTextField, coordinator: Coordinator) {
        // When the view is removed (e.g., checkmark button clicked without pressing
        // Return), the field editor may still hold in-progress text that hasn't been
        // committed to tf.stringValue yet. Flush it to the binding now so the model
        // reflects the final typed value.
        if let editor = tf.currentEditor() as? NSTextView {
            coordinator.parent.text = editor.string
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField

        init(parent: FocusableTextField) {
            self.parent = parent
        }

        @objc func submit(_ sender: Any) {
            parent.onSubmit()
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            // Read from the field editor directly. NSTextField.stringValue is
            // only committed from the field editor when editing ends; reading it
            // mid-edit can return the original (pre-edit) value.
            let current = (tf.currentEditor() as? NSTextView)?.string ?? tf.stringValue
            parent.text = current
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}
