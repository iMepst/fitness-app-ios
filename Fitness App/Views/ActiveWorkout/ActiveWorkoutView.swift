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
    /// Finished exercises the user opened again (they are collapsed otherwise).
    @State private var expanded: Set<PersistentIdentifier> = []
    @State private var showSessionNote = false
    @FocusState private var sessionNoteFocused: Bool

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
        ScrollViewReader { proxy in
            List {
                statusSection

                let entries = session.sortedExercises
                let current = WorkoutStats.currentExercise(in: session)

                if entries.count > 1 {
                    overviewSection(entries, current: current, proxy: proxy)
                }

                let labels = Supersets.labels(in: entries)
                ForEach(entries) { entry in
                    ExerciseLogSection(
                        entry: entry,
                        supersetLabel: entry.supersetGroup.flatMap { labels[$0] },
                        nextInSuperset: Supersets.isLinkedWithNext(entry, in: entries)
                            ? Supersets.next(after: entry, in: entries)?.exerciseName : nil,
                        canLinkWithNext: Supersets.next(after: entry, in: entries) != nil
                            && !Supersets.isLinkedWithNext(entry, in: entries),
                        isCurrent: entry === current,
                        isExpanded: expanded.contains(entry.persistentModelID),
                        onToggleExpanded: { toggleExpanded(entry) }
                    ) { set in
                        setCompleted(set, in: entry, proxy: proxy)
                    } onRemove: {
                        WorkoutFactory.remove(entry, from: session, in: modelContext)
                    } onLink: {
                        withAnimation { Supersets.linkWithNext(entry, in: session.exercises) }
                    } onUnlink: {
                        withAnimation { Supersets.unlinkFromNext(entry, in: session.exercises) }
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
            .animation(.snappy, value: expanded)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Menu {
                    Button("Notiz zum Training", systemImage: "note.text") {
                        showSessionNote = true
                        sessionNoteFocused = true
                    }
                    Button("Übung hinzufügen", systemImage: "plus") {
                        showPicker = true
                    }
                    Divider()
                    Button("Training verwerfen", systemImage: "trash", role: .destructive) {
                        showDiscardDialog = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mehr")
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
                RestTimerBar(timer: restTimer, upNext: upNext)
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
                        Text("Neue Bestleistung!").font(.headline)
                        Text("\(banner.exerciseName): \(banner.detail)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
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
                .presentationDetents([.fraction(0.65), .large])
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

    // MARK: - Sections

    private var statusSection: some View {
        let total = session.exercises.reduce(0) { $0 + $1.sets.count }
        let done = session.completedSets.count

        return Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.startDate, style: .timer)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(done)/\(total) Sätze")
                            .font(.headline)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(done)))
                        Text(Format.volume(session.volume))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(.green)
                    .animation(.snappy, value: done)
            }
            .padding(.vertical, 4)

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

            if showSessionNote || !session.notes.isEmpty {
                TextField("Notiz zum Training", text: $session.notes, axis: .vertical)
                    .font(.subheadline)
                    .focused($sessionNoteFocused)
            }
        }
    }

    /// Swipeable chips, one per exercise: progress and a jump to its section.
    private func overviewSection(_ entries: [SessionExercise], current: SessionExercise?, proxy: ScrollViewProxy) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(entries) { entry in
                        OverviewChip(entry: entry, isCurrent: entry === current) {
                            let id = entry.persistentModelID
                            if !entry.sets.isEmpty && entry.sets.allSatisfy(\.isCompleted) {
                                expanded.insert(id)
                            }
                            withAnimation { proxy.scrollTo(id, anchor: .top) }
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Actions

    private func toggleExpanded(_ entry: SessionExercise) {
        let id = entry.persistentModelID
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    private func setCompleted(_ set: SetEntry, in entry: SessionExercise, proxy: ScrollViewProxy) {
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
        // Exercise done: collapse it and bring the next one into view.
        if entry.sets.allSatisfy(\.isCompleted) {
            expanded.remove(entry.persistentModelID)
            if let next = WorkoutStats.currentExercise(in: session) {
                let id = next.persistentModelID
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                }
            }
        }
    }

    /// "Satz 2 · Dips" for the rest timer (set first, so it survives truncation).
    private var upNext: String? {
        guard let entry = WorkoutStats.currentExercise(in: session) else { return nil }
        let sets = entry.sortedSets
        guard let index = sets.firstIndex(where: { !$0.isCompleted }) else { return nil }
        let set = sets[index]
        let label = set.kind == .normal ? "Satz \(WorkoutStats.setNumbers(sets)[index])" : set.kind.label
        return "\(label) · \(entry.exerciseName)"
    }

    /// Changes whenever something shown in the Live Activity changes.
    private var activitySignature: String {
        let current = WorkoutStats.currentExercise(in: session)?.exerciseName ?? ""
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

/// Capsule in the exercise overview: "✓ Bankdrücken", "1/3 Dips".
private struct OverviewChip: View {
    let entry: SessionExercise
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        let done = entry.sets.filter(\.isCompleted).count
        let isFinished = !entry.sets.isEmpty && done == entry.sets.count

        let label = HStack(spacing: 5) {
            if isFinished {
                Image(systemName: "checkmark")
                    .fontWeight(.bold)
            } else {
                Text("\(done)/\(entry.sets.count)")
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
            Text(entry.exerciseName)
                .lineLimit(1)
        }

        Group {
            if isCurrent {
                Button(action: action) { label }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.bordered)
                    .tint(isFinished ? .green : nil)
            }
        }
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .accessibilityLabel("\(entry.exerciseName), \(done) von \(entry.sets.count) Sätzen")
    }
}

#Preview {
    let context = PreviewData.container.mainContext
    let plan = try! context.fetch(FetchDescriptor<WorkoutPlan>()).first
    let session = WorkoutFactory.startSession(plan: plan, gym: plan?.sessions.first?.gym, in: context)
    return ActiveWorkoutView(session: session)
        .modelContainer(PreviewData.container)
}
