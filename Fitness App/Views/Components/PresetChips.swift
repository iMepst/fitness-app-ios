import SwiftUI

/// A row of equally wide quick-pick capsules; the one matching `selection` is highlighted.
struct PresetChips<Value: Equatable>: View {
    let options: [(label: String, value: Value)]
    let selection: Value
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy) { onSelect(option.value) }
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                        .background(
                            isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary),
                            in: Capsule()
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
