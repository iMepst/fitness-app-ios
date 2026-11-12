import Foundation
import UserNotifications

/// Local notification before a studio contract's next cancellation deadline.
enum ContractReminder {
    private static func identifier(for gym: Gym) -> String { "contract-\(gym.id.uuidString)" }

    /// Date the reminder fires (09:00 local time), or nil if none is due.
    static func reminderDate(for contract: MembershipContract, now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard contract.reminderEnabled,
              let cancellation = contract.nextCancellation(after: now, calendar: calendar),
              let day = calendar.date(byAdding: .day, value: -max(contract.reminderLeadDays, 0), to: cancellation.deadline),
              let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) else { return nil }
        // Lead time already passed: no notification (the studio page highlights the
        // deadline instead), otherwise every app launch would fire it again.
        return fire > now ? fire : nil
    }

    /// Replaces the pending reminder for this gym.
    static func reschedule(for gym: Gym) {
        let center = UNUserNotificationCenter.current()
        let id = identifier(for: gym)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard let contract = gym.contract,
              let cancellation = contract.nextCancellation(),
              let fireDate = reminderDate(for: contract) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Kündigungsfrist \(gym.name)"
        content.body = "Wenn du kündigen willst: spätestens bis \(cancellation.deadline.formatted(date: .long, time: .omitted)). Sonst verlängert sich dein Vertrag."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(for gym: Gym) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: gym)])
    }

    /// Deadlines roll forward every period, so refresh all reminders at launch.
    static func rescheduleAll(_ gyms: [Gym]) {
        for gym in gyms { reschedule(for: gym) }
    }
}
