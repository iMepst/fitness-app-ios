import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var restTimer = RestTimer.shared
    @State private var showPicker = false
    @State private var showFinishDialog = false
    @State private var showDiscardDialog = false
    @State private var showEmptyAlert = false
    @State private var isFinished = false
    @State private var setCompletedTrigger = 0
    @State private var plateTarget: PlateTarget?
    @State private var recordBanner: RecordBanner?

    private struct RecordBanner: Identifiable, Equatable {
        let id = UUID()
        let exerciseName: String
        let detail: String
    }

    private struct PlateTarget: Identifiable {
        let id = UUID()
        let exerciseName: String
        let weight: Double
    }

    var body: some View {
        NavigationStack {
            if isFinished {
                WorkoutSummaryView(session: session) { dismiss() }
            } else {
                workoutList
            }
        }
    }

    private var workoutList: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dauer").font(.caption).foregroundStyle(.secondary)
                        Text(session.startDate, style: .timer)
                            .font(.title2.bold())
                            .monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Sätze").font(.caption).foregroundStyle(.secondary)
                        Text("\(session.completedSets.count)")
                            .font(.title2.bold())
                            .monospacedDigit()
                    }
                }
                if !session.gymName.isEmpty || session.gym?.currentLocker() != nil {
                    HStack {
                        if !session.gymName.isEmpty {
                            Label(session.gymName, systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let locker = session.gym?.currentLocker() {
                            Label("Spind \(locker)", systemImage: "lock.fill")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                        }
                    }
                    .font(.subheadline)
                }
                TextField("Notiz zum Training", text: $session.notes, axis: .vertical)
                    .font(.subheadline)
            }

            let entries = session.sortedExercises
            let labels = Supersets.labels(in: entries)
            ForEach(entries) { entry in
                ExerciseLogSection(
                    entry: entry,
                    supersetLabel: entry.supersetGroup.flatMap { labels[$0] },
                    nextInSuperset: Supersets.isLinkedWithNext(entry, in: entries)
                        ? Supersets.next(after: entry, in: entries)?.exerciseName : nil,
                    canLinkWithNext: Supersets.next(after: entry, in: entries) != nil
                        && !Supersets.isLinkedWithNext(entry, in: entries)
                ) { set in
                    dismissKeyboard()
                    setCompletedTrigger += 1
                    if WorkoutStats.isRecordSet(set) {
                        withAnimation(.spring) {
                            recordBanner = RecordBanner(
                                exerciseName: entry.exerciseName,
                                detail: "\(Format.weight(set.weight)) kg × \(set.reps) · 1RM ≈ \(Format.weight(WorkoutStats.estimatedOneRepMax(weight: set.weight, reps: set.reps).rounded())) kg"
                            )
                        }
                    }
                    if Supersets.shouldStartRest(after: entry, in: session.exercises) {
                        restTimer.start(seconds: entry.restSeconds)
                    }
                } onRemove: {
                    WorkoutFactory.remove(entry, from: session, in: modelContext)
                } onLink: {
                    withAnimation { Supersets.linkWithNext(entry, in: session.exercises) }
                } onUnlink: {
                    withAnimation { Supersets.unlink(entry, in: session.exercises) }
                } onPlateCalculator: {
                    plateTarget = PlateTarget(
                        exerciseName: entry.exerciseName,
                        weight: (entry.sortedSets.first { !$0.isCompleted } ?? entry.sortedSets.last)?.weight ?? 0
                    )
                }
            }

            Section {
                Button("Übung hinzufügen", systemImage: "plus") {
                    showPicker = true
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Verwerfen", role: .destructive) { showDiscardDialog = true }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Beenden", action: attemptFinish)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { dismissKeyboard() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if restTimer.isActive {
                RestTimerBar(timer: restTimer)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let banner = recordBanner {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Neue Bestleistung! 🏆").font(.headline)
                        Text("\(banner.exerciseName): \(banner.detail)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { withAnimation { recordBanner = nil } }
                .task(id: banner.id) {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { recordBanner = nil }
                }
            }
        }
        .sensoryFeedback(.success, trigger: recordBanner?.id) { _, new in new != nil }
        .animation(.snappy, value: restTimer.isActive)
        .sensoryFeedback(.success, trigger: restTimer.finishCount)
        .sensoryFeedback(.impact(weight: .medium), trigger: setCompletedTrigger)
        .sheet(isPresented: $showPicker) {
            ExercisePickerView(activeGym: session.gym) { exercises in
                for exercise in exercises {
                    WorkoutFactory.addExercise(exercise, to: session, in: modelContext)
                }
            }
        }
        .sheet(item: $plateTarget) { target in
            PlateCalculatorSheet(exerciseName: target.exerciseName, target: target.weight)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Training beenden?", isPresented: $showFinishDialog, titleVisibility: .visible) {
            Button("Training beenden", action: finish)
        } message: {
            Text("\(Format.count(openSetCount, "nicht abgehakter Satz wird", "nicht abgehakte Sätze werden")) verworfen.")
        }
        .confirmationDialog("Training verwerfen?", isPresented: $showDiscardDialog, titleVisibility: .visible) {
            Button("Training verwerfen", role: .destructive, action: discard)
        } message: {
            Text("Alle Sätze dieses Trainings werden gelöscht.")
        }
        .alert("Noch kein Satz erledigt", isPresented: $showEmptyAlert) {
            Button("Weiter trainieren", role: .cancel) {}
            Button("Verwerfen", role: .destructive, action: discard)
        } message: {
            Text("Hake mindestens einen Satz ab, um das Training zu speichern.")
        }
        .task {
            WorkoutActivityController.shared.start(for: session)
            await RestTimer.requestAuthorization()
        }
        .onChange(of: activitySignature) {
            WorkoutActivityController.shared.update(for: session)
        }
    }

    /// Changes whenever something shown in the Live Activity changes.
    private var activitySignature: String {
        let current = session.sortedExercises.first { $0.sets.contains { !$0.isCompleted } }?.exerciseName ?? ""
        return "\(session.completedSets.count)|\(session.exercises.count)|\(current)"
    }

    private var openSetCount: Int {
        session.exercises.flatMap(\.sets).filter { !$0.isCompleted }.count
    }

    private func attemptFinish() {
        dismissKeyboard()
        if session.completedSets.isEmpty {
            showEmptyAlert = true
        } else if openSetCount > 0 {
            showFinishDialog = true
        } else {
            finish()
        }
    }

    private func finish() {
        restTimer.stop()
        WorkoutActivityController.shared.end()
        if WorkoutFactory.finish(session, in: modelContext) {
            withAnimation { isFinished = true }
            Task { await HealthSync.export(session, in: modelContext) }
        }
    }

    private func discard() {
        restTimer.stop()
        WorkoutActivityController.shared.end()
        dismiss()
        WorkoutFactory.discard(session, in: modelContext)
    }
}

private struct ExerciseLogSection: View {
    @Bindable var entry: SessionExercise
    let supersetLabel: String?
    /// Name of the next exercise when this one is linked with it.
    let nextInSuperset: String?
    let canLinkWithNext: Bool
    let onSetCompleted: (SetEntry) -> Void
    let onRemove: () -> Void
    let onLink: () -> Void
    let onUnlink: () -> Void
    let onPlateCalculator: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let lastEntry = lastPerformance
        Section {
            if let last = lastEntry, let date = last.session?.startDate {
                Label("Letztes Mal (\(date.formatted(.dateTime.day().month()))): \(WorkoutStats.summary(of: last))", systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !last.notes.isEmpty {
                    Label(last.notes, systemImage: "note.text")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let suggestion = suggestedWeight {
                HStack {
                    Label("Vorschlag: \(Format.weight(suggestion)) kg", systemImage: "arrow.up.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Übernehmen") {
                        for set in openWorkingSets where set.weight < suggestion {
                            set.weight = suggestion
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.subheadline)
                }
            }

            TextField("Notiz", text: $entry.notes, axis: .vertical)
                .font(.subheadline)

            HStack(spacing: 12) {
                Text("Satz").frame(width: 36)
                Text("kg").frame(maxWidth: .infinity)
                Text("Wdh.").frame(maxWidth: .infinity)
                Image(systemName: "checkmark").frame(width: 32)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            let sets = entry.sortedSets
            let numbers = WorkoutStats.setNumbers(sets)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                SetRow(number: numbers[index], set: set) { completed in
                    if completed { onSetCompleted(set) }
                }
            }
            .onDelete { offsets in
                let sorted = entry.sortedSets
                for index in offsets {
                    WorkoutFactory.remove(sorted[index], from: entry, in: modelContext)
                }
            }

            Button("Satz hinzufügen", systemImage: "plus.circle") {
                WorkoutFactory.addSet(to: entry, in: modelContext)
            }
            .font(.subheadline)
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let supersetLabel {
                        SupersetTag(label: supersetLabel)
                    }
                    Text(entry.exerciseName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Menu {
                    Text("Pause: \(Format.rest(entry.restSeconds))")
                    if canLinkWithNext {
                        Button("Mit nächster Übung verbinden", systemImage: "link", action: onLink)
                    }
                    if supersetLabel != nil {
                        Button("Supersatz lösen", systemImage: "scissors", action: onUnlink)
                    }
                    if entry.exercise?.equipment == .langhantel {
                        Button("Scheibenrechner", systemImage: "scalemass", action: onPlateCalculator)
                    }
                    Button("Übung entfernen", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            .textCase(nil)
        } footer: {
            if let nextInSuperset {
                Label("Ohne Pause weiter mit \(nextInSuperset)", systemImage: "arrow.down")
            }
        }
    }

    private var openWorkingSets: [SetEntry] {
        entry.sortedSets.filter { !$0.isCompleted && $0.kind == .normal }
    }

    /// Shown only while some open working set is still below the suggestion.
    private var suggestedWeight: Double? {
        guard let suggestion = WorkoutStats.suggestedWeight(for: entry),
              openWorkingSets.contains(where: { $0.weight < suggestion })
        else { return nil }
        return suggestion
    }

    private var lastPerformance: SessionExercise? {
        guard let exercise = entry.exercise else { return nil }
        return WorkoutStats.lastPerformance(of: exercise, excluding: entry.session)
    }
}

private struct SetRow: View {
    let number: Int
    @Bindable var set: SetEntry
    let onToggle: (Bool) -> Void

    private static let rpeValues: [Double] = Array(stride(from: 6.0, through: 10.0, by: 0.5))

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Satzart", selection: $set.kind) {
                    ForEach(SetKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                Picker("RPE", selection: $set.rpe) {
                    Text("Kein RPE").tag(Double?.none)
                    ForEach(Self.rpeValues, id: \.self) { value in
                        Text("RPE \(Format.rpe(value))").tag(Double?.some(value))
                    }
                }
                .pickerStyle(.menu)
            } label: {
                SetBadge(kind: set.kind, number: number, rpe: set.rpe)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(set.kind.label) \(number), Satzart und RPE ändern")
            DecimalField(placeholder: "kg", value: $set.weight)
                .frame(maxWidth: .infinity)
            IntegerField(placeholder: "Wdh.", value: $set.reps)
                .frame(maxWidth: .infinity)
            Button {
                set.isCompleted.toggle()
                set.completedAt = set.isCompleted ? .now : nil
                onToggle(set.isCompleted)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .frame(width: 32)
            .accessibilityLabel(set.isCompleted ? "Satz erledigt" : "Satz abhaken")
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.12) : nil)
    }
}

#Preview {
    let context = PreviewData.container.mainContext
    let plan = try! context.fetch(FetchDescriptor<WorkoutPlan>()).first
    let session = WorkoutFactory.startSession(plan: plan, gym: plan?.sessions.first?.gym, in: context)
    return ActiveWorkoutView(session: session)
        .modelContainer(PreviewData.container)
}
