import Foundation
import SwiftData

/// In-memory sample data for SwiftUI previews.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let schema = Schema(AppSchema.models)
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let gym = SeedData.seedIfNeeded(context: context)

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        func exercise(_ name: String) -> Exercise? { exercises.first { $0.name == name } }

        let machine = Exercise(name: "Brustpresse", muscleGroup: .brust, equipment: .maschine, notes: "Sitz 4")
        context.insert(machine)
        machine.gym = gym

        let plan = WorkoutPlan(name: "Push", sortIndex: 0)
        context.insert(plan)
        for (index, item) in [exercise("Bankdrücken"), machine, exercise("Seitheben")].compactMap({ $0 }).enumerated() {
            let entry = PlanEntry(sortIndex: index)
            context.insert(entry)
            entry.exercise = item
            plan.entries.append(entry)
        }

        for weeksAgo in [3, 2, 1] {
            let session = WorkoutFactory.startSession(plan: plan, gym: gym, in: context)
            session.startDate = Calendar.current.date(byAdding: .day, value: -7 * weeksAgo, to: .now)!
            for entry in session.exercises {
                for set in entry.sets {
                    set.weight = entry.exerciseName == "Bankdrücken" ? Double(80 - weeksAgo * 2) : 12.5
                    set.isCompleted = true
                }
            }
            WorkoutFactory.finish(session, in: context)
            session.endDate = session.startDate.addingTimeInterval(55 * 60)
        }
        return container
    }()
}
