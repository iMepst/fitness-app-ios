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

    static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }
}

@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
