import SwiftUI
import SwiftData

/// Training tab: running workout, this week at a glance, the user's plans and a free workout.
struct PlanListView: View {
    let runningSession: WorkoutSession?
    let onStart: (WorkoutPlan?) -> Void
    let onResume: (WorkoutSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutPlan> { !$0.isDraft }, sort: \WorkoutPlan.sortIndex)
    private var plans: [WorkoutPlan]
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate != nil }, sort: \WorkoutSession.startDate)
    private var finishedSessions: [WorkoutSession]
    @AppStorage(AppSettings.weeklyGoalKey) private var weeklyGoal = AppSettings.defaultWeeklyGoal

    @State private var path: [WorkoutPlan] = []
    @State private var newPlan: WorkoutPlan?
    @State private var showSettings = false

    private var canStart: Bool { runningSession == nil }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let running = runningSession {
                    RunningWorkoutSection(session: running) { onResume(running) }
                }

                WeekSection(sessions: finishedSessions, goal: weeklyGoal)

                plansSection

                Section {
                    ExerciseRow(
                        icon: MuscleIcon(symbol: "bolt.fill", tint: .orange),
                        name: "Freies Training",
                        subtitle: "Übungen spontan wählen"
                    ) {
                        StartButton(isEnabled: canStart, label: "Freies Training starten") { onStart(nil) }
                    }
                }
            }
            .navigationTitle("Training")
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanEditorView(plan: plan, canStart: canStart) { onStart(plan) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GymMenu()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Neuer Plan", systemImage: "plus", action: createPlan)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Einstellungen", systemImage: "gearshape") {
                        showSettings = true
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $newPlan) { plan in
                NewPlanSheet(plan: plan)
            }
        }
    }

    // MARK: - Plans

    @ViewBuilder
    private var plansSection: some View {
        let next = WorkoutPlan.next(in: plans)
        Section {
            if plans.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Pläne", systemImage: "list.bullet.clipboard")
                } description: {
                    Text("Lege Pläne wie Push, Pull oder Beine an. Sätze, Wiederholungen und Pausen werden beim Training vorausgefüllt.")
                } actions: {
                    Button("Ersten Plan erstellen", systemImage: "plus", action: createPlan)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            ForEach(plans) { plan in
                NavigationLink(value: plan) {
                    PlanRow(plan: plan, isNext: plan === next, canStart: canStart) { onStart(plan) }
                }
                .contextMenu {
                    Button("Training starten", systemImage: "play.fill") { onStart(plan) }
                        .disabled(!canStart || plan.entries.isEmpty)
                    Button("Bearbeiten", systemImage: "pencil") { path.append(plan) }
                    Divider()
                    Button("Löschen", systemImage: "trash", role: .destructive) { delete(plan) }
                }
            }
            .onDelete { offsets in offsets.map { plans[$0] }.forEach(delete) }
            .onMove(perform: movePlans)
        } header: {
            Text("Meine Pläne")
        } footer: {
            if WorkoutPlan.next(in: plans) != nil {
                Text("„Als Nächstes“ ist der Plan, den du am längsten nicht trainiert hast.")
            }
        }
    }

    /// Inserts a hidden draft; `NewPlanSheet` either saves it or deletes it again.
    private func createPlan() {
        let plan = WorkoutPlan(name: "", sortIndex: (plans.map(\.sortIndex).max() ?? -1) + 1)
        plan.isDraft = true
        modelContext.insert(plan)
        newPlan = plan
    }

    private func delete(_ plan: WorkoutPlan) {
        withAnimation {
            modelContext.delete(plan)
            try? modelContext.save()
        }
    }

    private func movePlans(from source: IndexSet, to destination: Int) {
        var reordered = plans
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, plan) in reordered.enumerated() {
            plan.sortIndex = index
        }
    }
}

// MARK: - Running workout

private struct RunningWorkoutSection: View {
    let session: WorkoutSession
    let onResume: () -> Void

