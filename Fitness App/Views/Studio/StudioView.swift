import SwiftUI
import SwiftData
import MapKit

/// „Mein Studio": facts about the active studio.
struct StudioView: View {
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage(AppSettings.activeGymIDKey) private var activeGymID = ""

    @State private var editRequest: StudioEditRequest?

    private var gym: Gym? { gyms.active(id: activeGymID) }

    var body: some View {
        NavigationStack {
            Group {
                if let gym {
                    StudioContent(gym: gym) { destination in
                        editRequest = StudioEditRequest(gym: gym, start: destination)
                    }
                    .id(gym.id)
                } else {
                    ContentUnavailableView(
                        "Kein Studio",
                        systemImage: "building.2",
                        description: Text("Lege oben über das Studio-Menü ein Studio an.")
                    )
                }
            }
            .navigationTitle("Mein Studio")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GymMenu()
                }
                if let gym {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Bearbeiten") { editRequest = StudioEditRequest(gym: gym, start: nil) }
                    }
                }
            }
            .sheet(item: $editRequest) { request in
                StudioEditSheet(gym: request.gym, start: request.start)
            }
        }
    }
}

struct StudioEditRequest: Identifiable {
    let id = UUID()
    let gym: Gym
    let start: StudioEditDestination?
}

private struct StudioContent: View {
    @Bindable var gym: Gym
    let onEdit: (StudioEditDestination?) -> Void
    /// One place-card sheet for the whole page – several sheet modifiers in
    /// one List compete and SwiftUI then refuses to present any of them.
    @State private var placeItem: MKMapItem?

    var body: some View {
        List {
            Section {
                StudioHeader(gym: gym)
            }

            Section {
                LockerCard(gym: gym)
            } header: {
                Text("Spind heute")
            } footer: {
                Text("Wird nach 12 Stunden automatisch vergessen.")
            }

            if gym.hasLocation {
                StudioMapSection(gym: gym, onShowPlaceCard: showPlaceCard)
                TransitSection(gym: gym)
            } else {
                Section("Standort") {
                    Button("Studio auf der Karte suchen", systemImage: "magnifyingglass") { onEdit(.location) }
                }
            }

            if let hours = gym.builtInHours {
                HoursSection(title: "Öffnungszeiten", hours: hours.opening)
                if let staffed = hours.staffed {
                    HoursSection(
                        title: "Personal vor Ort",
                        hours: staffed,
                        footer: "Service und Trainer sind in dieser Zeit in der Regel erreichbar."
                    )
                }
            } else if gym.mapItemID != nil {
                AppleMapsHoursSection(onShowPlaceCard: showPlaceCard)
            }

            ContractSection(contract: gym.contract) { onEdit(.contract) }
        }
        .mapItemDetailSheet(item: $placeItem)
    }

    private func showPlaceCard() {
        Task { placeItem = await StudioPlaces.mapItem(for: gym) }
    }
}

// MARK: - Header

