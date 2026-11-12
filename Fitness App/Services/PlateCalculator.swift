import Foundation

struct PlateLoading: Equatable {
    /// Plates for one side of the bar, heaviest first.
    let perSide: [Double]
    /// Weight per side that could not be loaded with the available plates.
    let remainderPerSide: Double
    let achieved: Double
}

/// Greedy plate loading for a barbell (any number of each plate size).
enum PlateCalculator {
    /// Returns `nil` when the target is lighter than the bar.
    static func loading(target: Double, bar: Double, plates: [Double]) -> PlateLoading? {
        guard target >= bar else { return nil }
        // Integer grams avoid floating point drift (2.5 + 1.25 …).
        var remaining = grams((target - bar) / 2)
        var perSide: [Double] = []
        for plate in plates.filter({ $0 > 0 }).sorted(by: >) {
            let size = grams(plate)
            while remaining >= size {
                perSide.append(plate)
                remaining -= size
            }
        }
        let loaded = perSide.reduce(0, +)
        return PlateLoading(
            perSide: perSide,
            remainderPerSide: Double(remaining) / 1000,
            achieved: bar + 2 * loaded
        )
    }

    private static func grams(_ kg: Double) -> Int { Int((kg * 1000).rounded()) }
}
