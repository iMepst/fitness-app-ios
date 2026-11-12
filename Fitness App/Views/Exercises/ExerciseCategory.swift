import SwiftUI

/// A browsable bucket on the Übungen overview: one muscle group, or the
/// machines of the active studio.
enum ExerciseCategory: Hashable, Identifiable {
    case gymMachines
    case muscle(MuscleGroup)

    var id: String {
        switch self {
        case .gymMachines: "gym"
        case .muscle(let group): group.rawValue
        }
    }

    var title: String {
        switch self {
        case .gymMachines: "Geräte"
        case .muscle(let group): group.rawValue
        }
    }

    var symbol: String {
        switch self {
        case .gymMachines: "building.2.fill"
        case .muscle(let group): group.symbol
        }
    }

    var tint: Color {
        switch self {
        case .gymMachines: .gray
        case .muscle(let group): group.tint
        }
    }

    /// Exercises of this category that are usable in the active studio.
    func exercises(in all: [Exercise], activeGym: Gym?) -> [Exercise] {
        WorkoutStats.available(all, activeGym: activeGym)
            .filter { exercise in
                switch self {
                case .gymMachines: exercise.gym != nil
                case .muscle(let group): exercise.gym == nil && exercise.muscleGroup == group
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

extension MuscleGroup {
    var symbol: String {
        switch self {
        case .brust: "figure.strengthtraining.traditional"
        case .ruecken: "figure.rower"
        case .schultern: "figure.arms.open"
        case .bizeps: "dumbbell.fill"
        case .trizeps: "figure.strengthtraining.functional"
        case .beine: "figure.step.training"
        case .gesaess: "figure.cross.training"
        case .bauch: "figure.core.training"
        case .ganzkoerper: "figure.mixed.cardio"
        }
    }

    var tint: Color {
        switch self {
        case .brust: .red
        case .ruecken: .blue
        case .schultern: .orange
        case .bizeps: .purple
        case .trizeps: .indigo
        case .beine: .green
        case .gesaess: .pink
        case .bauch: .teal
        case .ganzkoerper: .brown
        }
    }
}

/// Shortcuts-style tile: symbol top left, title and count bottom left.
struct ExerciseCategoryTile: View {
    let category: ExerciseCategory
    let count: Int
    var subtitle: String?

    private var countText: String {
        count == 1 ? "1 Übung" : "\(count) Übungen"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: category.symbol)
                .font(.title2.weight(.semibold))
                .frame(height: 30, alignment: .leading)

            Spacer(minLength: 16)

            Text(category.title)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle.map { "\($0) · \(countText)" } ?? countText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background(category.tint.gradient, in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}
