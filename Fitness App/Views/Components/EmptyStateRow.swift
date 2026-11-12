import SwiftUI

/// Empty state for a list section: icon, title, one line of help and a
/// full-width prominent button. Built by hand because `ContentUnavailableView`
/// with actions collapses its button to a narrow vertical pill inside a list row.
struct EmptyStateRow: View {
    let systemImage: String
    let title: String
    let message: String
    let buttonTitle: String
    var buttonImage = "plus"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Label(buttonTitle, systemImage: buttonImage)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
