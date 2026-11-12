import SwiftUI

/// Text field for kilograms that writes through on every keystroke
/// and accepts both "82,5" and "82.5".
struct DecimalField: View {
    let placeholder: String
    @Binding var value: Double
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .monospacedDigit()
            .onAppear { text = value == 0 ? "" : Format.weight(value) }
            .onChange(of: text) { _, newValue in
                let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                if normalized.isEmpty {
                    value = 0
                } else if let parsed = Double(normalized) {
                    value = parsed
                }
            }
            .onChange(of: value) { _, newValue in
                // Value changed from outside (e.g. "apply suggestion") – refresh the text.
                let current = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
                if current != newValue {
                    text = newValue == 0 ? "" : Format.weight(newValue)
                }
            }
    }
}

struct IntegerField: View {
    let placeholder: String
    @Binding var value: Int
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .monospacedDigit()
            .onAppear { text = value == 0 ? "" : "\(value)" }
            .onChange(of: text) { _, newValue in
                if newValue.isEmpty {
                    value = 0
                } else if let parsed = Int(newValue) {
                    value = parsed
                }
            }
            .onChange(of: value) { _, newValue in
                if (Int(text) ?? 0) != newValue {
                    text = newValue == 0 ? "" : "\(newValue)"
                }
            }
    }
}
