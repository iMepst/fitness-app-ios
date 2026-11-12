import SwiftUI
import SwiftData

/// Übungen overview: a grid of categories; searching shows a flat result list.
struct ExerciseListView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    @State private var search = ""
    @State private var showEditor = false

    private var activeGym: Gym? { gyms.active(id: activeGymID) }

    var body: some View {
        NavigationStack {
            Group {
                if search.isEmpty {
                    CategoryGrid(exercises: exercises, activeGym: activeGym)
                } else {
                    SearchResults(exercises: exercises, activeGym: activeGym, search: search)
                }
            }
            .searchable(text: $search, prompt: "Übung suchen")
            .navigationTitle("Übungen")
            .navigationDestination(for: ExerciseCategory.self) { category in
                ExerciseCategoryView(category: category)
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GymMenu()
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

private struct CategoryGrid: View {
    let exercises: [Exercise]
    let activeGym: Gym?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        let machines = ExerciseCategory.gymMachines.exercises(in: exercises, activeGym: activeGym)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let gym = activeGym, !machines.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("Dein Studio")
                        NavigationLink(value: ExerciseCategory.gymMachines) {
                            ExerciseCategoryTile(category: .gymMachines, count: machines.count, subtitle: gym.name)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle("Muskelgruppen")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(MuscleGroup.allCases) { group in
                            let category = ExerciseCategory.muscle(group)
                            NavigationLink(value: category) {
                                ExerciseCategoryTile(
                                    category: category,
                                    count: category.exercises(in: exercises, activeGym: activeGym).count
                                )
                            }
                        }
                    }
                }
            }
            .buttonStyle(TileButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title3.bold())
            .accessibilityAddTraits(.isHeader)
    }
}

/// Subtle press feedback instead of the default highlight.
private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

private struct SearchResults: View {
    let exercises: [Exercise]
    let activeGym: Gym?
    let search: String

    var body: some View {
        let sections = ExerciseSection.make(from: exercises, activeGym: activeGym, search: search)
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.exercises) { exercise in
                        NavigationLink(value: exercise) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                    Text(exercise.equipment.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: exercise.muscleGroup.symbol)
                                    .foregroundStyle(exercise.muscleGroup.tint)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }
}

#Preview {
    ExerciseListView()
        .modelContainer(PreviewData.container)
}
