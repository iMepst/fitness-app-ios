import Foundation

/// A time span on one day, in minutes since midnight.
/// `close <= open` means the studio closes after midnight (next day);
/// `0...0` means open around the clock that day.
nonisolated struct TimeRange: Hashable {
    var open: Int
    var close: Int

    static let allDay = TimeRange(open: 0, close: 0)

    var isAllDay: Bool { open == 0 && close == 0 }

    /// Effective close in minutes relative to the opening day's midnight.
    var effectiveClose: Int { close <= open ? close + 24 * 60 : close }

    static func formatted(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    var label: String {
        if isAllDay { return "24 Stunden" }
        let end = close == 0 ? "24:00" : Self.formatted(close)
        return "\(Self.formatted(open))–\(end)"
    }
}

nonisolated enum OpenStatus: Equatable {
    /// No hours known.
    case unknown
    /// Open; `until` is nil when open around the clock.
    case open(until: Date?)
    /// Closed; `opensAt` is nil when no opening in the coming week.
    case closed(opensAt: Date?)
}

/// Weekly hours. `days[0]` is Monday … `days[6]` Sunday.
nonisolated struct WeeklyHours: Hashable {
    var days: [[TimeRange]]

    static let empty = WeeklyHours(days: Array(repeating: [], count: 7))

    /// Same ranges every day of the week.
    static func daily(_ ranges: [TimeRange]) -> WeeklyHours {
        WeeklyHours(days: Array(repeating: ranges, count: 7))
    }

    static let aroundTheClock = daily([.allDay])

    static let weekdayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
    static let weekdayShortNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var isEmpty: Bool { days.allSatisfy(\.isEmpty) }

    /// Monday-based index (0…6) of the given date.
    static func dayIndex(of date: Date, calendar: Calendar = .current) -> Int {
        // Calendar weekday: 1 = Sunday … 7 = Saturday.
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    func ranges(forDayIndex index: Int) -> [TimeRange] {
        days.indices.contains(index) ? days[index].sorted { $0.open < $1.open } : []
    }

    // MARK: Display

    struct Row: Hashable {
        /// Monday-based day indices covered by this row.
        let days: ClosedRange<Int>
        let label: String
        let hours: String
    }

    /// Consecutive days with identical hours collapsed: "Täglich", "Mo–Fr", "Samstag".
    func groupedRows() -> [Row] {
        let normalized = (0..<7).map { ranges(forDayIndex: $0) }
        var rows: [Row] = []
        var start = 0
        while start < 7 {
            var end = start
            while end + 1 < 7 && normalized[end + 1] == normalized[start] { end += 1 }
            let label: String
            if start == 0 && end == 6 {
                label = "Täglich"
            } else if start == end {
                label = Self.weekdayNames[start]
            } else {
                label = "\(Self.weekdayShortNames[start])–\(Self.weekdayShortNames[end])"
            }
            let hours = normalized[start].isEmpty ? "geschlossen" : normalized[start].map(\.label).joined(separator: ", ")
            rows.append(Row(days: start...end, label: label, hours: hours))
            start = end + 1
        }
        return rows
    }

    // MARK: Status

    /// Concrete open intervals from yesterday through the next 8 days, merged where they touch.
    private func intervals(around date: Date, calendar: Calendar) -> [DateInterval] {
        let today = calendar.startOfDay(for: date)
        var result: [DateInterval] = []
        for offset in -1...8 {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let index = Self.dayIndex(of: dayStart, calendar: calendar)
            for range in ranges(forDayIndex: index) {
                guard let start = calendar.date(byAdding: .minute, value: range.open, to: dayStart),
                      let end = calendar.date(byAdding: .minute, value: range.effectiveClose, to: dayStart),
                      end > start else { continue }
                result.append(DateInterval(start: start, end: end))
            }
        }
        result.sort { $0.start < $1.start }

        var merged: [DateInterval] = []
        for interval in result {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    func status(at date: Date = .now, calendar: Calendar = .current) -> OpenStatus {
        guard !isEmpty else { return .unknown }
        let all = intervals(around: date, calendar: calendar)
        if let current = all.first(where: { $0.start <= date && date < $0.end }) {
            // Interval reaching the end of the look-ahead window = open around the clock.
            return .open(until: current.duration >= 7 * 24 * 3600 ? nil : current.end)
        }
        return .closed(opensAt: all.first { $0.start > date }?.start)
    }
}
