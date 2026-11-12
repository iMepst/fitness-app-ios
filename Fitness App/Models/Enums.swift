import Foundation

enum MuscleGroup: String, CaseIterable, Identifiable, Codable {
    case brust = "Brust"
    case ruecken = "Rücken"
    case schultern = "Schultern"
    case bizeps = "Bizeps"
    case trizeps = "Trizeps"
    case beine = "Beine"
    case gesaess = "Gesäß"
    case bauch = "Bauch"
    case ganzkoerper = "Ganzkörper"

    var id: String { rawValue }
}

enum Equipment: String, CaseIterable, Identifiable, Codable {
    case langhantel = "Langhantel"
    case kurzhantel = "Kurzhantel"
    case maschine = "Maschine"
    case kabelzug = "Kabelzug"
    case koerpergewicht = "Körpergewicht"
    case sonstiges = "Sonstiges"

    var id: String { rawValue }

    /// Smallest sensible weight jump for progression suggestions; `nil` = no suggestion.
    var progressionStep: Double? {
        switch self {
        case .langhantel, .maschine, .kabelzug, .sonstiges: 2.5
        case .kurzhantel: 2
        case .koerpergewicht: nil
        }
    }
}

enum SetKind: String, CaseIterable, Identifiable, Codable {
    case normal
    case aufwaermen
    case drop
    case versagen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: "Arbeitssatz"
        case .aufwaermen: "Aufwärmsatz"
        case .drop: "Dropsatz"
        case .versagen: "Bis zum Versagen"
        }
    }

    /// Short badge shown instead of the set number; `nil` for normal sets.
    var badge: String? {
        switch self {
        case .normal: nil
        case .aufwaermen: "W"
        case .drop: "D"
        case .versagen: "F"
        }
    }

    /// Warm-ups don't count towards volume, 1RM or records.
    var countsAsWorkingSet: Bool { self != .aufwaermen }
}
