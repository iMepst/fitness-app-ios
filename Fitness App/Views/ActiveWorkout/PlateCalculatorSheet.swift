import SwiftUI

struct PlateCalculatorSheet: View {
    let exerciseName: String
    @State var target: Double

    @AppStorage(AppSettings.barWeightKey) private var barWeight = AppSettings.defaultBarWeight
    @AppStorage(AppSettings.platesKey) private var platesText = AppSettings.defaultPlates
    @Environment(\.dismiss) private var dismiss

    private static let bars: [Double] = [20, 15, 10]

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                targetControl
                result
                Spacer(minLength: 0)
                barPicker
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom)
            .animation(.snappy, value: target)
            .animation(.snappy, value: barWeight)
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .onAppear {
            if target < barWeight { target = barWeight }
        }
    }

    // MARK: - Parts

    private var targetControl: some View {
        HStack(spacing: 24) {
            stepButton(systemImage: "minus", up: false)
                .disabled(target <= barWeight)
            Text("\(Format.weight(target)) kg")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: target))
                .frame(minWidth: 170)
            stepButton(systemImage: "plus", up: true)
        }
    }

    /// Jumps to the next weight that can be loaded exactly.
    private func stepButton(systemImage: String, up: Bool) -> some View {
        RoundStepButton(systemImage: systemImage, accessibilityLabel: up ? "Nächstes Gewicht" : "Vorheriges Gewicht") {
            target = PlateCalculator.step(from: target, bar: barWeight, plates: plates, up: up)
        }
    }

    @ViewBuilder
    private var result: some View {
        if let loading = PlateCalculator.loading(target: target, bar: barWeight, plates: plates) {
            VStack(spacing: 20) {
                BarbellView(plates: loading.perSide)

                if loading.perSide.isEmpty {
                    Text("Nur die Stange")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        Text("Pro Seite, in kg")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        PlateChips(plates: loading.perSide)
                    }
                }

                if let nearest = PlateCalculator.nearest(target: target, bar: barWeight, plates: plates) {
                    VStack(spacing: 8) {
                        Label("Nicht genau ladbar", systemImage: "exclamationmark.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        HStack(spacing: 12) {
                            alternativeButton(nearest.lower)
                            if let upper = nearest.upper {
                                alternativeButton(upper)
                            }
                        }
                    }
                }
            }
        }
    }

    private func alternativeButton(_ weight: Double) -> some View {
        Button("\(Format.weight(weight)) kg") { target = weight }
            .buttonStyle(.bordered)
            .tint(.orange)
            .monospacedDigit()
    }

    private var barPicker: some View {
        HStack(spacing: 12) {
            Text("Stange")
                .foregroundStyle(.secondary)
            Picker("Stange", selection: $barWeight) {
                ForEach(barOptions, id: \.self) { weight in
                    Text("\(Format.weight(weight)) kg").tag(weight)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var barOptions: [Double] {
        Self.bars.contains(barWeight) ? Self.bars : (Self.bars + [barWeight]).sorted(by: >)
    }

    private var plates: [Double] { AppSettings.parsePlates(platesText) }
}

// MARK: - Drawing

/// Front view of a loaded barbell, both sides mirrored.
private struct BarbellView: View {
    let plates: [Double]

    var body: some View {
        HStack(spacing: 0) {
            sleeve(plates.reversed(), isLeft: true)
            Capsule()
                .fill(.gray.opacity(0.45))
                .frame(height: 8)
                .frame(minWidth: 40)
            sleeve(plates, isLeft: false)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plates.isEmpty ? "Leere Stange" : "Pro Seite: " + plates.map { "\(Format.weight($0)) kg" }.joined(separator: ", "))
    }

    /// Plates from left to right; the collar sits on the inner side (towards the bar).
    private func sleeve(_ ordered: [Double], isLeft: Bool) -> some View {
        HStack(spacing: 2) {
            if !isLeft { collar }
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, plate in
                RoundedRectangle(cornerRadius: 3)
                    .fill(plateColor(plate))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.15)))
                    .frame(width: thickness(plate), height: height(plate))
            }
            if isLeft { collar }
        }
        .padding(.horizontal, 2)
        .background(alignment: .center) {
            Capsule().fill(.gray.opacity(0.3)).frame(height: 12)
        }
        .frame(minWidth: 24)
    }

    private var collar: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.gray.opacity(0.7))
            .frame(width: 6, height: 26)
    }

    private func thickness(_ plate: Double) -> CGFloat {
        switch plate {
        case 10...: 14
        case 2.5..<10: 9
        default: 6
        }
    }

    private func height(_ plate: Double) -> CGFloat {
        switch plate {
        case 15...: 120
        case 10..<15: 100
        case 5..<10: 70
        case 2.5..<5: 52
        default: 40
        }
    }
}

/// "2 × 25 kg" chips with the plate colour as a dot.
private struct PlateChips: View {
    let plates: [Double]

    private var groups: [(plate: Double, count: Int)] {
        var result: [(Double, Int)] = []
        for plate in plates {
            if let last = result.last, last.0 == plate {
                result[result.count - 1].1 += 1
            } else {
                result.append((plate, 1))
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(groups, id: \.plate) { group in
                HStack(spacing: 6) {
                    Circle()
                        .fill(plateColor(group.plate))
                        .overlay(Circle().strokeBorder(.black.opacity(0.15)))
                        .frame(width: 12, height: 12)
                    Text(group.count > 1 ? "\(group.count) × \(Format.weight(group.plate))" : Format.weight(group.plate))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary, in: Capsule())
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        PlateCalculatorSheet(exerciseName: "Kniebeuge", target: 101)
            .presentationDetents([.fraction(0.65), .large])
    }
}
