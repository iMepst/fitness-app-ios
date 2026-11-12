import SwiftUI
import UIKit

/// Built-in look for studio chains, used until the user sets their own logo.
/// Add more chains here; matching is by name prefix (case-insensitive).
struct GymBrand: Equatable {
    let monogram: String
    let backgroundHex: String
    /// Where "Logo von Website laden" looks when the studio has no website set.
    let website: String

    private static let known: [(prefix: String, brand: GymBrand)] = [
        ("john reed", GymBrand(monogram: "JR", backgroundHex: "#000000", website: "https://johnreed.fitness")),
    ]

    static func preset(for gymName: String) -> GymBrand? {
        let name = gymName.trimmingCharacters(in: .whitespaces).lowercased()
        return known.first { name.hasPrefix($0.prefix) }?.brand
    }
}

/// What the studio badge shows, in order of preference.
enum GymLogo: Equatable {
    case image(Data)
    case monogram(String, backgroundHex: String)
    case pin
}

extension Gym {
    var logo: GymLogo {
        if let logoData, !logoData.isEmpty { return .image(logoData) }
        let text = monogram.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty { return .monogram(text, backgroundHex: monogramColorHex) }
        if let brand = GymBrand.preset(for: name) {
            return .monogram(brand.monogram, backgroundHex: brand.backgroundHex)
        }
        return .pin
    }

    /// The studio's own website, else the chain's.
    var logoWebsite: String? {
        let own = websiteURL.trimmingCharacters(in: .whitespaces)
        if !own.isEmpty { return own }
        return GymBrand.preset(for: name)?.website
    }

    static let monogramMaxLength = 3

    static func cleanMonogram(_ text: String) -> String {
        String(text.filter { !$0.isWhitespace }.prefix(monogramMaxLength)).uppercased()
    }
}

// MARK: - Colour helpers

extension Color {
    /// "#RRGGBB" → Color; nil for anything else.
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    /// Black or white, whichever reads better on this colour.
    var contrastingText: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? .black : .white
    }
}
