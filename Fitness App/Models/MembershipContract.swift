import Foundation

nonisolated enum NoticeUnit: String, Codable, CaseIterable, Identifiable {
    case days, weeks, months

    var id: String { rawValue }

    func label(_ value: Int) -> String {
        switch self {
        case .days: value == 1 ? "Tag" : "Tage"
        case .weeks: value == 1 ? "Woche" : "Wochen"
        case .months: value == 1 ? "Monat" : "Monate"
        }
    }

    var pluralLabel: String { label(2) }
}

/// Membership contract of a studio. After the minimum term the contract renews
/// by `renewalMonths` (1 month by default for contracts since March 2022).
nonisolated struct MembershipContract: Codable, Hashable {
    var memberNumber: String = ""
    var startDate: Date
    var minimumTermMonths: Int = 12
    var noticeValue: Int = 1
    var noticeUnit: NoticeUnit = .months
    var renewalMonths: Int = 1
    var monthlyFee: Decimal?
    var reminderEnabled: Bool = true
    var reminderLeadDays: Int = 14

    struct Cancellation: Equatable {
        /// Last day of the membership if cancelled by `deadline`.
        let termEnd: Date
        /// Last day on which the cancellation must arrive.
        let deadline: Date
    }

    /// End of the minimum term (last day of membership).
    func minimumTermEnd(calendar: Calendar = .current) -> Date? {
        termEnd(afterMonths: minimumTermMonths, calendar: calendar)
    }

    /// The next term end that can still be reached by cancelling today or later.
    func nextCancellation(after now: Date = .now, calendar: Calendar = .current) -> Cancellation? {
        let today = calendar.startOfDay(for: now)
        let renewal = max(renewalMonths, 1)
        for period in 0..<1200 {
            let months = max(minimumTermMonths, 0) + period * renewal
            guard months > 0,
                  let end = termEnd(afterMonths: months, calendar: calendar),
                  let deadline = deadline(for: end, calendar: calendar) else { continue }
            if deadline >= today {
                return Cancellation(termEnd: end, deadline: deadline)
            }
        }
        return nil
    }

    /// The day before start + months (BGB §188). If that month has no matching
    /// day (start on the 31st), the term ends on the month's last day.
    /// Computed from the start date each time so month-end dates don't drift.
    private func termEnd(afterMonths months: Int, calendar: Calendar) -> Date? {
        let start = calendar.startOfDay(for: startDate)
        guard let next = calendar.date(byAdding: .month, value: months, to: start) else { return nil }
        if calendar.component(.day, from: next) < calendar.component(.day, from: start) {
            return next
        }
        return calendar.date(byAdding: .day, value: -1, to: next)
    }

    private func deadline(for termEnd: Date, calendar: Calendar) -> Date? {
        let value = max(noticeValue, 0)
        switch noticeUnit {
        case .days: return calendar.date(byAdding: .day, value: -value, to: termEnd)
        case .weeks: return calendar.date(byAdding: .day, value: -7 * value, to: termEnd)
        case .months: return calendar.date(byAdding: .month, value: -value, to: termEnd)
        }
    }
}
