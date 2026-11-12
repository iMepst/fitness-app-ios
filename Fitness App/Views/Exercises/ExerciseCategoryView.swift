import SwiftUI
import SwiftData

/// All exercises of one category, grouped by equipment (or, for studio
/// machines, by muscle group).
struct ExerciseCategoryView: View {
    let category: ExerciseCategory

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    @State private var showEditor = false

    private var activeGym: Gym? { gyms.active(id: activeGymID) }

    private struct ExerciseGroup: Identifiable {
        let id: String
        let exercises: [Exercise]
    }

    private var groups: [ExerciseGroup] {
        let items = category.exercises(in: exercises, activeGym: activeGym)
        switch category {
        case .gymMachines:
            return MuscleGroup.allCases.compactMap { group in
                let matching = items.filter { $0.muscleGroup == group }
                return matching.isEmpty ? nil : ExerciseGroup(id: group.rawValue, exercises: matching)
            }
        case .muscle:
            return Equipment.allCases.compactMap { equipment in
                let matching = items.filter { $0.equipment == equipment }
                return matching.isEmpty ? nil : ExerciseGroup(id: equipment.rawValue, exercises: matching)
            }
        }
    }

    var body: some View {
        let groups = groups
        List {
            ForEach(groups) { group in
                Section(group.id) {
                    ForEach(group.exercises) { exercise in
                        NavigationLink(value: exercise) {
                            Text(exercise.name)
                        }
                    }
                }
            }
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView {
                    Label("Keine Übungen", systemImage: category.symbol)
                } description: {
                    Text("In dieser Kategorie gibt es noch keine Übungen.")
                } actions: {
                    Button("Übung hinzufügen") { showEditor = true }
                }
            }
        }
        .navigationTitle(category.title)
        .navigationSubtitle(category == .gymMachines ? activeGym?.name ?? "" : "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Neue Übung", systemImage: "plus") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            switch category {
            case .gymMachines:
                ExerciseEditorView(exercise: nil, defaultGym: activeGym, preferMachine: true)
            case .muscle(let group):
                ExerciseEditorView(exercise: nil, defaultGym: activeGym, defaultMuscleGroup: group)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseCategoryView(category: .muscle(.brust))
    }
    .modelContainer(PreviewData.container)
}