private struct StudioHeader: View {
    let gym: Gym

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(gym.name)
                .font(.title2.bold())
            if !gym.address.isEmpty {
                Text(gym.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let hours = gym.builtInHours {
                OpenStatusBadge(hours: hours.opening)
                if let staffed = hours.staffed {
                    StaffStatusLine(hours: staffed)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct OpenStatusBadge: View {
    let hours: WeeklyHours

    var body: some View {
        TimelineView(.everyMinute) { context in
            let (text, color) = describe(hours.status(at: context.date), now: context.date)
            if let text {
                Label(text, systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
        }
    }

    private func describe(_ status: OpenStatus, now: Date) -> (String?, Color) {
        switch status {
        case .unknown:
            return (nil, .secondary)
        case .open(nil):
            return ("Rund um die Uhr geöffnet", .green)
        case .open(let until?):
            let soon = until.timeIntervalSince(now) < 3600
            return ("Geöffnet · bis \(Self.moment(until, now: now))", soon ? .orange : .green)
        case .closed(nil):
            return ("Geschlossen", .red)
        case .closed(let opens?):
            return ("Geschlossen · öffnet \(Self.moment(opens, now: now))", .red)
        }
    }

    static func moment(_ date: Date, now: Date) -> String {
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if calendar.isDateInTomorrow(date) { return "morgen \(time)" }
        return "\(WeeklyHours.weekdayShortNames[WeeklyHours.dayIndex(of: date)]) \(time)"
    }
}

/// "Personal vor Ort · bis 22:00" / "Kein Personal vor Ort · ab 08:00".
struct StaffStatusLine: View {
    let hours: WeeklyHours

    var body: some View {
        TimelineView(.everyMinute) { context in
            switch hours.status(at: context.date) {
            case .unknown:
                EmptyView()
            case .open(nil):
                line("Personal rund um die Uhr vor Ort", active: true)
            case .open(let until?):
                line("Personal vor Ort · bis \(OpenStatusBadge.moment(until, now: context.date))", active: true)
            case .closed(let opens):
                line("Kein Personal vor Ort" + (opens.map { " · ab \(OpenStatusBadge.moment($0, now: context.date))" } ?? ""), active: false)
            }
        }
    }

    private func line(_ text: String, active: Bool) -> some View {
        Label(text, systemImage: active ? "person.fill.checkmark" : "person.slash")
            .font(.subheadline)
            .foregroundStyle(active ? Color.primary : Color.secondary)
    }
}

// MARK: - Locker

private struct LockerCard: View {
    @Bindable var gym: Gym
    @Environment(\.modelContext) private var modelContext
    @State private var input = ""
    @State private var isEditing = false
    @FocusState private var focused: Bool

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let locker = gym.currentLocker(now: context.date), !isEditing {
                HStack(alignment: .center) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locker)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        if let since = gym.lockerSetAt {
                            Text("seit \(since.formatted(date: .omitted, time: .shortened)) Uhr")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Ändern") {
                        input = locker
                        isEditing = true
                        focused = true
                    }
                    .buttonStyle(.bordered)
                    Button("Freigeben", systemImage: "lock.open") { save(nil) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Spind freigeben")
                }
            } else {
                HStack {
                    TextField("Spindnummer", text: $input)
                        .keyboardType(.numbersAndPunctuation)
                        .submitLabel(.done)
                        .focused($focused)
                        .onSubmit { save(input) }
                    Button("Merken") { save(input) }
                        .buttonStyle(.borderedProminent)
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save(_ number: String?) {
        gym.setLocker(number)
        try? modelContext.save()
        input = ""
        isEditing = false
        focused = false
    }
}

// MARK: - Map

private struct StudioMapSection: View {
    let gym: Gym
    let onShowPlaceCard: () -> Void
    @State private var stops: [TransitStop] = []

    var body: some View {
        Section {
            if let coordinate = gym.coordinate {
                // Static map: no panning/zooming, so it never fights the list's scrolling.
                Map(position: .constant(.region(region(around: coordinate))), interactionModes: []) {
                    Marker(gym.name, systemImage: "dumbbell.fill", coordinate: coordinate)
                        .tint(.red)
                    ForEach(stops) { stop in
                        Marker(stop.name, systemImage: "tram.fill", coordinate: stop.coordinate)
                            .tint(.blue)
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .including([.publicTransport])))
                .frame(height: 240)
                .listRowInsets(EdgeInsets())
                .task {
                    stops = (try? await TransitStopFinder.stops(near: coordinate)) ?? []
                }
            }

            HStack(spacing: 10) {
                Menu {
                    Button("Mit ÖPNV", systemImage: "tram.fill") { directions(MKLaunchOptionsDirectionsModeTransit) }
                    Button("Zu Fuß", systemImage: "figure.walk") { directions(MKLaunchOptionsDirectionsModeWalking) }
                    Button("Mit dem Rad", systemImage: "bicycle") { directions(MKLaunchOptionsDirectionsModeCycling) }
                    Button("Mit dem Auto", systemImage: "car.fill") { directions(MKLaunchOptionsDirectionsModeDriving) }
                } label: {
                    actionLabel("Route", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
                if let phoneURL {
                    Link(destination: phoneURL) { actionLabel("Anrufen", systemImage: "phone.fill") }
                }
                if let websiteURL {
                    Link(destination: websiteURL) { actionLabel("Website", systemImage: "safari.fill") }
                }
                Button(action: onShowPlaceCard) {
                    actionLabel("Karten", systemImage: "info.circle.fill")
                }
            }
            .buttonStyle(.borderless)
            .padding(.vertical, 4)
        }
    }

    /// Frames the studio and all stops (the map can't be panned), at least ~900 m wide.
    private func region(around center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let minSpan = 900.0 / 111_000 // ≈ 900 m in degrees latitude
        var latDelta = minSpan
        var lonDelta = minSpan / cos(center.latitude * .pi / 180)
        for stop in stops {
            // Centered on the studio, so the span must cover twice the farthest offset (+ room for pins).
            latDelta = max(latDelta, abs(stop.coordinate.latitude - center.latitude) * 2 * 1.35)
            lonDelta = max(lonDelta, abs(stop.coordinate.longitude - center.longitude) * 2 * 1.35)
        }
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }

    private var phoneURL: URL? {
        let digits = gym.phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    private var websiteURL: URL? {
        let text = gym.websiteURL.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return URL(string: text.contains("://") ? text : "https://\(text)")
    }

    private func directions(_ mode: String) {
        Task {
            guard let item = await StudioPlaces.mapItem(for: gym) else { return }
            StudioPlaces.openDirections(to: item, mode: mode)
        }
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).font(.title3)
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.tint.opacity(0.12), in: .rect(cornerRadius: 10))
    }
}

// MARK: - Transit

private struct TransitSection: View {
    let gym: Gym

    private enum LoadState { case loading, loaded([TransitStop]), failed }
    @State private var state: LoadState = .loading

    var body: some View {
        Section {
            switch state {
            case .loading:
                HStack {
                    ProgressView()
                    Text("Suche Haltestellen …").foregroundStyle(.secondary)
                }
            case .failed:
                Text("Haltestellen konnten nicht geladen werden.")
                    .foregroundStyle(.secondary)
            case .loaded(let stops) where stops.isEmpty:
                Text("Keine Haltestellen im Umkreis von 1,2 km gefunden.")
                    .foregroundStyle(.secondary)
            case .loaded(let stops):
                ForEach(stops) { stop in
                    Button {
                        stop.mapItem.openInMaps()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: stop.name))
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stop.name).foregroundStyle(.primary)
                                Text("ca. \(stop.walkMinutes) min zu Fuß · \(stop.distanceLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Link(destination: StudioPlaces.hvvPlannerURL) {
                Label("HVV-Fahrplanauskunft öffnen", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("ÖPNV in der Nähe")
        } footer: {
            Text("Gehzeit geschätzt (Luftlinie). Für Verbindungen und Echtzeit nutze „Route → Mit ÖPNV“ oder die HVV-Auskunft.")
        }
        .task(id: "\(gym.latitude ?? 0),\(gym.longitude ?? 0)") {
            guard let coordinate = gym.coordinate else { return }
            state = .loading
            do {
                state = .loaded(try await TransitStopFinder.stops(near: coordinate))
            } catch {
                state = .failed
            }
        }
    }

    private func icon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("bus") || lower.contains("zob") { return "bus.fill" }
        return "tram.fill"
    }
}

// MARK: - Opening hours

/// Read-only weekly hours; days with identical hours are grouped.
private struct HoursSection: View {
    let title: String
    let hours: WeeklyHours
    var footer: String?

    var body: some View {
        Section {
            let today = WeeklyHours.dayIndex(of: .now)
            ForEach(hours.groupedRows(), id: \.self) { row in
                let isToday = row.days.contains(today) && row.days.count < 7
                HStack(alignment: .firstTextBaseline) {
                    Text(row.label)
                    Spacer()
                    Text(row.hours.replacingOccurrences(of: ", ", with: "\n"))
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .foregroundStyle(row.hours == "geschlossen" ? .secondary : .primary)
                }
                .fontWeight(isToday ? .semibold : .regular)
                .listRowBackground(isToday ? Color.accentColor.opacity(0.1) : nil)
            }
        } header: {
            Text(title)
        } footer: {
            if let footer { Text(footer) }
        }
    }
}

/// MapKit exposes no opening-hours data, so the hours come from Apple's own
/// place card – always as current as Apple Maps itself.
private struct AppleMapsHoursSection: View {
    let onShowPlaceCard: () -> Void

    var body: some View {
        Section {
            Button(action: onShowPlaceCard) {
                Label("Öffnungszeiten in Apple Karten", systemImage: "clock")
            }
        } header: {
            Text("Öffnungszeiten")
        }
    }
}

// MARK: - Contract

private struct ContractSection: View {
    let contract: MembershipContract?
    let onEdit: () -> Void

    var body: some View {
        Section("Mitgliedschaft") {
            if let contract {
                if !contract.memberNumber.isEmpty {
                    LabeledContent("Mitgliedsnummer", value: contract.memberNumber)
                }
                if let fee = contract.monthlyFee {
                    LabeledContent("Monatsbeitrag", value: fee.formatted(.currency(code: "EUR")))
                }
                if let minEnd = contract.minimumTermEnd(), minEnd >= Calendar.current.startOfDay(for: .now) {
                    LabeledContent("Mindestlaufzeit bis", value: minEnd.formatted(date: .long, time: .omitted))
                }
                if let next = contract.nextCancellation() {
                    let daysLeft = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: next.deadline).day ?? 0
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Kündigen bis") {
                            Text(next.deadline.formatted(date: .long, time: .omitted))
                                .fontWeight(.semibold)
                                .foregroundStyle(daysLeft <= 30 ? .orange : .primary)
                        }
                        Text("Vertrag endet dann am \(next.termEnd.formatted(date: .long, time: .omitted)) · noch \(Format.count(daysLeft, "Tag", "Tage"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let reminder = ContractReminder.reminderDate(for: contract) {
                    Label("Erinnerung am \(reminder.formatted(date: .abbreviated, time: .omitted))", systemImage: "bell.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Vertrag bearbeiten", action: onEdit)
            } else {
                Button("Vertrag eintragen", systemImage: "doc.text", action: onEdit)
            }
        }
    }
}

#Preview {
    StudioView()
        .modelContainer(PreviewData.container)
}
