//
//  PasteableTextField.swift
//  Gameshelf
//
//  Created by Antigravity on 2026-10-25.
//

import SwiftUI
import UIKit

/// En UITextField-wrapper som avaktiverar iOS 17/18:s irriterande "AutoFill"-meny
/// och garanterar att "Klistra in" (Paste) visas direkt vid tryck och långtryck.
struct PasteableTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var onCommit: (() -> Void)? = nil

    class CustomUITextField: UITextField {
        override func buildMenu(with builder: UIMenuBuilder) {
            if #available(iOS 17.0, *) {
                // Tar bort AutoFill så att Klistra in (Paste) visas direkt i menyn
                builder.remove(menu: .autoFill)
            }
            super.buildMenu(with: builder)
        }

        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            if action == #selector(paste(_:)) {
                return UIPasteboard.general.hasStrings
            }
            if action == #selector(copy(_:)) || action == #selector(cut(_:)) || action == #selector(selectAll(_:)) {
                return super.canPerformAction(action, withSender: sender)
            }
            return super.canPerformAction(action, withSender: sender)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CustomUITextField {
        let tf = CustomUITextField()
        tf.placeholder = placeholder
        tf.isSecureTextEntry = isSecure
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.spellCheckingType = .no
        tf.textContentType = nil
        tf.keyboardType = .asciiCapable
        tf.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        tf.textColor = .label
        tf.clearButtonMode = .whileEditing
        tf.returnKeyType = .done
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateUIView(_ uiView: CustomUITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PasteableTextField

        init(_ parent: PasteableTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onCommit?()
            return true
        }
    }
}
