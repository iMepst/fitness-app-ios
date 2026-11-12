import AppIntents
import Foundation

// Buttons in the Live Activity. `LiveActivityIntent`s run in the app's process, so the
// widget extension only needs the type – the actual work is compiled into the app only.

nonisolated struct AdjustRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause anpassen"
    static let isDiscoverable = false

    @Parameter(title: "Sekunden")
    var seconds: Int

    init() {}

    init(seconds: Int) {
        self.seconds = seconds
    }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let seconds = seconds
        await MainActor.run { RestTimer.shared.adjust(by: seconds) }
        #endif
        return .result()
    }
}

nonisolated struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause überspringen"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await MainActor.run { RestTimer.shared.stop() }
        #endif
        return .result()
    }
}
