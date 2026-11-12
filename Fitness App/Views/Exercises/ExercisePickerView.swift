import SwiftUI
import SwiftData

/// Multi-select exercise picker (universal exercises + machines of the given gym).
struct ExercisePickerView: View {
    let activeGym: Gym?
    let onSelect: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var selection: [PersistentIdentifier] = []
    @State private var search = ""
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(activeGym.map { "Neues Gerät in \($0.name)" } ?? "Neue Übung", systemImage: "plus") {
                        showEditor = true
                    }
                }
                ForEach(ExerciseSection.make(from: exercises, activeGym: activeGym, search: search)) { section in
                    Section(section.title) {
                        ForEach(section.exercises) { exercise in
                            Button {
                                toggle(exercise)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                        Text(exercise.equipment.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let position = selection.firstIndex(of: exercise.persistentModelID) {
                                        Text("\(position + 1)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .frame(width: 24, height: 24)
                                            // Not `.tint`: the row sets `.tint(.primary)`, which made the badge white on white in dark mode.
                                            .background(Color.accentColor, in: Circle())
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Übung suchen")
            .navigationTitle("Übungen wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selection.isEmpty ? "Hinzufügen" : "Hinzufügen (\(selection.count))") {
                        let byID = Dictionary(exercises.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { a, _ in a })
                        onSelect(selection.compactMap { byID[$0] })
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .sheet(isPresented: $showEditor) {
                ExerciseEditorView(exercise: nil, defaultGym: activeGym, preferMachine: activeGym != nil)
            }
        }
    }

    private func toggle(_ exercise: Exercise) {
        let id = exercise.persistentModelID
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
    }
}
