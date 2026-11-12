import Foundation

struct ExerciseSection: Identifiable {
    let id: String
    let title: String
    let exercises: [Exercise]

    /// Machines of the active gym first, then universal exercises by muscle group.
    static func make(
        from exercises: [Exercise],
        activeGym: Gym?,
        search: String = "",
        muscleGroup: MuscleGroup? = nil
    ) -> [ExerciseSection] {
        let filtered = WorkoutStats.available(exercises, activeGym: activeGym)
            .filter { muscleGroup == nil || $0.muscleGroup == muscleGroup }
            .filter { search.isEmpty || $0.name.localizedStandardContains(search) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var sections: [ExerciseSection] = []
        let machines = filtered.filter { $0.gym != nil }
        if let gym = activeGym, !machines.isEmpty {
            sections.append(ExerciseSection(id: "gym", title: "Geräte – \(gym.name)", exercises: machines))
        }
        let universal = filtered.filter { $0.gym == nil }
        for group in MuscleGroup.allCases {
            let items = universal.filter { $0.muscleGroup == group }
            if !items.isEmpty {
                sections.append(ExerciseSection(id: group.rawValue, title: group.rawValue, exercises: items))
            }
        }
        return sections
    }
}
