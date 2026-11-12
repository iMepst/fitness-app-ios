import SwiftUI
import SwiftData

/// One exercise of the running workout as a list section: header row in the
/// app's `ExerciseRow` style, last time / suggestion, and the set rows.
/// A finished exercise collapses to its header row.
struct ExerciseLogSection: View {
    @Bindable var entry: SessionExercise
    let supersetLabel: String?
    /// Name of the next exercise when this one is linked with it.
    let nextInSuperset: String?
    let canLinkWithNext: Bool
    let isCurrent: Bool
    /// Only relevant for finished exercises (they are collapsed otherwise).
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onSetCompleted: (SetEntry) -> Void
    let onRemove: () -> Void
    let onLink: () -> Void
    let onUnlink: () -> Void
    let onPlateCalculator: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showNote = false
    @FocusState private var noteFocused: Bool

    private var isFinished: Bool {
        !entry.sets.isEmpty && entry.sets.allSatisfy(\.isCompleted)
    }

    private var isCollapsed: Bool { isFinished && !isExpanded }

    var body: some View {
        Section {
            header
                .id(entry.persistentModelID)

            if !isCollapsed {
                lastTimeRows

                if showNote || !entry.notes.isEmpty {
                    TextField("Notiz zur Übung", text: $entry.notes, axis: .vertical)
                        .font(.subheadline)
                        .focused($noteFocused)
                }

                columnHeader

                let sets = entry.sortedSets
                let numbers = WorkoutStats.setNumbers(sets)
                let previous = WorkoutStats.previousSets(for: entry)
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    SetRow(
                        number: numbers[index],
                        set: set,
                        previous: index < previous.count ? previous[index] : nil
                    ) { completed in
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
            }
        } footer: {
            if let nextInSuperset, !isCollapsed {
                Label("Ohne Pause weiter mit \(nextInSuperset)", systemImage: "arrow.down")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ExerciseRow(
            muscleGroup: entry.exercise?.muscleGroup,
            name: entry.exerciseName,
            details: details,
            supersetLabel: supersetLabel,
            tag: isCurrent ? "Jetzt" : nil,
            isDone: isFinished
        ) {
            HStack(spacing: 14) {
                menu
                if isFinished {
                    RowChevron(isExpanded: isExpanded)
                }
            }
        }
        .onTapGesture {
            if isFinished { withAnimation(.snappy) { onToggleExpanded() } }
        }
        .animation(.snappy, value: isFinished)
    }

    private var details: [ExerciseDetail] {
        if isFinished {
            return [ExerciseDetail(systemImage: "checkmark", text: WorkoutStats.summary(of: entry))]
        }
        var result: [ExerciseDetail] = []
        let done = entry.sets.filter(\.isCompleted).count
        result.append(ExerciseDetail(systemImage: "square.stack.3d.up", text: "\(done)/\(entry.sets.count)"))
        if let min = entry.targetRepsMin, let max = entry.targetRepsMax {
            result.append(ExerciseDetail(systemImage: "repeat", text: "\(Format.reps(min: min, max: max)) Wdh."))
        }
        result.append(ExerciseDetail(systemImage: "timer", text: Format.rest(entry.restSeconds)))
        return result
    }

    private var menu: some View {
        Menu {
            Button(entry.notes.isEmpty ? "Notiz hinzufügen" : "Notiz bearbeiten", systemImage: "note.text") {
                showNote = true
                noteFocused = true
            }
            if canLinkWithNext {
                Button("Mit nächster Übung verbinden", systemImage: "link", action: onLink)
            }
            if nextInSuperset != nil {
                Button("Supersatz lösen", systemImage: "scissors", action: onUnlink)
            }
            if entry.exercise?.equipment == .langhantel {
                Button("Scheibenrechner", systemImage: "scalemass", action: onPlateCalculator)
            }
            Button("Übung entfernen", systemImage: "trash", role: .destructive, action: onRemove)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .accessibilityLabel("Optionen für \(entry.exerciseName)")
    }

    // MARK: - Last time & suggestion

    @ViewBuilder
    private var lastTimeRows: some View {
        if let last = lastPerformance, let date = last.session?.startDate {
            VStack(alignment: .leading, spacing: 6) {
                Label("Letztes Mal \(date.formatted(.dateTime.day().month())): \(WorkoutStats.summary(of: last))", systemImage: "clock.arrow.circlepath")
                if !last.notes.isEmpty {
                    Label(last.notes, systemImage: "note.text")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        if let suggestion = suggestedWeight {
            HStack {
                Label("Vorschlag", systemImage: "arrow.up.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer()
                Button("\(Format.weight(suggestion)) kg übernehmen") {
                    withAnimation {
                        for set in openWorkingSets where set.weight < suggestion {
                            set.weight = suggestion
                        }
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(.green)
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: SetRow.spacing) {
            Text("Satz").frame(width: SetRow.badgeWidth)
            Text("Vorher").frame(width: SetRow.previousWidth)
            Text("kg").frame(maxWidth: .infinity)
            Text("Wdh.").frame(maxWidth: .infinity)
            Color.clear.frame(width: SetRow.checkSize, height: 1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
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

// MARK: - Set row

private struct SetRow: View {
    let number: Int
    @Bindable var set: SetEntry
    let previous: SetEntry?
    let onToggle: (Bool) -> Void

    static let spacing: CGFloat = 8
    static let badgeWidth: CGFloat = 32
    static let previousWidth: CGFloat = 58
    static let checkSize: CGFloat = 38

    private static let rpeValues: [Double] = Array(stride(from: 6.0, through: 10.0, by: 0.5))

    var body: some View {
        HStack(spacing: Self.spacing) {
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
                    .frame(width: Self.badgeWidth, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(set.kind.label) \(number), Satzart und RPE ändern")

            previousButton

            DecimalField(placeholder: "kg", value: $set.weight, style: .filled)
                .frame(maxWidth: .infinity)
            IntegerField(placeholder: "Wdh.", value: $set.reps, style: .filled)
                .frame(maxWidth: .infinity)

            Button {
                withAnimation(.snappy) {
                    set.isCompleted.toggle()
                    set.completedAt = set.isCompleted ? .now : nil
                }
                onToggle(set.isCompleted)
            } label: {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(set.isCompleted ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
                    .frame(width: Self.checkSize, height: Self.checkSize)
                    .background(
                        set.isCompleted ? AnyShapeStyle(Color.green) : AnyShapeStyle(.fill.tertiary),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Satz erledigt" : "Satz abhaken")
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.12) : nil)
    }

    /// Same set last time; tapping copies its values into this (open) set.
    private var previousButton: some View {
        Button {
            guard let previous else { return }
            withAnimation {
                set.weight = previous.weight
                set.reps = previous.reps
            }
        } label: {
            Text(previousText)
                .font(.footnote)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .frame(width: Self.previousWidth, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(previous == nil || set.isCompleted)
        .accessibilityLabel(previous == nil ? "Kein Vorwert" : "Vorher \(previousText), übernehmen")
    }

    private var previousText: String {
        guard let previous else { return "–" }
        return previous.weight > 0
            ? "\(Format.weight(previous.weight))×\(previous.reps)"
            : "\(previous.reps) Wdh."
    }
}
