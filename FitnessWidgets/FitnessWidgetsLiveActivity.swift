import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

/// Lock screen + Dynamic Island for a running workout: elapsed time, or the rest countdown with buttons.
struct FitnessWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
                .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            let state = context.state
            let resting = state.isResting && !context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(resting ? "Pause" : "Training")
                    } icon: {
                        Image(systemName: resting ? "timer" : "dumbbell.fill")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MainTimer(state: state, isStale: context.isStale)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(subtitle(state, isStale: context.isStale))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if resting {
                            RestButtons()
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: resting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                MainTimer(state: state, isStale: context.isStale)
                    .frame(maxWidth: 52)
                    .foregroundStyle(.orange)
            } minimal: {
                Image(systemName: resting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let state = context.state
        let resting = state.isResting && !context.isStale
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(context.attributes.workoutTitle, systemImage: "dumbbell.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text(subtitle(state, isStale: context.isStale))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let locker = state.locker {
                        Label("Spind \(locker)", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(resting ? "Pause" : "Dauer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MainTimer(state: state, isStale: context.isStale)
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.trailing)
                }
            }

            if resting, let start = state.restStart, let end = state.restEnd {
                ProgressView(timerInterval: start...end, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(.orange)
                RestButtons()
            }
        }
    }
}

/// Rest countdown while resting, otherwise the elapsed workout time.
private struct MainTimer: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if state.isResting && !isStale, let start = state.restStart, let end = state.restEnd {
            Text(timerInterval: start...end, countsDown: true)
                .monospacedDigit()
        } else {
            // Counts up "12:34" (style: .timer renders as "1 Minute" on the lock screen).
            Text(timerInterval: state.workoutStart...Date.distantFuture, countsDown: false)
                .monospacedDigit()
        }
    }
}

private struct RestButtons: View {
    var body: some View {
        HStack(spacing: 8) {
            Button(intent: AdjustRestIntent(seconds: -15)) {
                Text("−15 s").frame(maxWidth: .infinity)
            }
            Button(intent: AdjustRestIntent(seconds: 15)) {
                Text("+15 s").frame(maxWidth: .infinity)
            }
            Button(intent: SkipRestIntent()) {
                Label("Weiter", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .font(.subheadline.weight(.semibold))
    }
}

private func subtitle(_ state: WorkoutActivityAttributes.ContentState, isStale: Bool) -> String {
    let sets = "\(state.completedSets) \(state.completedSets == 1 ? "Satz" : "Sätze")"
    if isStale, state.restEnd != nil {
        return "Pause vorbei – weiter mit \(state.currentExercise)"
    }
    return state.currentExercise.isEmpty ? sets : "\(state.currentExercise) · \(sets)"
}

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(sessionID: "preview", workoutTitle: "Push", gymName: "John Reed")
    }
}

extension WorkoutActivityAttributes.ContentState {
    fileprivate static var resting: Self {
        .init(workoutStart: .now.addingTimeInterval(-1500), restStart: .now, restEnd: .now.addingTimeInterval(90),
              currentExercise: "Bankdrücken", completedSets: 7, locker: "112")
    }

    fileprivate static var working: Self {
        .init(workoutStart: .now.addingTimeInterval(-1500), restStart: nil, restEnd: nil,
              currentExercise: "Seitheben", completedSets: 8, locker: nil)
    }
}

#Preview("Notification", as: .content, using: WorkoutActivityAttributes.preview) {
    FitnessWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.resting
    WorkoutActivityAttributes.ContentState.working
}
