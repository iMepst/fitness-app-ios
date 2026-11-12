import ActivityKit
import Foundation

/// Shared between the app (starts/updates the activity) and the widget extension (renders it).
nonisolated struct WorkoutActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var workoutStart: Date
        var restStart: Date?
        var restEnd: Date?
        /// Exercise with the next open set, or the last one when everything is done.
        var currentExercise: String
        var completedSets: Int
        var locker: String?

        var isResting: Bool {
            guard let restStart, let restEnd else { return false }
            return restStart < restEnd && restEnd > .now
        }
    }

    /// Identifies the workout so a restored app can reuse its running activity.
    var sessionID: String
    var workoutTitle: String
    var gymName: String
}
