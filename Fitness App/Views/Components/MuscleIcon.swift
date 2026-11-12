import SwiftUI

/// Rounded square in the muscle group's colour with its symbol.
/// Also used with a custom symbol/colour (e.g. "Freies Training").
struct MuscleIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 40

    init(group: MuscleGroup?, size: CGFloat = 40) {
        self.symbol = group?.symbol ?? "questionmark"
        self.tint = group?.tint ?? .gray
        self.size = size
    }

    init(symbol: String, tint: Color, size: CGFloat = 40) {
        self.symbol = symbol
        self.tint = tint
        self.size = size
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}
