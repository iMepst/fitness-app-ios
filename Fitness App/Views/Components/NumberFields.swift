import SwiftUI

enum NumberFieldStyle {
    /// System rounded border (forms, statistics).
    case bordered
    /// Soft filled rounded rectangle with large digits, matching `PresetChips` (workout logging).
    case filled
}

private struct NumberFieldStyling: ViewModifier {
    let style: NumberFieldStyle

    func body(content: Content) -> some View {
        switch style {
        case .bordered:
            content
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
        case .filled:
            content
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(.fill.tertiary, in: .rect(cornerRadius: 10))
        }
    }
}

/// Text field for kilograms that writes through on every keystroke
/// and accepts both "82,5" and "82.5".
struct DecimalField: View {
    let placeholder: String
    @Binding var value: Double
    var style: NumberFieldStyle = .bordered
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .modifier(NumberFieldStyling(style: style))
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
    var style: NumberFieldStyle = .bordered
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .modifier(NumberFieldStyling(style: style))
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