    var body: some View {
        let total = session.exercises.reduce(0) { $0 + $1.sets.count }
        let done = session.completedSets.count
        let current = WorkoutStats.currentExercise(in: session)

        Section {
            Button(action: onResume) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        MuscleIcon(symbol: "figure.strengthtraining.traditional", tint: .green, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.displayTitle)
                                .font(.headline)
                            Text(current.map { "Gerade: \($0.exerciseName)" } ?? "Alle Sätze erledigt")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text(session.startDate, style: .timer)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }
                    ProgressView(value: Double(done), total: Double(max(total, 1)))
                        .tint(.green)
                    HStack {
                        Text("\(done)/\(total) Sätze")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        Label("Fortsetzen", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.green, in: Capsule())
                    }
                }
                .padding(.vertical, 6)
                .contentShape(.rect)
            }
            .tint(.primary)
        } header: {
            Text("Läuft gerade")
        }
    }
}

// MARK: - This week

/// Mo–So strip with ticks on training days, the weekly goal and the streak.
/// Same numbers as the Statistik tab (`TrainingStats`).
private struct WeekSection: View {
    let sessions: [WorkoutSession]
    let goal: Int

    private let calendar = TrainingStats.calendar
    private static let dayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var body: some View {
        let now = Date.now
        let days = TrainingStats.trainingDays(sessions, weeks: 1, now: now, calendar: calendar)
        let count = TrainingStats.sessions(sessions, inWeekOf: now, calendar: calendar).count
        let streak = TrainingStats.streak(sessions, goal: goal, now: now, calendar: calendar)
        let monday = TrainingStats.weekStart(of: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)

        Section {
            VStack(spacing: 14) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { offset in
                        let day = calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
                        DayDot(
                            label: Self.dayLabels[offset],
                            trained: (days[calendar.startOfDay(for: day)] ?? 0) > 0,
                            isToday: day == today,
                            isFuture: day > today
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(count >= goal
                         ? "Wochenziel erreicht"
                         : "\(count) von \(Format.count(goal, "Training", "Trainings"))")
                        .font(.headline)
                        .foregroundStyle(count >= goal ? .green : .primary)
                    Spacer()
                    if streak > 0 {
                        Label("\(Format.count(streak, "Woche", "Wochen")) in Folge", systemImage: "flame.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else if count < goal {
                        Text("noch \(goal - count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        } header: {
            Text("Diese Woche")
        }
    }
}

private struct DayDot: View {
    let label: String
    let trained: Bool
    let isToday: Bool
    let isFuture: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            ZStack {
                Circle()
                    .fill(trained ? AnyShapeStyle(Color.green) : (isFuture ? AnyShapeStyle(.fill.quaternary) : AnyShapeStyle(.fill.tertiary)))
                if trained {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 30, height: 30)
            .overlay {
                if isToday && !trained {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label)\(trained ? ", trainiert" : "")")
    }
}

// MARK: - Plan row

private struct PlanRow: View {
    let plan: WorkoutPlan
    let isNext: Bool
    let canStart: Bool
    let onStart: () -> Void

    var body: some View {
        let muscles = plan.muscleGroups
        ExerciseRow(
            muscleGroup: muscles.first,
            name: plan.name,
            subtitle: muscles.isEmpty ? "Noch keine Übungen" : muscles.prefix(3).map(\.rawValue).joined(separator: " · "),
            details: details,
            tag: isNext ? "Als Nächstes" : nil
        ) {
            StartButton(isEnabled: canStart && !plan.entries.isEmpty, label: "\(plan.name) starten", action: onStart)
        }
    }

    private var details: [ExerciseDetail] {
        guard !plan.entries.isEmpty else { return [] }
        return [
            ExerciseDetail(systemImage: "list.bullet", text: Format.count(plan.entries.count, "Übung", "Übungen")),
            ExerciseDetail(
                systemImage: "clock.arrow.circlepath",
                text: plan.lastPerformed.map { Format.daysAgo($0) } ?? "neu"
            ),
        ]
    }
}

/// Round play button used by plan rows and "Freies Training".
private struct StartButton: View {
    let isEnabled: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

#Preview {
    PlanListView(runningSession: nil, onStart: { _ in }, onResume: { _ in })
        .modelContainer(PreviewData.container)
}
