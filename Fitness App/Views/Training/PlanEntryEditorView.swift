import SwiftUI

/// Sheet for one exercise in a plan: sets, rep range, rest, superset and removal.
struct PlanEntryEditorView: View {
    @Bindable var entry: PlanEntry
    /// Called after the user chose "Aus Plan entfernen"; the sheet closes itself.
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss

    private struct RepRange: Equatable {
        let min: Int
        let max: Int
    }

    private static let repPresets: [(label: String, value: RepRange)] = [
        (5, 5), (6, 8), (8, 12), (10, 15), (15, 20),
    ].map { (Format.reps(min: $0.0, max: $0.1), RepRange(min: $0.0, max: $0.1)) }

    private static let restPresets: [(label: String, value: Int)] = [45, 60, 90, 120, 180]
        .map { (String(format: "%d:%02d", $0 / 60, $0 % 60), $0) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    setsCard
                    repsCard
                    restCard
                    actionsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: entry.repsMin) { _, newValue in
                if entry.repsMax < newValue { entry.repsMax = newValue }
            }
            .onChange(of: entry.repsMax) { _, newValue in
                if entry.repsMin > newValue { entry.repsMin = newValue }
            }
            .navigationTitle(entry.exercise?.name ?? "Gelöschte Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Parts

    private var header: some View {
        HStack(spacing: 14) {
            MuscleIcon(group: entry.exercise?.muscleGroup, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                if let exercise = entry.exercise {
                    Text("\(exercise.muscleGroup.rawValue) · \(exercise.equipment.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(entry.targetSets) × \(Format.reps(min: entry.repsMin, max: entry.repsMax)) Wdh. · \(Format.rest(entry.restSeconds)) Pause")
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: entry.targetSets)
                    .animation(.snappy, value: entry.repsMin)
                    .animation(.snappy, value: entry.repsMax)
                    .animation(.snappy, value: entry.restSeconds)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var setsCard: some View {
        EditorCard(title: "Sätze", systemImage: "square.stack.3d.up") {
            ValueStepper(label: "Sätze", value: $entry.targetSets, range: 1...10)
        }
    }

    private var repsCard: some View {
        EditorCard(title: "Wiederholungen", systemImage: "repeat") {
            PresetChips(
                options: Self.repPresets,
                selection: RepRange(min: entry.repsMin, max: entry.repsMax)
            ) { range in
                entry.repsMin = range.min
                entry.repsMax = range.max
            }
            HStack {
                labeledCompact("von", value: $entry.repsMin)
                Spacer()
                labeledCompact("bis", value: $entry.repsMax)
            }
        }
    }

    private func labeledCompact(_ title: String, value: Binding<Int>) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ValueStepper(label: "Wiederholungen \(title)", value: value, range: 1...50, style: .compact)
        }
    }

    private var restCard: some View {
        EditorCard(title: "Pause", systemImage: "timer") {
            PresetChips(options: Self.restPresets, selection: entry.restSeconds) { entry.restSeconds = $0 }
            ValueStepper(label: "Pause", value: $entry.restSeconds, range: 15...600, step: 15, format: Format.rest)
        }
    }

    private var actionsCard: some View {
        let entries = entry.plan?.entries ?? []
        let next = Supersets.next(after: entry, in: entries)
        return VStack(spacing: 12) {
            EditorCard(title: "Supersatz", systemImage: "link") {
                Toggle(isOn: supersetBinding(in: entries)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mit nächster Übung verbinden")
                        Text(next.map { "Ohne Pause weiter mit \($0.exercise?.name ?? "der nächsten Übung")" } ?? "Das ist die letzte Übung im Plan.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(next == nil)
            }

            Button(role: .destructive) {
                onRemove()
                dismiss()
            } label: {
                Label("Aus Plan entfernen", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.red)
        }
    }

    private func supersetBinding(in entries: [PlanEntry]) -> Binding<Bool> {
        Binding {
            Supersets.isLinkedWithNext(entry, in: entries)
        } set: { isOn in
            withAnimation {
                if isOn {
                    Supersets.linkWithNext(entry, in: entries)
                } else {
                    Supersets.unlinkFromNext(entry, in: entries)
                }
            }
        }
    }
}

/// White-on-tint card used by the plan entry editor.
private struct EditorCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        PlanEntryEditorView(entry: PlanEntry(sortIndex: 0), onRemove: {})
    }
}
