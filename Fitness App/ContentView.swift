//
//  ContentView.swift
//  Fitness App
//
//  Created by Markus Epstein on 12.11.26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate == nil }, sort: \WorkoutSession.startDate, order: .reverse)
    private var runningSessions: [WorkoutSession]
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    @State private var presentedSession: WorkoutSession?
    @State private var didRestore = false

    var body: some View {
        TabView {
            Tab("Training", systemImage: "dumbbell.fill") {
                PlanListView(
                    runningSession: runningSessions.first,
                    onStart: start,
                    onResume: { presentedSession = $0 }
                )
            }
            Tab("Verlauf", systemImage: "clock.arrow.circlepath") {
                HistoryListView()
            }
            Tab("Statistik", systemImage: "chart.bar.xaxis") {
                StatsView()
            }
            Tab("Übungen", systemImage: "list.bullet.rectangle.portrait") {
                ExerciseListView()
            }
            Tab("Studio", systemImage: "building.2") {
                StudioView()
            }
        }
        .fullScreenCover(item: $presentedSession) { session in
            ActiveWorkoutView(session: session)
        }
        .task {
            // Reopen a workout that was still running when the app was closed.
            guard !didRestore else { return }
            didRestore = true
            presentedSession = runningSessions.first
        }
    }

    private func start(_ plan: WorkoutPlan?) {
        if let running = runningSessions.first {
            presentedSession = running
            return
        }
        presentedSession = WorkoutFactory.startSession(plan: plan, gym: gyms.active(id: activeGymID), in: modelContext)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
