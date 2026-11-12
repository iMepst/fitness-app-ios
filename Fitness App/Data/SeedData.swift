import Foundation
import SwiftData

enum SeedData {
    static let defaultGymName = "John Reed Wandsbek"

    /// Universal exercises (free weights, cables, bodyweight) – available in every gym.
    static let universalExercises: [(name: String, muscle: MuscleGroup, equipment: Equipment)] = [
        // Brust
        ("Bankdrücken", .brust, .langhantel),
        ("Schrägbankdrücken", .brust, .langhantel),
        ("Kurzhantel-Bankdrücken", .brust, .kurzhantel),
        ("Schrägbankdrücken mit Kurzhanteln", .brust, .kurzhantel),
        ("Fliegende mit Kurzhanteln", .brust, .kurzhantel),
        ("Cable Crossover", .brust, .kabelzug),
        ("Dips", .brust, .koerpergewicht),
        ("Liegestütze", .brust, .koerpergewicht),
        // Rücken
        ("Kreuzheben", .ruecken, .langhantel),
        ("Langhantelrudern", .ruecken, .langhantel),
        ("Einarmiges Kurzhantelrudern", .ruecken, .kurzhantel),
        ("Klimmzüge", .ruecken, .koerpergewicht),
        ("Latzug", .ruecken, .kabelzug),
        ("Rudern am Kabel sitzend", .ruecken, .kabelzug),
        ("Face Pulls", .ruecken, .kabelzug),
        ("Hyperextensions", .ruecken, .koerpergewicht),
        // Schultern
        ("Schulterdrücken stehend", .schultern, .langhantel),
        ("Kurzhantel-Schulterdrücken", .schultern, .kurzhantel),
        ("Seitheben", .schultern, .kurzhantel),
        ("Seitheben am Kabel", .schultern, .kabelzug),
        ("Reverse Flys", .schultern, .kurzhantel),
        // Bizeps
        ("Langhantelcurls", .bizeps, .langhantel),
        ("Kurzhantelcurls", .bizeps, .kurzhantel),
        ("Hammercurls", .bizeps, .kurzhantel),
        ("Bizepscurls am Kabel", .bizeps, .kabelzug),
        // Trizeps
        ("Trizepsdrücken am Kabel", .trizeps, .kabelzug),
        ("Überkopf-Trizepsstrecken am Kabel", .trizeps, .kabelzug),
        ("Stirndrücken (SZ-Stange)", .trizeps, .langhantel),
        ("Enges Bankdrücken", .trizeps, .langhantel),
        // Beine
        ("Kniebeuge", .beine, .langhantel),
        ("Frontkniebeuge", .beine, .langhantel),
        ("Rumänisches Kreuzheben", .beine, .langhantel),
        ("Ausfallschritte", .beine, .kurzhantel),
        ("Bulgarian Split Squats", .beine, .kurzhantel),
        ("Goblet Squat", .beine, .kurzhantel),
        ("Wadenheben stehend", .beine, .koerpergewicht),
        // Gesäß
        ("Hip Thrust", .gesaess, .langhantel),
        ("Glute Bridge", .gesaess, .koerpergewicht),
        ("Kickbacks am Kabel", .gesaess, .kabelzug),
        // Bauch
        ("Plank", .bauch, .koerpergewicht),
        ("Crunches", .bauch, .koerpergewicht),
        ("Hängendes Beinheben", .bauch, .koerpergewicht),
        ("Cable Crunch", .bauch, .kabelzug),
        ("Russian Twist", .bauch, .koerpergewicht),
    ]

    /// Machines per gym name. Empty until a real machine list exists –
    /// machines can always be added in the app.
    static let gymMachines: [String: [(name: String, muscle: MuscleGroup)]] = [:]

    /// Inserts the starter library and the default gym on first launch.
    /// Returns the gym if one was created.
    @discardableResult
    static func seedIfNeeded(context: ModelContext) -> Gym? {
        let exerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        if exerciseCount == 0 {
            for item in universalExercises {
                context.insert(Exercise(name: item.name, muscleGroup: item.muscle, equipment: item.equipment, isBuiltIn: true))
            }
        }

        var createdGym: Gym?
        let gymCount = (try? context.fetchCount(FetchDescriptor<Gym>())) ?? 0
        if gymCount == 0 {
            let gym = Gym(name: defaultGymName)
            context.insert(gym)
            for machine in gymMachines[defaultGymName] ?? [] {
                let exercise = Exercise(name: machine.name, muscleGroup: machine.muscle, equipment: .maschine, isBuiltIn: true)
                context.insert(exercise)
                exercise.gym = gym
            }
            createdGym = gym
        }

        try? context.save()
        return createdGym
    }

}
