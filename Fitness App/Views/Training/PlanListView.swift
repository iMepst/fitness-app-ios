import SwiftUI
import SwiftData

struct PlanListView: View {
    let runningSession: WorkoutSession?
    let onStart: (WorkoutPlan?) -> Void
    let onResume: (WorkoutSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutPlan> { !$0.isDraft }, sort: \WorkoutPlan.sortIndex)
    private var plans: [WorkoutPlan]

    @State private var path: [WorkoutPlan] = []
    @State private var newPlan: WorkoutPlan?
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let running = runningSession {
                    Section("Laufendes Training") {
                        Button {
                            onResume(running)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(running.displayTitle).font(.headline)
                                    Text("Gestartet \(Text(running.startDate, style: .relative))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .tint(.primary)
                    }
                }

                Section("Meine Pläne") {
                    if plans.isEmpty {
                        ContentUnavailableView(
                            "Noch keine Pläne",
                            systemImage: "list.clipboard",
                            description: Text("Lege deinen ersten Trainingsplan an, z. B. Push, Pull oder Beine.")
                        )
                    }
                    ForEach(plans) { plan in
                        NavigationLink(value: plan) {
                            PlanRow(plan: plan, canStart: runningSession == nil) { onStart(plan) }
                        }
                    }
                    .onDelete(perform: deletePlans)
                    .onMove(perform: movePlans)
                }

                Section {
                    Button("Freies Training starten", systemImage: "bolt.fill") {
                        onStart(nil)
                    }
                    .disabled(runningSession != nil)
                }
            }
            .navigationTitle("Training")
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanEditorView(plan: plan, canStart: runningSession == nil) { onStart(plan) }
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

    /// Inserts a hidden draft; `NewPlanSheet` either saves it or deletes it again.
    private func createPlan() {
        let plan = WorkoutPlan(name: "", sortIndex: (plans.map(\.sortIndex).max() ?? -1) + 1)
        plan.isDraft = true
        modelContext.insert(plan)
        newPlan = plan
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
        try? modelContext.save()
    }

    private func movePlans(from source: IndexSet, to destination: Int) {
        var reordered = plans
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, plan) in reordered.enumerated() {
            plan.sortIndex = index
        }
    }
}

private struct PlanRow: View {
    let plan: WorkoutPlan
    let canStart: Bool
    let onStart: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Start", action: onStart)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(!canStart || plan.entries.isEmpty)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts = [Format.count(plan.entries.count, "Übung", "Übungen")]
        if let last = plan.lastPerformed {
            parts.append("zuletzt \(last.formatted(.dateTime.day().month()))")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    PlanListView(runningSession: nil, onStart: { _ in }, onResume: { _ in })
        .modelContainer(PreviewData.container)
}
