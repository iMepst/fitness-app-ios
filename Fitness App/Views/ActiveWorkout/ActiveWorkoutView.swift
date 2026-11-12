import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var restTimer = RestTimer()
    @State private var showPicker = false
    @State private var showFinishDialog = false
    @State private var showDiscardDialog = false
    @State private var showEmptyAlert = false
    @State private var isFinished = false
    @State private var setCompletedTrigger = 0

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
            }

            ForEach(session.sortedExercises) { entry in
                ExerciseLogSection(entry: entry) {
                    dismissKeyboard()
                    setCompletedTrigger += 1
                    restTimer.start(seconds: entry.restSeconds)
                } onRemove: {
                    WorkoutFactory.remove(entry, from: session, in: modelContext)
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
            await RestTimer.requestAuthorization()
        }
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
        if WorkoutFactory.finish(session, in: modelContext) {
            withAnimation { isFinished = true }
        }
    }

    private func discard() {
        restTimer.stop()
        dismiss()
        WorkoutFactory.discard(session, in: modelContext)
    }
}

private struct ExerciseLogSection: View {
    @Bindable var entry: SessionExercise
    let onSetCompleted: () -> Void
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Section {
            if let last = lastPerformanceText {
                Label(last, systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text("Satz").frame(width: 36)
                Text("kg").frame(maxWidth: .infinity)
                Text("Wdh.").frame(maxWidth: .infinity)
                Image(systemName: "checkmark").frame(width: 32)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(Array(entry.sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(number: index + 1, set: set) { completed in
                    if completed { onSetCompleted() }
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
                Text(entry.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    Text("Pause: \(Format.rest(entry.restSeconds))")
                    Button("Übung entfernen", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            .textCase(nil)
        }
    }

    private var lastPerformanceText: String? {
        guard let exercise = entry.exercise,
              let last = WorkoutStats.lastPerformance(of: exercise, excluding: entry.session),
              let date = last.session?.startDate
        else { return nil }
        return "Letztes Mal (\(date.formatted(.dateTime.day().month()))): \(WorkoutStats.summary(of: last))"
    }
}

private struct SetRow: View {
    let number: Int
    @Bindable var set: SetEntry
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .monospacedDigit()
                .frame(width: 36)
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
