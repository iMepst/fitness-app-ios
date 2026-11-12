import SwiftUI

/// One small icon + text pair under an exercise name ("3 Sätze", "1:30 Pause", …).
struct ExerciseDetail: Hashable {
    let systemImage: String
    let text: String
}

/// The app's standard exercise row: muscle icon, name (+ gym badge), a line of
/// details and optional superset/status tags. Used by the plan editor, the
/// running workout and the workout summary so they look alike.
struct ExerciseRow<Trailing: View>: View {
    let icon: MuscleIcon
    let name: String
    var gymName: String?
    /// Secondary line between name and details (e.g. a plan's muscle groups).
    var subtitle: String?
    var details: [ExerciseDetail] = []
    var supersetLabel: String?
    /// Small accent capsule next to the name, e.g. "Jetzt".
    var tag: String?
    /// Shows a green check on the icon.
    var isDone = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            icon
                .overlay(alignment: .bottomTrailing) {
                    if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                            .background(Circle().fill(Color(.secondarySystemGroupedBackground)).padding(-2))
                            .offset(x: 5, y: 5)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if let gymName {
                        Text(gymName)
                            .font(.caption2)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                    }
                    if let tag {
                        Text(tag)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !details.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(details, id: \.self) { detail in
                            HStack(spacing: 3) {
                                Image(systemName: detail.systemImage)
                                Text(detail.text)
                            }
                            .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                if let supersetLabel {
                    SupersetTag(label: supersetLabel)
                }
            }

            Spacer(minLength: 0)

            trailing
        }
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            if let supersetLabel {
                Capsule()
                    .fill(SupersetTag.color(for: supersetLabel))
                    .frame(width: 4)
                    .offset(x: -12)
            }
        }
        .contentShape(.rect)
    }
}

extension ExerciseRow {
    /// Row with the muscle group's icon.
    init(
        muscleGroup: MuscleGroup?,
        name: String,
        gymName: String? = nil,
        subtitle: String? = nil,
        details: [ExerciseDetail] = [],
        supersetLabel: String? = nil,
        tag: String? = nil,
        isDone: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            icon: MuscleIcon(group: muscleGroup), name: name, gymName: gymName, subtitle: subtitle,
            details: details, supersetLabel: supersetLabel, tag: tag, isDone: isDone, trailing: trailing
        )
    }
}

extension ExerciseRow where Trailing == EmptyView {
    init(
        muscleGroup: MuscleGroup?,
        name: String,
        gymName: String? = nil,
        subtitle: String? = nil,
        details: [ExerciseDetail] = [],
        supersetLabel: String? = nil,
        tag: String? = nil,
        isDone: Bool = false
    ) {
        self.init(
            muscleGroup: muscleGroup, name: name, gymName: gymName, subtitle: subtitle, details: details,
            supersetLabel: supersetLabel, tag: tag, isDone: isDone
        ) { EmptyView() }
    }
}

/// Trailing disclosure chevron used by tappable exercise rows.
struct RowChevron: View {
    var isExpanded = false

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
    }
}
