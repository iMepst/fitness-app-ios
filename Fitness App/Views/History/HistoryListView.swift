import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate != nil }, sort: \WorkoutSession.startDate, order: .reverse)
    private var sessions: [WorkoutSession]

    private struct MonthGroup: Identifiable {
        let id: Date
        let sessions: [WorkoutSession]
    }

    private var groups: [MonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) {
            calendar.dateInterval(of: .month, for: $0.startDate)?.start ?? $0.startDate
        }
        return grouped
            .map { MonthGroup(id: $0.key, sessions: $0.value) }
            .sorted { $0.id > $1.id }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section(group.id.formatted(.dateTime.month(.wide).year())) {
                        ForEach(group.sessions) { session in
                            NavigationLink(value: session) {
                                HistoryRow(session: session)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                HealthSync.deleteWorkout(id: group.sessions[index].healthKitWorkoutID)
                                modelContext.delete(group.sessions[index])
                            }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Trainings",
                        systemImage: "clock",
                        description: Text("Abgeschlossene Trainings erscheinen hier.")
                    )
                }
            }
            .navigationTitle("Verlauf")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
        }
    }
}

private struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.displayTitle).font(.headline)
                Spacer()
                Text(session.startDate.formatted(.dateTime.weekday(.abbreviated).day().month()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("\(Format.duration(session.duration)) · \(Format.volume(session.volume)) · \(Format.count(session.completedSets.count, "Satz", "Sätze"))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !session.gymName.isEmpty {
                Label(session.gymName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section {
                LabeledContent("Datum", value: session.startDate.formatted(date: .complete, time: .shortened))
                if !session.gymName.isEmpty {
                    LabeledContent("Studio", value: session.gymName)
                }
                SessionStatsGrid(session: session)
                if !session.notes.isEmpty {
                    Label(session.notes, systemImage: "note.text")
                        .foregroundStyle(.secondary)
                }
            }

            let entries = session.sortedExercises
            let labels = Supersets.labels(in: entries)
            ForEach(entries) { entry in
                Section {
                    let sets = entry.sortedSets
                    let numbers = WorkoutStats.setNumbers(sets)
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text(set.historyLabel(number: numbers[index]))
                                .foregroundStyle(set.kind == .normal ? .secondary : set.kind.tint)
                            Spacer()
                            Text(set.weight > 0 ? "\(Format.weight(set.weight)) kg × \(set.reps)" : "\(set.reps) Wdh.")
                                .monospacedDigit()
                        }
                    }
                    if !entry.notes.isEmpty {
                        Label(entry.notes, systemImage: "note.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        if let label = entry.supersetGroup.flatMap({ labels[$0] }) {
                            SupersetTag(label: label)
                        }
                        Text(entry.exerciseName)
                        if WorkoutStats.isPersonalRecord(entry) {
                            Image(systemName: "trophy.fill").foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryListView()
        .modelContainer(PreviewData.container)
}
