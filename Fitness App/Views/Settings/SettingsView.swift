import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.barWeightKey) private var barWeight = AppSettings.defaultBarWeight
    @AppStorage(AppSettings.platesKey) private var platesText = AppSettings.defaultPlates
    @AppStorage(AppSettings.weeklyGoalKey) private var weeklyGoal = AppSettings.defaultWeeklyGoal

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
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
