import SwiftUI
import SwiftData

struct PlanEditorView: View {
    @Bindable var plan: WorkoutPlan

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    @State private var showPicker = false
    @State private var editingEntry: PlanEntry?

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $plan.name)
            }

            Section {
                let entries = plan.sortedEntries
                let labels = Supersets.labels(in: entries)
                ForEach(entries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        PlanEntryRow(entry: entry, supersetLabel: entry.supersetGroup.flatMap { labels[$0] })
                    }
                    .tint(.primary)
                    .swipeActions(edge: .leading) {
                        supersetButton(for: entry, in: entries)
                    }
                    .contextMenu {
                        supersetButton(for: entry, in: entries)
                    }
                }
                .onDelete(perform: deleteEntries)
                .onMove(perform: moveEntries)

                Button("Übung hinzufügen", systemImage: "plus") {
                    showPicker = true
                }
            } header: {
                Text("Übungen")
            } footer: {
                Text("Tippe auf eine Übung, um Sätze, Wiederholungen und Pause anzupassen. Nach rechts wischen verbindet sie mit der nächsten Übung zu einem Supersatz.")
            }
        }
        .navigationTitle(plan.name.isEmpty ? "Plan" : plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView(activeGym: gyms.active(id: activeGymID)) { exercises in
                add(exercises)
            }
        }
        .sheet(item: $editingEntry) { entry in
            PlanEntryEditorView(entry: entry)
                .presentationDetents([.medium])
        }
    }

    private func add(_ exercises: [Exercise]) {
        var nextIndex = (plan.entries.map(\.sortIndex).max() ?? -1) + 1
        for exercise in exercises {
            let entry = PlanEntry(sortIndex: nextIndex)
            modelContext.insert(entry)
            entry.exercise = exercise
            plan.entries.append(entry)
            nextIndex += 1
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private func supersetButton(for entry: PlanEntry, in entries: [PlanEntry]) -> some View {
        if Supersets.isLinkedWithNext(entry, in: entries) || (entry.supersetGroup != nil && Supersets.next(after: entry, in: entries) == nil) {
            Button("Supersatz lösen", systemImage: "scissors") {
                withAnimation { Supersets.unlink(entry, in: plan.entries) }
            }
            .tint(.orange)
        } else if Supersets.next(after: entry, in: entries) != nil {
            Button("Mit nächster verbinden", systemImage: "link") {
                withAnimation { Supersets.linkWithNext(entry, in: plan.entries) }
            }
            .tint(.indigo)
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        let sorted = plan.sortedEntries
        for index in offsets {
            let entry = sorted[index]
            plan.entries.removeAll { $0.persistentModelID == entry.persistentModelID }
            modelContext.delete(entry)
        }
        Supersets.cleanUp(plan.entries)
    }

    private func moveEntries(from source: IndexSet, to destination: Int) {
        var reordered = plan.sortedEntries
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in reordered.enumerated() {
            entry.sortIndex = index
        }
    }
}

private struct PlanEntryRow: View {
    let entry: PlanEntry
    let supersetLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let supersetLabel {
                SupersetTag(label: supersetLabel)
            }
            HStack {
                Text(entry.exercise?.name ?? "Gelöschte Übung")
                if let gym = entry.exercise?.gym {
                    Text(gym.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                }
            }
            Text("\(entry.targetSets) × \(Format.reps(min: entry.repsMin, max: entry.repsMax)) Wdh. · \(Format.rest(entry.restSeconds)) Pause")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct PlanEntryEditorView: View {
    @Bindable var entry: PlanEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Sätze: \(entry.targetSets)", value: $entry.targetSets, in: 1...10)
                Stepper("Wdh. von: \(entry.repsMin)", value: $entry.repsMin, in: 1...50)
                Stepper("Wdh. bis: \(entry.repsMax)", value: $entry.repsMax, in: 1...50)
                Stepper("Pause: \(Format.rest(entry.restSeconds))", value: $entry.restSeconds, in: 15...600, step: 15)
            }
            .onChange(of: entry.repsMin) { _, newValue in
                if entry.repsMax < newValue { entry.repsMax = newValue }
            }
            .onChange(of: entry.repsMax) { _, newValue in
                if entry.repsMin > newValue { entry.repsMin = newValue }
            }
            .navigationTitle(entry.exercise?.name ?? "Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
