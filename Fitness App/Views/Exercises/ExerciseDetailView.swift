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
                }
            }

            let records = WorkoutStats.records(for: exercise)
            if !records.isEmpty {
                Section("Rekorde") {
                    recordRow("Geschätztes 1RM", records.bestOneRepMax) { "\(Format.weight($0.rounded())) kg" }
                    recordRow("Höchstes Gewicht", records.heaviestWeight) { "\(Format.weight($0)) kg" }
                    recordRow("Meiste Wiederholungen", records.mostReps) { "\(Int($0)) Wdh." }
                    recordRow("Bestes Satzvolumen", records.bestSetVolume) { Format.volume($0) }
                    recordRow("Bestes Einheitenvolumen", records.bestSessionVolume) { Format.volume($0) }
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

    @ViewBuilder
    private func recordRow(_ title: String, _ record: RecordValue?, format: (Double) -> String) -> some View {
        if let record {
            LabeledContent {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(format(record.value)).monospacedDigit()
                    Text(record.date.formatted(.dateTime.day().month().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text(title)
            }
        }
    }
}
