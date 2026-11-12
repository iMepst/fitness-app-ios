import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDone: () -> Void

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Stark! Training gespeichert.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }

            Section {
                SessionStatsGrid(session: session)
                if !session.notes.isEmpty {
                    Label(session.notes, systemImage: "note.text")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Übungen") {
                ForEach(session.sortedExercises) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.exerciseName).font(.headline)
                            Text(WorkoutStats.summary(of: entry))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if WorkoutStats.isPersonalRecord(entry) {
                            Label("Bestleistung", systemImage: "trophy.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig", action: onDone)
            }
        }
    }
}

struct SessionStatsGrid: View {
    let session: WorkoutSession

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                stat("Dauer", Format.duration(session.duration))
                stat("Volumen", Format.volume(session.volume))
            }
            GridRow {
                stat("Sätze", "\(session.completedSets.count)")
                stat("Übungen", "\(session.exercises.count)")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
