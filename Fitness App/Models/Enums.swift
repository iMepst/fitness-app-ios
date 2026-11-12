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
}
