import SwiftUI

/// Round −/+ button; holding it repeats the action.
struct RoundStepButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(size >= 44 ? .title3.weight(.semibold) : .body.weight(.semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A large number between two round −/+ buttons.
struct ValueStepper: View {
    enum Style { case large, compact }

    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var style: Style = .large
    var format: (Int) -> String = { "\($0)" }

    var body: some View {
        HStack(spacing: style == .large ? 0 : 10) {
            RoundStepButton(systemImage: "minus", accessibilityLabel: "\(label) verringern", size: buttonSize) {
                change(by: -step)
            }
            .disabled(value <= range.lowerBound)

            if style == .large { Spacer(minLength: 8) }

            Text(format(value))
                .font(style == .large
                      ? .system(size: 40, weight: .bold, design: .rounded)
                      : .system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: style == .large ? 120 : 40)

            if style == .large { Spacer(minLength: 8) }

            RoundStepButton(systemImage: "plus", accessibilityLabel: "\(label) erhöhen", size: buttonSize) {
                change(by: step)
            }
            .disabled(value >= range.upperBound)
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: step)
            case .decrement: change(by: -step)
            @unknown default: break
            }
        }
    }

    private var buttonSize: CGFloat { style == .large ? 48 : 36 }

    private func change(by delta: Int) {
        withAnimation(.snappy) {
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        }
    }
}

#Preview {
    @Previewable @State var sets = 3
    @Previewable @State var reps = 8
    VStack(spacing: 24) {
        ValueStepper(label: "Sätze", value: $sets, range: 1...10)
        ValueStepper(label: "Wdh.", value: $reps, range: 1...50, style: .compact)
    }
    .padding()
}
