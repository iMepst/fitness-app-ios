import SwiftUI

/// Rounded square in the muscle group's colour with its symbol.
struct MuscleIcon: View {
    let group: MuscleGroup?
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: group?.symbol ?? "questionmark")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background((group?.tint ?? .gray).gradient, in: .rect(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}
