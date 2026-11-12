import ActivityKit
import Foundation

/// Owns the Live Activity of the running workout. The workout screen pushes session changes,
/// the rest timer pushes rest changes; both end up in one `ContentState`.
@MainActor
final class WorkoutActivityController {
    static let shared = WorkoutActivityController()

    private var activity: Activity<WorkoutActivityAttributes>?
    private var state: WorkoutActivityAttributes.ContentState?

    /// Starts (or re-attaches to) the activity for this session.
    func start(for session: WorkoutSession) {
        let sessionID = String(Int(session.startDate.timeIntervalSince1970 * 1000))
        let newState = Self.state(for: session, rest: RestTimer.shared)

        if let existing = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.attributes.sessionID == sessionID }) {
            activity = existing
            push(newState)
            return
        }
        endAll()  // leftovers from a workout that ended while the app was killed

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WorkoutActivityAttributes(
            sessionID: sessionID,
            workoutTitle: session.displayTitle,
            gymName: session.gymName
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: newState, staleDate: nil),
            pushType: nil
        )
        state = newState
    }

    /// Exercise/set/locker changes from the workout screen.
    func update(for session: WorkoutSession) {
        guard activity != nil else { return }
        push(Self.state(for: session, rest: RestTimer.shared))
    }

    /// Rest timer started, adjusted, skipped or finished.
    func restChanged(start: Date?, end: Date?) {
        guard var newState = state else { return }
        newState.restStart = start
        newState.restEnd = end
        push(newState)
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        state = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func endAll() {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
    }

    private func push(_ newState: WorkoutActivityAttributes.ContentState) {
        guard let activity, newState != state else { return }
        state = newState
        // Stale once the rest is over, so the lock screen can say "Pause vorbei" while suspended.
        let content = ActivityContent(state: newState, staleDate: newState.isResting ? newState.restEnd : nil)
        Task { await activity.update(content) }
    }

    static func state(for session: WorkoutSession, rest: RestTimer) -> WorkoutActivityAttributes.ContentState {
        let entries = session.sortedExercises
        let current = entries.first { $0.sets.contains { !$0.isCompleted } } ?? entries.last
        return WorkoutActivityAttributes.ContentState(
            workoutStart: session.startDate,
            restStart: rest.startDate,
            restEnd: rest.endDate,
            currentExercise: current?.exerciseName ?? "",
            completedSets: session.completedSets.count,
            locker: session.gym?.currentLocker()
        )
    }
}
