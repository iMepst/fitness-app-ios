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

    /// Closest loadable weights around a target that can't be loaded exactly.
    /// `lower` is what the greedy loading reaches, `upper` the next exact weight above the target.
    static func nearest(target: Double, bar: Double, plates: [Double]) -> (lower: Double, upper: Double?)? {
        guard let loading = loading(target: target, bar: bar, plates: plates), loading.remainderPerSide > 0 else { return nil }
        guard let smallest = plates.filter({ $0 > 0 }).min() else { return (loading.achieved, nil) }
        let step = grams(2 * smallest)
        var candidate = grams(loading.achieved) + step
        for _ in 0..<200 {
            let weight = Double(candidate) / 1000
            if let next = self.loading(target: weight, bar: bar, plates: plates), next.remainderPerSide == 0, weight > target {
                return (loading.achieved, weight)
            }
            candidate += step
        }
        return (loading.achieved, nil)
    }

    /// Next loadable weight above (`up`) or below the target: the bar plus a multiple of
    /// two of the smallest plate. Going down never goes below the bar.
    static func step(from target: Double, bar: Double, plates: [Double], up: Bool) -> Double {
        guard let smallest = plates.filter({ $0 > 0 }).min() else { return max(bar, target) }
        let unit = grams(2 * smallest)
        let offset = grams(target) - grams(bar)
        var units = up ? offset / unit + 1 : (offset + unit - 1) / unit - 1
        if offset < 0 { units = 0 }  // below the bar: snap to the empty bar
        return Double(grams(bar) + max(0, units) * unit) / 1000
    }

    private static func grams(_ kg: Double) -> Int { Int((kg * 1000).rounded()) }
}
