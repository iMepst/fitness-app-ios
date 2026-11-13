import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate != nil }, sort: \WorkoutSession.startDate)
    private var sessions: [WorkoutSession]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var bodyWeights: [BodyWeightEntry]
    @AppStorage(AppSettings.weeklyGoalKey) private var weeklyGoal = AppSettings.defaultWeeklyGoal

    @State private var showAddWeight = false

    private let calendar = TrainingStats.calendar

    var body: some View {
        // Refreshed on every render; cheap for personal data volumes.
        let now = Date.now
        NavigationStack {
            List {
                weekSection(now: now)
                calendarSection(now: now)
                muscleSection(now: now)
                volumeSection(now: now)
                recordsSection
                bodyWeightSection
            }
            .navigationTitle("Statistik")
            .task { await HealthSync.importBodyWeights(in: modelContext) }
            .refreshable { await HealthSync.importBodyWeights(in: modelContext) }
            .sheet(isPresented: $showAddWeight) {
                BodyWeightEditor()
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Sections

    private func weekSection(now: Date) -> some View {
        let count = TrainingStats.sessions(sessions, inWeekOf: now, calendar: calendar).count
        let streak = TrainingStats.streak(sessions, goal: weeklyGoal, now: now, calendar: calendar)
        return Section("Diese Woche") {
            HStack(spacing: 16) {
                Gauge(value: Double(min(count, weeklyGoal)), in: 0...Double(max(weeklyGoal, 1))) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(count)/\(weeklyGoal)")
                        .font(.headline)
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(count >= weeklyGoal ? .green : .accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(count >= weeklyGoal ? "Wochenziel erreicht! 🎉" : "Noch \(Format.count(weeklyGoal - count, "Training", "Trainings")) bis zum Ziel")
                        .font(.headline)
                    if streak > 0 {
                        Label("\(Format.count(streak, "Woche", "Wochen")) in Folge", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("Erreiche dein Wochenziel, um eine Serie zu starten.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func calendarSection(now: Date) -> some View {
        let weeks = 16
        let days = TrainingStats.trainingDays(sessions, weeks: weeks, now: now, calendar: calendar)
        let starts = TrainingStats.weekStarts(count: weeks, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        return Section {
            HStack(alignment: .top, spacing: 3) {
                VStack(spacing: 3) {
                    ForEach(Array(["Mo", "", "Mi", "", "Fr", "", "So"].enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 14)
                    }
                }
                ForEach(starts, id: \.self) { start in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { offset in
                            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                            let count = days[calendar.startOfDay(for: day)] ?? 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cellColor(count: count, isFuture: day > today))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(days.count) Trainingstage in den letzten \(weeks) Wochen")
        } header: {
            Text("Trainingskalender")
        } footer: {
            Text("Die letzten \(weeks) Wochen – jedes Kästchen ist ein Tag.")
        }
    }

    private func cellColor(count: Int, isFuture: Bool) -> Color {
        if isFuture { return .clear }
        switch count {
        case 0: return Color.secondary.opacity(0.15)
        case 1: return Color.accentColor.opacity(0.6)
        default: return Color.accentColor
        }
    }

    @ViewBuilder
    private func muscleSection(now: Date) -> some View {
        let rows = TrainingStats.muscleComparison(sessions, now: now, calendar: calendar)
        Section {
            if rows.isEmpty {
                Text("Diese und letzte Woche noch keine Arbeitssätze.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(rows) { row in
                    BarMark(
                        x: .value("Sätze", row.sets),
                        y: .value("Muskelgruppe", row.muscle.rawValue)
                    )
                    .foregroundStyle(by: .value("Woche", row.week))
                    .position(by: .value("Woche", row.week))
                }
                .chartForegroundStyleScale(["Letzte Woche": Color.secondary.opacity(0.4), "Diese Woche": Color.accentColor])
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: CGFloat(rows.count / 2) * 44 + 40)
                .padding(.vertical, 4)
            }
        } header: {
            Text("Arbeitssätze pro Muskelgruppe")
        } footer: {
            Text("Aufwärmsätze zählen nicht mit.")
        }
    }

    @ViewBuilder
    private func volumeSection(now: Date) -> some View {
        let weeks = TrainingStats.weeklyVolume(sessions, weeks: 12, now: now, calendar: calendar)
        if weeks.contains(where: { $0.volume > 0 }) {
            Section("Volumen pro Woche") {
                Chart(weeks) { week in
                    BarMark(
                        x: .value("Woche", week.weekStart, unit: .weekOfYear),
                        y: .value("Volumen", week.volume)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .chartYAxisLabel("kg")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 3)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 180)
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var recordsSection: some View {
        let records = TrainingStats.recentRecords(sessions, limit: 5)
        if !records.isEmpty {
            Section("Neue Bestleistungen") {
                ForEach(records) { entry in
                    HStack {
                        Image(systemName: "trophy.fill").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.exerciseName).font(.headline)
                            Text(entry.session?.startDate.formatted(.dateTime.day().month().year()) ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("1RM ≈ \(Format.weight(WorkoutStats.bestOneRepMax(of: entry).rounded())) kg")
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var bodyWeightSection: some View {
        Section {
            if bodyWeights.isEmpty {
                Text("Noch keine Einträge.")
                    .foregroundStyle(.secondary)
            } else {
                if bodyWeights.count > 1 {
                    Chart(bodyWeights) { entry in
                        LineMark(x: .value("Datum", entry.date), y: .value("Gewicht", entry.kg))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Datum", entry.date), y: .value("Gewicht", entry.kg))
                            .symbolSize(20)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel("kg")
                    .frame(height: 160)
                    .padding(.vertical, 4)
                }
                ForEach(bodyWeights.prefix(10)) { entry in
                    HStack {
                        Text(entry.date.formatted(.dateTime.day().month().year()))
                        if entry.healthKitUUID != nil {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.pink)
                                .accessibilityLabel("Apple Health")
                        }
                        Spacer()
                        Text("\(Format.weight(entry.kg)) kg").monospacedDigit()
                    }
                }
                .onDelete { offsets in
                    let shown = Array(bodyWeights.prefix(10))
                    for index in offsets {
                        HealthSync.deleteBodyWeight(id: shown[index].healthKitUUID)
                        modelContext.delete(shown[index])
                    }
                    try? modelContext.save()
                }
            }
        } header: {
            HStack {
                Text("Körpergewicht")
                Spacer()
                Button("Eintragen", systemImage: "plus") { showAddWeight = true }
                    .labelStyle(.iconOnly)
                    .font(.body)
            }
        }
    }
}

/// Sheet for logging one body weight entry, styled like the plan entry editor.
struct BodyWeightEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var bodyWeights: [BodyWeightEntry]

    /// Weight in tenths of a kilogram, so the stepper can work on integers.
    @State private var tenths = 750
    @State private var stepTenths = 1
    @State private var date = Date.now
    @State private var didLoadLast = false

    private static let range = 200...3500
    private static let stepPresets: [(label: String, value: Int)] = [
        ("0,1 kg", 1), ("0,5 kg", 5), ("1 kg", 10),
    ]
    private static let dayPresets: [(label: String, value: Int)] = [
        ("Heute", 0), ("Gestern", 1), ("Vorgestern", 2),
    ]

    private var kg: Double { Double(tenths) / 10 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weightCard
                    dateCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Körpergewicht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                }
            }
            .onAppear {
                guard !didLoadLast else { return }
                didLoadLast = true
                if let last = bodyWeights.first {
                    tenths = min(max(Int((last.kg * 10).rounded()), Self.range.lowerBound), Self.range.upperBound)
                }
            }
        }
    }

    // MARK: - Parts

    private var weightCard: some View {
        EditorCard(title: "Gewicht", systemImage: "scalemass") {
            ValueStepper(
                label: "Gewicht",
                value: $tenths,
                range: Self.range,
                step: stepTenths,
                format: { "\((Double($0) / 10).formatted(.number.precision(.fractionLength(1)))) kg" }
            )
            PresetChips(options: Self.stepPresets, selection: stepTenths) { stepTenths = $0 }
            if let last = bodyWeights.first {
                Text(deltaText(to: last))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: tenths)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dateCard: some View {
        EditorCard(title: "Datum", systemImage: "calendar") {
            PresetChips(options: Self.dayPresets, selection: daysAgo) { days in
                date = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
            }
            DatePicker("Zeitpunkt", selection: $date, in: ...Date.now)
        }
    }

    /// Whole days between the chosen date and today; matches a day preset or none.
    private var daysAgo: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: .now)
        ).day ?? -1
    }

    private func deltaText(to last: BodyWeightEntry) -> String {
        let delta = kg - last.kg
        let lastDay = last.date.formatted(.dateTime.day().month())
        if abs(delta) < 0.05 {
            return "Gleich wie am \(lastDay) (\(Format.weight(last.kg)) kg)"
        }
        let sign = delta > 0 ? "+" : "−"
        let amount = abs(delta).formatted(.number.precision(.fractionLength(1)))
        return "\(sign)\(amount) kg seit \(lastDay)"
    }

    private func save() {
        let entry = BodyWeightEntry(date: date, kg: kg)
        modelContext.insert(entry)
        try? modelContext.save()
        let context = modelContext
        Task { await HealthSync.exportBodyWeight(entry, in: context) }
        dismiss()
    }
}

#Preview {
    StatsView()
        .modelContainer(PreviewData.container)
}

#Preview("Körpergewicht eintragen") {
    Color.clear.sheet(isPresented: .constant(true)) {
        BodyWeightEditor()
    }
    .modelContainer(PreviewData.container)
}
