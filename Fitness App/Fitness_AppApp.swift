//
//  Fitness_AppApp.swift
//  Fitness App
//
//  Created by Markus Epstein on 12.11.26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct Fitness_AppApp: App {
    let modelContainer: ModelContainer

    init() {
        #if DEBUG
        // `-demoData` runs the app on the in-memory preview data (never touches the real store).
        if ProcessInfo.processInfo.arguments.contains("-demoData") {
            modelContainer = PreviewData.container
            return
        }
        #endif
        do {
            let schema = Schema(AppSchema.models)
            // Own store name so the old template store (Item) is never migrated.
            let configuration = ModelConfiguration("FitnessApp", schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        if let gym = SeedData.seedIfNeeded(context: modelContainer.mainContext),
           (UserDefaults.standard.string(forKey: AppSettings.activeGymIDKey) ?? "").isEmpty {
            UserDefaults.standard.set(gym.id.uuidString, forKey: AppSettings.activeGymIDKey)
        }

        // A plan left as a draft (app quit while "Neuer Plan" was open) was never saved – remove it.
        let context = modelContainer.mainContext
        if let drafts = try? context.fetch(FetchDescriptor<WorkoutPlan>(predicate: #Predicate { $0.isDraft })),
           !drafts.isEmpty {
            drafts.forEach(context.delete)
            try? context.save()
        }

        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Cancellation deadlines roll forward each period – keep reminders current.
        if let gyms = try? modelContainer.mainContext.fetch(FetchDescriptor<Gym>()) {
            ContractReminder.rescheduleAll(gyms)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
