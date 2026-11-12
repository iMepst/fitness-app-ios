import Testing
import Foundation
@testable import Fitness_App

struct GymLogoTests {
    @Test func johnReedGetsBuiltInMonogram() {
        #expect(GymBrand.preset(for: "John Reed Wandsbek")?.monogram == "JR")
        #expect(GymBrand.preset(for: "  john reed Altona")?.monogram == "JR")
        #expect(GymBrand.preset(for: "McFit Barmbek") == nil)
    }

    @Test func logoPrefersImageThenMonogramThenBrandThenPin() {
        let gym = Gym(name: "Studio X")
        #expect(gym.logo == .pin)

        gym.name = "John Reed Wandsbek"
        #expect(gym.logo == .monogram("JR", backgroundHex: "#000000"))

        gym.monogram = "JRW"
        gym.monogramColorHex = "#FF0000"
        #expect(gym.logo == .monogram("JRW", backgroundHex: "#FF0000"))

        gym.logoData = Data([1, 2, 3])
        #expect(gym.logo == .image(Data([1, 2, 3])))
    }

    @Test func logoWebsiteFallsBackToChain() {
        let gym = Gym(name: "John Reed Wandsbek")
        #expect(gym.logoWebsite == "https://johnreed.fitness")
        gym.websiteURL = "example.com"
        #expect(gym.logoWebsite == "example.com")
        #expect(Gym(name: "Studio X").logoWebsite == nil)
    }

    @Test func monogramIsShortAndUppercased() {
        #expect(Gym.cleanMonogram("j r wandsbek") == "JRW")
        #expect(Gym.cleanMonogram("jr") == "JR")
    }

    @Test func normalizedURLKeepsOnlyHost() {
        #expect(GymLogoLoader.normalizedURL("johnreed.fitness/studios")?.absoluteString == "https://johnreed.fitness")
        #expect(GymLogoLoader.normalizedURL("http://example.com/a")?.absoluteString == "http://example.com")
        #expect(GymLogoLoader.normalizedURL("kein link") == nil)
        #expect(GymLogoLoader.normalizedURL("") == nil)
    }

    @Test func iconURLsPreferAppleTouchIconAndLargerSizes() {
        let html = """
        <head>
        <link rel="icon" type="image/png" sizes="16x16" href="/favicon/favicon-16x16.ico"/>
        <link rel="apple-touch-icon" sizes="180x180" href="/favicon/favicon-180x180.ico"/>
        <link rel="icon" type="image/png" sizes="32x32" href="/favicon/favicon-32x32.ico"/>
        <link rel="stylesheet" href="/style.css"/>
        <link rel="shortcut icon" href="/favicon/favicon-32x32.ico"/>
        <link rel="mask-icon" href="/favicon/safari-pinned-tab.svg" color="#000000"/>
        </head>
        """
        let urls = GymLogoLoader.iconURLs(inHTML: html, baseURL: URL(string: "https://johnreed.fitness")!)
        #expect(urls.map(\.absoluteString) == [
            "https://johnreed.fitness/favicon/favicon-180x180.ico",
            "https://johnreed.fitness/favicon/favicon-32x32.ico",
            "https://johnreed.fitness/favicon/favicon-16x16.ico",
        ])
    }
}
