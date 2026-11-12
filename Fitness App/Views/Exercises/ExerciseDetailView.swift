import SwiftUI
import SwiftData
import Charts

private enum ProgressMetric: String, CaseIterable, Identifiable {
    case oneRepMax = "Geschätztes 1RM"
    case topWeight = "Top-Gewicht"

    var id: String { rawValue }

    func value(of point: ProgressPoint) -> Double {
        switch self {
        case .oneRepMax: point.estimatedOneRepMax
        case .topWeight: point.topWeight
        }
    }
}

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var metric: ProgressMetric = .oneRepMax
    @State private var showEditor = false
    @State private var showDeleteConfirm = false

    var body: some View {
        let points = WorkoutStats.progress(for: exercise)
        let recent = Array(WorkoutStats.finishedEntries(for: exercise).prefix(10))

        List {
            Section {
                LabeledContent("Muskelgruppe", value: exercise.muscleGroup.rawValue)
                LabeledContent("Equipment", value: exercise.equipment.rawValue)
                LabeledContent("Studio", value: exercise.gym?.name ?? "Alle Studios")
                if !exercise.notes.isEmpty {
                    Label(exercise.notes, systemImage: "note.text")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Fortschritt") {
                if points.isEmpty {
                    Text("Noch keine Daten – trainiere diese Übung, um deinen Fortschritt zu sehen.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Metrik", selection: $metric) {
                        ForEach(ProgressMetric.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Chart(points) { point in
                        LineMark(
                            x: .value("Datum", point.date),
                            y: .value(metric.rawValue, metric.value(of: point))
                        )
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Datum", point.date),
                            y: .value(metric.rawValue, metric.value(of: point))
                        )
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel("kg")
                    .frame(height: 200)
                    .padding(.vertical, 8)

                    LabeledContent("Bestes geschätztes 1RM", value: "\(Format.weight(points.map(\.estimatedOneRepMax).max() ?? 0)) kg")
                    LabeledContent("Höchstes Gewicht", value: "\(Format.weight(points.map(\.topWeight).max() ?? 0)) kg")
                }
            }

            if !recent.isEmpty {
                Section("Letzte Einheiten") {
                    ForEach(recent) { entry in
                        HStack {
                            Text(entry.session?.startDate.formatted(.dateTime.day().month().year()) ?? "")
                            Spacer()
                            Text(WorkoutStats.summary(of: entry))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)
                    }
                }
            }

            if !exercise.isBuiltIn {
                Section {
                    Button("Übung löschen", role: .destructive) { showDeleteConfirm = true }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Bearbeiten") { showEditor = true }
        }
        .sheet(isPresented: $showEditor) {
            ExerciseEditorView(exercise: exercise, defaultGym: exercise.gym)
        }
        .confirmationDialog("Übung löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                dismiss()
                modelContext.delete(exercise)
                try? modelContext.save()
            }
        } message: {
            Text("Die Übung wird aus allen Plänen entfernt. Vergangene Trainings bleiben im Verlauf erhalten.")
        }
    }
}
