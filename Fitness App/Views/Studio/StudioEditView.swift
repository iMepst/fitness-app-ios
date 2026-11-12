import SwiftUI
import SwiftData
import MapKit

enum StudioEditDestination: Hashable {
    case location, contract
}

/// Sheet wrapper; can open directly on one of the sub-editors.
struct StudioEditSheet: View {
    let gym: Gym
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var path: [StudioEditDestination]

    init(gym: Gym, start: StudioEditDestination?) {
        self.gym = gym
        _path = State(initialValue: start.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            StudioEditForm(gym: gym)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
        }
    }
}

/// Studio info form (location, contact, hours, contract). Usable in any NavigationStack.
struct StudioEditForm: View {
    @Bindable var gym: Gym

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $gym.name)
            }

            Section("Standort") {
                if gym.hasLocation {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gym.address.isEmpty ? "Ort gesetzt" : gym.address)
                    }
                    NavigationLink("Anderen Ort suchen", value: StudioEditDestination.location)
                    Button("Standort entfernen", role: .destructive) { StudioPlaces.clearLocation(of: gym) }
                } else {
                    NavigationLink(value: StudioEditDestination.location) {
                        Label("Auf der Karte suchen", systemImage: "magnifyingglass")
                    }
                }
            }

            Section("Kontakt") {
                TextField("Telefon", text: $gym.phone)
                    .keyboardType(.phonePad)
                TextField("Website", text: $gym.websiteURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                NavigationLink(value: StudioEditDestination.contract) {
                    LabeledContent("Mitgliedschaft", value: gym.contract == nil ? "nicht eingetragen" : "eingetragen")
                }
            }
        }
        .navigationTitle("Studio-Infos")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: StudioEditDestination.self) { destination in
            switch destination {
            case .location: StudioLocationSearchView(gym: gym)
            case .contract: ContractEditorView(gym: gym)
            }
        }
    }
}

// MARK: - Location search

struct StudioLocationSearchView: View {
    let gym: Gym
    @Environment(\.dismiss) private var dismiss

    @State private var query: String
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var failed = false

    init(gym: Gym) {
        self.gym = gym
        _query = State(initialValue: gym.name)
    }

    var body: some View {
        List {
            if failed {
                Text("Suche fehlgeschlagen. Bist du online?")
                    .foregroundStyle(.secondary)
            } else if results.isEmpty && !isSearching && !query.isEmpty {
                Text("Keine Treffer.")
                    .foregroundStyle(.secondary)
            }
            ForEach(results, id: \.self) { item in
                Button {
                    StudioPlaces.apply(item, to: gym)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Ort").foregroundStyle(.primary)
                        Text(StudioPlaces.addressLine(of: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if isSearching && results.isEmpty { ProgressView() }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Studio oder Adresse")
        .navigationTitle("Standort suchen")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: query) {
            let text = query.trimmingCharacters(in: .whitespaces)
            guard text.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            do {
                results = try await StudioPlaces.search(text, near: gym.coordinate)
                failed = false
            } catch {
                if !Task.isCancelled {
                    results = []
                    // MKError.placemarkNotFound just means "no results".
                    failed = (error as? MKError)?.code != .placemarkNotFound
                }
            }
        }
    }
}
