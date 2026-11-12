import SwiftUI

extension SetKind {
    var tint: Color {
        switch self {
        case .normal: .primary
        case .aufwaermen: .orange
        case .drop: .purple
        case .versagen: .red
        }
    }
}

/// Set number, or W / D / F for special sets, with an optional RPE underneath.
struct SetBadge: View {
    let kind: SetKind
    let number: Int
    var rpe: Double?

    var body: some View {
        VStack(spacing: 0) {
            Text(kind.badge ?? "\(number)")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(kind.tint)
            if let rpe {
                Text("@\(Format.rpe(rpe))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Small coloured capsule "Supersatz A".
struct SupersetTag: View {
    let label: String

    var body: some View {
        Text("Supersatz \(label)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(Self.color(for: label), in: Capsule())
    }

    static func color(for label: String) -> Color {
        let palette: [Color] = [.indigo, .teal, .pink, .orange, .mint, .brown]
        let index = Int(label.unicodeScalars.first?.value ?? 65) - 65
        return palette[((index % palette.count) + palette.count) % palette.count]
    }
}

extension SetEntry {
    /// "Satz 2", "Aufwärmsatz", … plus "· RPE 8" when set.
    func historyLabel(number: Int) -> String {
        var text = kind == .normal ? "Satz \(number)" : kind.label
        if let rpe { text += " · RPE \(Format.rpe(rpe))" }
        return text
    }
}
