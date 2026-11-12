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
                    Stepper("Stange: \(Format.weight(barWeight)) kg", value: $barWeight, in: 0...30, step: 2.5)
                    ForEach(AppSettings.standardPlates, id: \.self) { plate in
                        Toggle("\(Format.weight(plate)) kg", isOn: plateBinding(plate))
                    }
                } header: {
                    Text("Scheibenrechner")
                } footer: {
                    Text("Welche Scheiben in deinem Studio liegen. Der Rechner zeigt die Beladung pro Seite.")
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

    private func plateBinding(_ plate: Double) -> Binding<Bool> {
        Binding {
            AppSettings.parsePlates(platesText).contains(plate)
        } set: { isOn in
            var plates = AppSettings.parsePlates(platesText).filter { $0 != plate }
            if isOn { plates.append(plate) }
            platesText = AppSettings.encodePlates(plates)
        }
    }
}

#Preview {
    SettingsView()
}
