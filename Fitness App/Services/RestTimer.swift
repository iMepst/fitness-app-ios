import Foundation
import Observation
import UserNotifications

/// Rest countdown between sets. Also schedules a local notification so the
/// end of the rest is signalled while the phone is locked.
@Observable
final class RestTimer {
    /// One timer for the whole app so Live Activity buttons (App Intents) can reach it.
    static let shared = RestTimer()

    private(set) var startDate: Date?
    private(set) var endDate: Date?
    /// Increments every time a countdown runs out (drives haptics).
    private(set) var finishCount = 0

    @ObservationIgnored private var task: Task<Void, Never>?
    private static let notificationID = "rest-timer"

    var isActive: Bool { endDate != nil }

    func start(seconds: Int) {
        let now = Date.now
        startDate = now
        endDate = now.addingTimeInterval(TimeInterval(seconds))
        reschedule()
        notifyActivity()
    }

    func adjust(by seconds: Int) {
        guard let end = endDate else { return }
        endDate = max(end.addingTimeInterval(TimeInterval(seconds)), Date.now.addingTimeInterval(1))
        reschedule()
        notifyActivity()
    }

    func stop() {
        task?.cancel()
        task = nil
        startDate = nil
        endDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        notifyActivity()
    }

    private func notifyActivity() {
        WorkoutActivityController.shared.restChanged(start: startDate, end: endDate)
    }

    private func reschedule() {
        task?.cancel()
        guard let end = endDate else { return }
        let remaining = max(end.timeIntervalSinceNow, 0)
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled, let self else { return }
            self.startDate = nil
            self.endDate = nil
            self.finishCount += 1
            self.notifyActivity()
        }
        scheduleNotification(after: remaining)
    }

    private func scheduleNotification(after interval: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        guard interval >= 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Pause vorbei"
        content.body = "Weiter geht's mit dem nächsten Satz! 💪"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
    }

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}

/// Shows the rest notification as a banner even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
