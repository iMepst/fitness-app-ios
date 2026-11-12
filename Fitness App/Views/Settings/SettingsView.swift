import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage(AppSettings.barWeightKey) private var barWeight = AppSettings.defaultBarWeight
    @AppStorage(AppSettings.platesKey) private var platesText = AppSettings.defaultPlates
    @AppStorage(AppSettings.weeklyGoalKey) private var weeklyGoal = AppSettings.defaultWeeklyGoal
    @AppStorage(AppSettings.healthSyncKey) private var healthSync = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var healthMessage: String?
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if HealthKitService.shared.isAvailable {
                        Toggle("Mit Apple Health verbinden", isOn: $healthSync)
                        if healthSync {
                            Button {
                                Task { await exportPastWorkouts() }
                            } label: {
                                HStack {
                                    Text("Bisherige Trainings übertragen")
                                    if isExporting {
                                        Spacer()
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isExporting)
                        }
                        if let healthMessage {
                            Text(healthMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Apple Health ist auf diesem Gerät nicht verfügbar.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Beendete Trainings werden als Krafttraining gespeichert. Dein Körpergewicht wird in beide Richtungen abgeglichen.")
                }

                Section {
                    Stepper("Wochenziel: \(Format.count(weeklyGoal, "Training", "Trainings"))", value: $weeklyGoal, in: 1...7)
                } header: {
                    Text("Wochenziel")
                } footer: {
                    Text("Wird in der Statistik für deine Serie verwendet.")
                }

                Section {
                    Stepper(value: $barWeight, in: 0...30, step: 2.5) {
                        LabeledContent("Stange") {
                            Text("\(Format.weight(barWeight)) kg")
                                .monospacedDigit()
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Verfügbare Scheiben")
                            Spacer()
                            Text("\(selectedPlates.count) von \(AppSettings.standardPlates.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        PlatePickerGrid(selection: plateSelection)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Scheibenrechner")
                } footer: {
                    Text("Tippe auf die Scheiben, die in deinem Studio liegen (in kg). Der Rechner zeigt die Beladung pro Seite.")
                }
            }
            .onChange(of: healthSync) { _, isOn in
                guard isOn else { return }
                Task {
                    do {
                        try await HealthKitService.shared.requestAuthorization()
                        healthMessage = nil
                    } catch {
                        healthMessage = error.localizedDescription
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func exportPastWorkouts() async {
        isExporting = true
        let count = await HealthSync.exportPending(in: modelContext)
        isExporting = false
        healthMessage = count == 0
            ? "Alle Trainings sind bereits in Apple Health."
            : "\(Format.count(count, "Training", "Trainings")) übertragen."
    }

    private var selectedPlates: Set<Double> {
        Set(AppSettings.parsePlates(platesText))
    }

    private var plateSelection: Binding<Set<Double>> {
        Binding {
            selectedPlates
        } set: { plates in
            platesText = AppSettings.encodePlates(Array(plates))
        }
    }
}

/// Compact grid of plate tokens; tapping one toggles whether it is available.
private struct PlatePickerGrid: View {
    @Binding var selection: Set<Double>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(AppSettings.standardPlates, id: \.self) { plate in
                token(plate)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func token(_ plate: Double) -> some View {
        let isOn = selection.contains(plate)
        return Button {
            if isOn { selection.remove(plate) } else { selection.insert(plate) }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(isOn ? plateColor(plate) : .clear)
                    .overlay(
                        Circle().strokeBorder(
                            isOn ? AnyShapeStyle(.black.opacity(0.15)) : AnyShapeStyle(.tertiary),
                            style: StrokeStyle(lineWidth: 1.5, dash: isOn ? [] : [3, 3])
                        )
                    )
                    .frame(width: 22, height: 22)
                Text(Format.weight(plate))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.fill.quaternary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isOn ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isOn)
        .accessibilityLabel("\(Format.weight(plate)) kg")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    SettingsView()
}
