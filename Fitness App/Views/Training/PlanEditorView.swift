import SwiftUI
import SwiftData

/// Name and exercise list of a plan. Pushed for existing plans (changes save
/// automatically) and embedded in `NewPlanSheet` when creating one.
struct PlanEditorView: View {
    @Bindable var plan: WorkoutPlan
    var isNew = false
    var canStart = true
    var onStart: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    @State private var showPicker = false
    @State private var editingEntry: PlanEntry?
    @State private var pendingRemoval: PlanEntry?
    @FocusState private var nameFocused: Bool

    private static let nameSuggestions = ["Push", "Pull", "Beine", "Oberkörper", "Unterkörper", "Ganzkörper"]

    var body: some View {
        List {
            nameSection
            exercisesSection
        }
        .navigationTitle(isNew ? "Neuer Plan" : (plan.name.isEmpty ? "Plan" : plan.name))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { startButton }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView(activeGym: gyms.active(id: activeGymID)) { exercises in
                add(exercises)
            }
        }
        .sheet(item: $editingEntry, onDismiss: removePendingEntry) { entry in
            PlanEntryEditorView(entry: entry) { pendingRemoval = entry }
                .presentationDetents([.large])
        }
        .onAppear {
            if isNew && plan.name.isEmpty { nameFocused = true }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField("Planname", text: $plan.name, prompt: Text("z. B. Push"))
                .font(.title3.weight(.semibold))
                .focused($nameFocused)
                .submitLabel(.done)

            if plan.name.trimmingCharacters(in: .whitespaces).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.nameSuggestions, id: \.self) { name in
                            Button(name) {
                                plan.name = name
                                nameFocused = false
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        } header: {
            Text("Name")
        }
    }

    private var exercisesSection: some View {
        let entries = plan.sortedEntries
        let labels = Supersets.labels(in: entries)

        return Section {
            if entries.isEmpty {
                emptyState
            } else {
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
                        Button("Entfernen", systemImage: "trash", role: .destructive) {
                            remove([entry])
                        }
                    }
                }
                .onDelete { offsets in remove(offsets.map { entries[$0] }) }
                .onMove(perform: moveEntries)

                Button("Übung hinzufügen", systemImage: "plus.circle.fill") {
                    showPicker = true
                }
            }
        } header: {
            HStack {
                Text("Übungen")
                Spacer()
                if !entries.isEmpty {
                    let sets = entries.reduce(0) { $0 + $1.targetSets }
                    Text("\(Format.count(entries.count, "Übung", "Übungen")) · \(Format.count(sets, "Satz", "Sätze"))")
                        .monospacedDigit()
                }
            }
        } footer: {
            if entries.count > 1 {
                Text("Gedrückt halten und ziehen zum Sortieren, nach links wischen zum Entfernen.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)
            Text("Noch keine Übungen")
                .font(.headline)
            Text("Wähle die Übungen in der Reihenfolge, in der du sie trainierst. Sätze und Pausen stellst du danach ein.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                nameFocused = false
                showPicker = true
            } label: {
                Label("Übungen wählen", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var startButton: some View {
        if !isNew, let onStart, !plan.entries.isEmpty {
            Button(action: onStart) {
                Label("Training starten", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStart)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func supersetButton(for entry: PlanEntry, in entries: [PlanEntry]) -> some View {
        if Supersets.isLinkedWithNext(entry, in: entries) {
            Button("Supersatz lösen", systemImage: "scissors") {
                withAnimation { Supersets.unlinkFromNext(entry, in: plan.entries) }
            }
            .tint(.orange)
        } else if Supersets.next(after: entry, in: entries) != nil {
            Button("Mit nächster verbinden", systemImage: "link") {
                withAnimation { Supersets.linkWithNext(entry, in: plan.entries) }
            }
            .tint(.indigo)
        }
    }

    // MARK: - Actions

    private func add(_ exercises: [Exercise]) {
        var nextIndex = (plan.entries.map(\.sortIndex).max() ?? -1) + 1
        for exercise in exercises {
            let entry = PlanEntry(sortIndex: nextIndex)
            modelContext.insert(entry)
            entry.exercise = exercise
            plan.entries.append(entry)
            nextIndex += 1
        }
        if !isNew { try? modelContext.save() }
    }

    private func removePendingEntry() {
        guard let entry = pendingRemoval else { return }
        pendingRemoval = nil
        remove([entry])
    }

    private func remove(_ removed: [PlanEntry]) {
        withAnimation {
            for entry in removed {
                plan.entries.removeAll { $0.persistentModelID == entry.persistentModelID }
                modelContext.delete(entry)
            }
            Supersets.cleanUp(plan.entries)
            for (index, entry) in plan.sortedEntries.enumerated() {
                entry.sortIndex = index
            }
        }
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
        HStack(spacing: 12) {
            MuscleIcon(group: entry.exercise?.muscleGroup, size: 40)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.exercise?.name ?? "Gelöschte Übung")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if let gym = entry.exercise?.gym {
                        Text(gym.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                    }
                }
                HStack(spacing: 12) {
                    detail("square.stack.3d.up", Format.count(entry.targetSets, "Satz", "Sätze"))
                    detail("repeat", "\(Format.reps(min: entry.repsMin, max: entry.repsMax)) Wdh.")
                    detail("timer", Format.rest(entry.restSeconds))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                if let supersetLabel {
                    SupersetTag(label: supersetLabel)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            if let supersetLabel {
                Capsule()
                    .fill(SupersetTag.color(for: supersetLabel))
                    .frame(width: 4)
                    .offset(x: -12)
            }
        }
        .contentShape(.rect)
    }

    private func detail(_ systemImage: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
        }
        .labelStyle(DetailLabelStyle())
    }
}

private struct DetailLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

/// Full-screen sheet for creating a plan; the plan stays a hidden draft until "Sichern".
struct NewPlanSheet: View {
    let plan: WorkoutPlan

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var didSave = false
    @State private var confirmDiscard = false

    private var trimmedName: String { plan.name.trimmingCharacters(in: .whitespaces) }
    private var hasContent: Bool { !trimmedName.isEmpty || !plan.entries.isEmpty }

    var body: some View {
        NavigationStack {
            PlanEditorView(plan: plan, isNew: true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            if hasContent { confirmDiscard = true } else { dismiss() }
                        }
                        .confirmationDialog("Plan verwerfen?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                            Button("Verwerfen", role: .destructive) { dismiss() }
                        } message: {
                            Text("Name und Übungen werden nicht gespeichert.")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Sichern", action: save)
                            .disabled(trimmedName.isEmpty)
                    }
                }
        }
        .interactiveDismissDisabled(hasContent)
        .onDisappear {
            if !didSave { discard() }
        }
    }

    private func save() {
        plan.name = trimmedName
        plan.isDraft = false
        didSave = true
        try? modelContext.save()
        dismiss()
    }

    private func discard() {
        modelContext.delete(plan)
        try? modelContext.save()
    }
}
