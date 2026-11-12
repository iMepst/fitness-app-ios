import Foundation
import MapKit
import CoreLocation

/// A public transport stop near a studio.
struct TransitStop: Identifiable, Hashable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let mapItem: MKMapItem

    /// Rough walking time at ~80 m/min.
    var walkMinutes: Int { max(1, Int((distance / 80).rounded(.up))) }

    var distanceLabel: String {
        distance < 1000
            ? "\(Int((distance / 10).rounded()) * 10) m"
            : (distance / 1000).formatted(.number.precision(.fractionLength(1))) + " km"
    }

    static func == (lhs: TransitStop, rhs: TransitStop) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Finds public transport stops (U-/S-Bahn, bus) around a coordinate via MapKit.
enum TransitStopFinder {
    private static var cache: [String: [TransitStop]] = [:]

    static func stops(near coordinate: CLLocationCoordinate2D, radius: CLLocationDistance = 1200, limit: Int = 6) async throws -> [TransitStop] {
        let key = String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
        if let cached = cache[key] { return cached }

        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: radius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])
        let response = try await MKLocalSearch(request: request).start()

        let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var nearestByName: [String: TransitStop] = [:]
        for item in response.mapItems {
            guard let name = item.name, !name.isEmpty else { continue }
            // MapKit's .publicTransport category also contains taxi companies/stands.
            if name.localizedCaseInsensitiveContains("taxi") { continue }
            let location = item.location
            let stop = TransitStop(
                id: item.identifier?.rawValue ?? "\(name)-\(location.coordinate.latitude)-\(location.coordinate.longitude)",
                name: name,
                coordinate: location.coordinate,
                distance: location.distance(from: center),
                mapItem: item
            )
            // MapKit often lists one station several times (U-Bahn, bus, …) – keep the nearest.
            if let existing = nearestByName[name], existing.distance <= stop.distance { continue }
            nearestByName[name] = stop
        }

        let result = Array(nearestByName.values.sorted { $0.distance < $1.distance }.prefix(limit))
        cache[key] = result
        return result
    }
}

/// Apple Maps search for a studio and helpers to open places in Maps.
enum StudioPlaces {
    /// Rough Hamburg region used to bias searches when the studio has no location yet.
    static let hamburg = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 53.5511, longitude: 9.9937),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.7)
    )

    /// HVV journey planner (Geofox). It has no documented way to prefill a destination.
    static let hvvPlannerURL = URL(string: "https://geofox.hvv.de/web/de/connections?clear=true&language=de")!

    static func search(_ query: String, near coordinate: CLLocationCoordinate2D?) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        request.region = coordinate.map {
            MKCoordinateRegion(center: $0, span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.7))
        } ?? hamburg
        return try await MKLocalSearch(request: request).start().mapItems
    }

    static func addressLine(of item: MKMapItem) -> String {
        let full = item.address?.fullAddress ?? item.address?.shortAddress ?? ""
        return full
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Copies location, phone and website of the picked place into the gym.
    static func apply(_ item: MKMapItem, to gym: Gym) {
        let coordinate = item.location.coordinate
        gym.latitude = coordinate.latitude
        gym.longitude = coordinate.longitude
        gym.address = addressLine(of: item)
        gym.mapItemID = item.identifier?.rawValue
        if let phone = item.phoneNumber, !phone.isEmpty { gym.phone = phone }
        if let url = item.url { gym.websiteURL = url.absoluteString }
    }

    static func clearLocation(of gym: Gym) {
        gym.latitude = nil
        gym.longitude = nil
        gym.address = ""
        gym.mapItemID = nil
    }

    /// The Apple Maps place of the gym (falls back to a plain pin).
    static func mapItem(for gym: Gym) async -> MKMapItem? {
        if let raw = gym.mapItemID, let identifier = MKMapItem.Identifier(rawValue: raw),
           let item = try? await MKMapItemRequest(mapItemIdentifier: identifier).mapItem {
            return item
        }
        return pin(for: gym)
    }

    static func pin(for gym: Gym) -> MKMapItem? {
        guard let coordinate = gym.coordinate else { return nil }
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        item.name = gym.name
        return item
    }

    static func openDirections(to item: MKMapItem, mode: String) {
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode])
    }
}
