import SwiftUI
import SwiftData

struct GymListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    @State private var showAddAlert = false
    @State private var newName = ""
    @State private var gymToDelete: Gym?

    var body: some View {
        List {
            Section {
                ForEach(gyms) { gym in
                    NavigationLink {
                        GymDetailView(gym: gym)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gym.name)
                                Text(Format.count(gym.exercises.count, "Gerät", "Geräte"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isActive(gym) {
                                Text("Aktiv")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Löschen", systemImage: "trash") { gymToDelete = gym }
                            .tint(.red)
                        if !isActive(gym) {
                            Button("Aktiv", systemImage: "checkmark") { activeGymID = gym.id.uuidString }
                                .tint(.blue)
                        }
                    }
                }
            } footer: {
                Text("Dein Trainingsverlauf bleibt beim Studiowechsel erhalten. Freie Gewichte zählen überall weiter, Geräte gehören zu ihrem Studio.")
            }
        }
        .navigationTitle("Studios")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Studio hinzufügen", systemImage: "plus") {
                    newName = ""
                    showAddAlert = true
                }
            }
        }
        .alert("Neues Studio", isPresented: $showAddAlert) {
            TextField("Name", text: $newName)
            Button("Abbrechen", role: .cancel) {}
            Button("Anlegen", action: addGym)
        }
        .confirmationDialog(
            "Studio löschen?",
            isPresented: Binding(get: { gymToDelete != nil }, set: { if !$0 { gymToDelete = nil } }),
            titleVisibility: .visible,
            presenting: gymToDelete
        ) { gym in
            Button("„\(gym.name)“ löschen", role: .destructive) { delete(gym) }
        } message: { _ in
            Text("Die Geräte dieses Studios werden gelöscht und aus deinen Plänen entfernt. Vergangene Trainings bleiben im Verlauf.")
        }
    }

    private func isActive(_ gym: Gym) -> Bool {
        gyms.active(id: activeGymID)?.id == gym.id
    }

    private func addGym() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let gym = Gym(name: name)
        modelContext.insert(gym)
        try? modelContext.save()
    }

    private func delete(_ gym: Gym) {
        let wasActive = isActive(gym)
        modelContext.delete(gym)
        try? modelContext.save()
        if wasActive {
            activeGymID = gyms.first { $0.id != gym.id }?.id.uuidString ?? ""
        }
        gymToDelete = nil
    }
}

struct GymDetailView: View {
    @Bindable var gym: Gym

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""
    @State private var showEditor = false

    private var machines: [Exercise] {
        gym.exercises.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $gym.name)
            }

            Section {
                ForEach(machines) { machine in
                    NavigationLink {
                        ExerciseDetailView(exercise: machine)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(machine.name)
                            Text(machine.notes.isEmpty ? machine.muscleGroup.rawValue : "\(machine.muscleGroup.rawValue) · \(machine.notes)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let sorted = machines
                    for index in offsets { modelContext.delete(sorted[index]) }
                    try? modelContext.save()
                }

                Button("Gerät hinzufügen", systemImage: "plus") { showEditor = true }
            } header: {
                Text("Geräte")
            } footer: {
                Text("Lege hier die Maschinen deines Studios an – mit Notizen wie Sitzhöhe. Geräte kannst du auch direkt im Training hinzufügen.")
            }

            Section {
                Button("Als aktives Studio setzen") { activeGymID = gym.id.uuidString }
                    .disabled(activeGymID == gym.id.uuidString)
            }
        }
        .navigationTitle(gym.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            ExerciseEditorView(exercise: nil, defaultGym: gym, preferMachine: true)
        }
    }
}
