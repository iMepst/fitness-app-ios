import SwiftUI
import SwiftData

/// Toolbar menu to switch the active gym or open gym management.
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
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                Text(gyms.active(id: activeGymID)?.name ?? "Kein Studio")
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
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
