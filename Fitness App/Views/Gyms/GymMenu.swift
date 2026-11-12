import SwiftUI
import SwiftData

/// Toolbar menu to switch the active gym or open gym management.
/// Pair it with `.activeGymSubtitle()` on the same screen.
struct GymMenu: View {
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""
    @State private var showManager = false

    var body: some View {
        Menu {
            Picker("Studio", selection: selection) {
                ForEach(gyms) { gym in
                    Text(gym.name).tag(gym.id.uuidString)
                }
            }
            Divider()
            Button("Studios verwalten …", systemImage: "gearshape") {
                showManager = true
            }
        } label: {
            // Icon only: the gym's name is shown as the navigation subtitle
            // (`activeGymSubtitle()`), so the collapsed title keeps its room.
            Image(systemName: "mappin.and.ellipse")
                .accessibilityLabel("Studio: \(gyms.active(id: activeGymID)?.name ?? "Kein Studio")")
        }
        .sheet(isPresented: $showManager) {
            NavigationStack {
                GymListView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { showManager = false }
                        }
                    }
            }
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: { gyms.active(id: activeGymID)?.id.uuidString ?? "" },
            set: { activeGymID = $0 }
        )
    }
}

/// Shows the active gym's name as the navigation subtitle (under the large title).
private struct ActiveGymSubtitle: ViewModifier {
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    func body(content: Content) -> some View {
        content.navigationSubtitle(gyms.active(id: activeGymID)?.name ?? "Kein Studio")
    }
}

extension View {
    func activeGymSubtitle() -> some View {
        modifier(ActiveGymSubtitle())
    }
}
