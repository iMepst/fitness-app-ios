import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    @State private var search = ""
    @State private var muscleFilter: MuscleGroup?
    @State private var showEditor = false

    private var activeGym: Gym? { gyms.active(id: activeGymID) }

    var body: some View {
        NavigationStack {
            let sections = ExerciseSection.make(from: exercises, activeGym: activeGym, search: search, muscleGroup: muscleFilter)
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.exercises) { exercise in
                            NavigationLink(value: exercise) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                    Text("\(exercise.muscleGroup.rawValue) · \(exercise.equipment.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if sections.isEmpty {
                    if search.isEmpty {
                        ContentUnavailableView("Keine Übungen", systemImage: "dumbbell")
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
            .searchable(text: $search, prompt: "Übung suchen")
            .navigationTitle("Übungen")
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GymMenu()
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Muskelgruppe", selection: $muscleFilter) {
                            Text("Alle").tag(MuscleGroup?.none)
                            ForEach(MuscleGroup.allCases) { group in
                                Text(group.rawValue).tag(Optional(group))
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: muscleFilter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Neue Übung", systemImage: "plus") { showEditor = true }
                }
            }
            .sheet(isPresented: $showEditor) {
                ExerciseEditorView(exercise: nil, defaultGym: activeGym)
            }
        }
    }
}

#Preview {
    ExerciseListView()
        .modelContainer(PreviewData.container)
}
