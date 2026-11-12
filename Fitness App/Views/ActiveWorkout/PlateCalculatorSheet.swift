import SwiftUI

struct PlateCalculatorSheet: View {
    let exerciseName: String
    @State var target: Double

    @AppStorage(AppSettings.barWeightKey) private var barWeight = AppSettings.defaultBarWeight
    @AppStorage(AppSettings.platesKey) private var platesText = AppSettings.defaultPlates
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Zielgewicht")
                        Spacer()
                        DecimalField(placeholder: "kg", value: $target)
                            .frame(width: 100)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    Stepper("Stange: \(Format.weight(barWeight)) kg", value: $barWeight, in: 0...30, step: 2.5)
                }

                Section("Pro Seite") {
                    if target <= 0 {
                        Text("Gib ein Zielgewicht ein.")
                            .foregroundStyle(.secondary)
                    } else if let loading = PlateCalculator.loading(target: target, bar: barWeight, plates: plates) {
                        if loading.perSide.isEmpty {
                            Text("Nur die Stange – keine Scheiben nötig.")
                                .foregroundStyle(.secondary)
                        } else {
                            PlateStack(plates: loading.perSide)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            Text(grouped(loading.perSide))
                                .font(.headline)
                        }
                        if loading.remainderPerSide > 0 {
                            Label(
                                "Nicht exakt ladbar: \(Format.weight(loading.achieved)) kg (je Seite fehlen \(Format.weight(loading.remainderPerSide)) kg)",
                                systemImage: "exclamationmark.triangle"
                            )
                            .foregroundStyle(.orange)
                        }
                    } else {
                        Text("Das Zielgewicht ist leichter als die Stange.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var plates: [Double] { AppSettings.parsePlates(platesText) }

    /// "2 × 20 kg + 1 × 2,5 kg"
    private func grouped(_ plates: [Double]) -> String {
        var counts: [(Double, Int)] = []
        for plate in plates {
            if let last = counts.last, last.0 == plate {
                counts[counts.count - 1].1 += 1
            } else {
                counts.append((plate, 1))
            }
        }
        return counts.map { "\($0.1) × \(Format.weight($0.0)) kg" }.joined(separator: " + ")
    }
}

/// Side view of one bar end: heavier plates are taller.
private struct PlateStack: View {
    let plates: [Double]

    var body: some View {
        HStack(spacing: 3) {
            Rectangle()
                .fill(.gray.opacity(0.5))
                .frame(width: 30, height: 10)
            ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color(for: plate))
                    .frame(width: plate >= 10 ? 14 : 10, height: height(for: plate))
                    .overlay {
                        Text(Format.weight(plate))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(-90))
                            .fixedSize()
                    }
            }
            Rectangle()
                .fill(.gray.opacity(0.5))
                .frame(width: 20, height: 10)
        }
        .frame(height: 110)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plates.map { "\(Format.weight($0)) kg" }.joined(separator: ", "))
    }

    private func height(for plate: Double) -> CGFloat {
        switch plate {
        case 20...: 110
        case 15..<20: 95
        case 10..<15: 80
        case 5..<10: 60
        case 2.5..<5: 45
        default: 35
        }
    }

    private func color(for plate: Double) -> Color {
        switch plate {
        case 25...: .red
        case 20..<25: .blue
        case 15..<20: .yellow
        case 10..<15: .green
        default: .gray
        }
    }
}

#Preview {
    PlateCalculatorSheet(exerciseName: "Kniebeuge", target: 102.5)
}
