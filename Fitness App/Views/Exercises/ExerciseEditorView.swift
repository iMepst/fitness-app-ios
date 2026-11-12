import SwiftUI
import SwiftData

/// Create or edit an exercise. Machines can be bound to a gym.
struct ExerciseEditorView: View {
    let exercise: Exercise?
    let defaultGym: Gym?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @State private var name: String
    @State private var muscleGroup: MuscleGroup
    @State private var equipment: Equipment
    @State private var notes: String
    @State private var gymOnly: Bool

    init(exercise: Exercise?, defaultGym: Gym?, preferMachine: Bool = false) {
        self.exercise = exercise
        self.defaultGym = defaultGym
        _name = State(initialValue: exercise?.name ?? "")
        _muscleGroup = State(initialValue: exercise?.muscleGroup ?? .brust)
        _equipment = State(initialValue: exercise?.equipment ?? (preferMachine ? .maschine : .kurzhantel))
        _notes = State(initialValue: exercise?.notes ?? "")
        _gymOnly = State(initialValue: exercise.map { $0.gym != nil } ?? preferMachine)
    }

    private var targetGym: Gym? {
        exercise?.gym ?? defaultGym ?? gyms.active(id: activeGymID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Brustpresse", text: $name)
                    Picker("Muskelgruppe", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: equipment) { _, newValue in
                        if exercise == nil, targetGym != nil { gymOnly = newValue == .maschine }
                    }
                }

                if let gym = targetGym {
                    Section {
                        Toggle("Nur in \(gym.name)", isOn: $gymOnly)
                    } footer: {
                        Text("Geräte sind studiospezifisch: Gewichte an Maschinen sind zwischen Studios nicht vergleichbar. Freie Gewichte gelten überall.")
                    }
                }

                Section("Notizen") {
                    TextField("z. B. Sitzhöhe 4, Lehne Stufe 2", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(exercise == nil ? "Neue Übung" : "Übung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let target = exercise ?? {
            let new = Exercise(name: trimmed, muscleGroup: muscleGroup, equipment: equipment)
            modelContext.insert(new)
            return new
        }()
        target.name = trimmed
        target.muscleGroup = muscleGroup
        target.equipment = equipment
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.gym = gymOnly ? targetGym : nil
        try? modelContext.save()
        dismiss()
    }
}
