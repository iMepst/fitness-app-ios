import Foundation
import UIKit

enum Format {
    /// "82,5" (German locale), no grouping separators.
    static func weight(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    static func volume(_ kg: Double) -> String {
        "\(kg.formatted(.number.precision(.fractionLength(0)))) kg"
    }

    static func rest(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        if minutes == 0 { return "\(rest) s" }
        if rest == 0 { return "\(minutes) min" }
        return String(format: "%d:%02d min", minutes, rest)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    static func reps(min: Int, max: Int) -> String {
        min == max ? "\(min)" : "\(min)–\(max)"
    }

    /// "8" or "8,5".
    static func rpe(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "heute", "gestern", "vor 5 Tagen", "vor 3 Wochen" – by calendar days.
    static func daysAgo(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "heute"
        case 1: return "gestern"
        case 2..<14: return "vor \(days) Tagen"
        case 14..<60: return "vor \(days / 7) Wochen"
        default: return "vor \(days / 30) Monaten"
        }
    }

    static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }
}

@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
