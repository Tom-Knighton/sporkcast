//
//  EmojiEntrySheet.swift
//  Design
//
//  Created by Tom Knighton on 13/01/2026.
//

import SwiftUI
import UIKit

public struct EmojiEntrySheet: View {
    @Binding var value: String?
    @Binding var isPresented: Bool
    
    public init(value: Binding<String?>, isPresented: Binding<Bool>) {
        self._value = value
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Text("Choose an emoji")
                .font(.headline)
            
            EmojiTextField(
                value: $value,
                isPresented: $isPresented
            )
            .frame(height: 44)
            .padding(.horizontal)
        }
        .padding(.top, 20)
    }
}

private extension UIKeyboardType {
    static let emoji = UIKeyboardType(rawValue: 124)!
}

private struct EmojiTextField: UIViewRepresentable {
    @Binding var value: String?
    @Binding var isPresented: Bool
    
    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.delegate = context.coordinator
        
        tf.keyboardType = .emoji
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.smartQuotesType = .no
        tf.smartDashesType = .no
        tf.smartInsertDeleteType = .no
        
        tf.textAlignment = .center
        tf.font = .systemFont(ofSize: 32)
        
        tf.borderStyle = .roundedRect
        tf.placeholder = "Ingredient Emoji"
        
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        
        DispatchQueue.main.async {
            tf.becomeFirstResponder()
        }
        
        return tf
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != value {
            uiView.text = value
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, isPresented: $isPresented)
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var value: String?
        @Binding var isPresented: Bool
        
        init(value: Binding<String?>, isPresented: Binding<Bool>) {
            _value = value
            _isPresented = isPresented
        }
        
        @objc func editingChanged(_ sender: UITextField) {
            applyFilter(from: sender)
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            true
        }
        
        private func applyFilter(from textField: UITextField) {
            let raw = textField.text ?? ""
            let filtered = raw.firstEmojiOnly() ?? ""
            
            if filtered != value {
                value = filtered
            }
            
            if textField.text != filtered {
                textField.text = filtered
            }
            
            if !filtered.isEmpty {
                DispatchQueue.main.async {
                    self.isPresented = false
                }
            }
        }
    }
}

private extension String {
    func firstEmojiOnly() -> String? {
        // Take the first Character in the string that is an emoji *presentation*.
        for ch in self {
            if ch.isSingleEmojiLike {
                return String(ch)
            }
        }
        return nil
    }
}

private extension Character {
    var isSingleEmojiLike: Bool {
        // “emoji-like” here means:
        // - the grapheme cluster contains at least one emoji scalar
        // - and it’s not just a plain ASCII digit/letter etc.
        // This accepts compound emojis (flags, family, skin-tone, ZWJ sequences).
        unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji }
    }
}
