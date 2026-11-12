import Foundation
import UIKit

/// Loads a studio's logo from its website: the declared apple-touch-icon
/// (or largest icon), falling back to /apple-touch-icon.png.
enum GymLogoLoader {
    enum LoadError: LocalizedError {
        case invalidWebsite, noIcon

        var errorDescription: String? {
            switch self {
            case .invalidWebsite: "Die Website-Adresse ist ungültig."
            case .noIcon: "Auf der Website wurde kein passendes Logo gefunden."
            }
        }
    }

    static let maxPixelSize: CGFloat = 256

    static func load(from website: String) async throws -> Data {
        guard let base = normalizedURL(website) else { throw LoadError.invalidWebsite }

        var candidates: [URL] = []
        if let (html, finalURL) = try? await fetchHTML(base) {
            candidates += iconURLs(inHTML: html, baseURL: finalURL)
        }
        candidates.append(base.appending(path: "apple-touch-icon.png"))

        for url in candidates {
            if let data = try? await downloadImage(url) { return data }
        }
        throw LoadError.noIcon
    }

    /// "johnreed.fitness" → https://johnreed.fitness (host only).
    static func normalizedURL(_ text: String) -> URL? {
        var string = text.trimmingCharacters(in: .whitespaces)
        guard !string.isEmpty else { return nil }
        if !string.contains("://") { string = "https://" + string }
        guard let url = URL(string: string), let host = url.host(), host.contains(".") else { return nil }
        return URL(string: "\(url.scheme ?? "https")://\(host)")
    }

    /// Icon links from a page, best first: apple-touch-icons, then other icons, larger sizes first.
    static func iconURLs(inHTML html: String, baseURL: URL) -> [URL] {
        let linkPattern = /<link\b[^>]*>/.ignoresCase()
        var found: [(url: URL, score: Int)] = []
        for match in html.matches(of: linkPattern) {
            let tag = String(match.output)
            guard let rel = attribute("rel", in: tag)?.lowercased(),
                  let href = attribute("href", in: tag),
                  let url = URL(string: href, relativeTo: baseURL)?.absoluteURL
            else { continue }
            let isApple = rel.contains("apple-touch-icon")
            guard isApple || rel.split(separator: " ").contains("icon") else { continue }
            let size = attribute("sizes", in: tag)
                .flatMap { Int($0.lowercased().split(separator: "x").first ?? "") } ?? 0
            found.append((url, (isApple ? 10_000 : 0) + size))
        }
        var seen = Set<URL>()
        return found.sorted { $0.score > $1.score }.map(\.url).filter { seen.insert($0).inserted }
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = try! Regex("\\b\(name)\\s*=\\s*[\"']([^\"']*)[\"']").ignoresCase()
        guard let match = tag.firstMatch(of: pattern), let value = match.output[1].substring else { return nil }
        return String(value)
    }

    private static func fetchHTML(_ url: URL) async throws -> (String, URL) {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw LoadError.noIcon
        }
        return (html, response.url ?? url)
    }

    /// Downloads and re-encodes as PNG (max 256 px). Rejects tiny icons.
    private static func downloadImage(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw LoadError.noIcon }
        guard let image = UIImage(data: data), image.size.width >= 48 else { throw LoadError.noIcon }
        guard let png = normalized(image) else { throw LoadError.noIcon }
        return png
    }

    /// Downscales to `maxPixelSize` and encodes as PNG (also used for picked photos).
    static func normalized(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxPixelSize / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.pngData()
    }
}
