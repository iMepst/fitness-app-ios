import Testing
import Foundation
import SwiftData
@testable import Fitness_App

private let berlin: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    berlin.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

@MainActor
struct OpeningHoursTests {
    /// Mo–Fr 06–23, Sa 09–20, So closed.
    let regular: WeeklyHours = {
        var hours = WeeklyHours.empty
        for day in 0...4 { hours.days[day] = [TimeRange(open: 6 * 60, close: 23 * 60)] }
        hours.days[5] = [TimeRange(open: 9 * 60, close: 20 * 60)]
        return hours
    }()

    // 2026-11-12 is a Thursday.

    @Test func dayIndexIsMondayBased() {
        #expect(WeeklyHours.dayIndex(of: date(2026, 11, 9), calendar: berlin) == 0)  // Monday
        #expect(WeeklyHours.dayIndex(of: date(2026, 11, 15), calendar: berlin) == 6) // Sunday
    }

    @Test func emptyIsUnknown() {
        #expect(WeeklyHours.empty.status(at: date(2026, 11, 12, 12), calendar: berlin) == .unknown)
    }

    @Test func openDuringHours() {
        #expect(regular.status(at: date(2026, 11, 12, 12), calendar: berlin) == .open(until: date(2026, 11, 12, 23)))
    }

    @Test func closedBeforeOpening() {
        #expect(regular.status(at: date(2026, 11, 12, 5, 30), calendar: berlin) == .closed(opensAt: date(2026, 11, 12, 6)))
    }

    @Test func closedSundayOpensMonday() {
        #expect(regular.status(at: date(2026, 11, 15, 12), calendar: berlin) == .closed(opensAt: date(2026, 11, 16, 6)))
    }

    @Test func closingAfterMidnight() {
        var hours = WeeklyHours.empty
        hours.days[4] = [TimeRange(open: 18 * 60, close: 2 * 60)] // Fri 18:00 – Sat 02:00
        #expect(hours.status(at: date(2026, 11, 14, 1), calendar: berlin) == .open(until: date(2026, 11, 14, 2)))
    }

    @Test func aroundTheClock() {
        #expect(WeeklyHours.aroundTheClock.status(at: date(2026, 11, 12, 3), calendar: berlin) == .open(until: nil))
    }

    @Test func staffedHoursDaily() {
        let staffed = WeeklyHours.daily([TimeRange(open: 8 * 60, close: 22 * 60)])
        #expect(staffed.status(at: date(2026, 11, 12, 21), calendar: berlin) == .open(until: date(2026, 11, 12, 22)))
        #expect(staffed.status(at: date(2026, 11, 12, 23), calendar: berlin) == .closed(opensAt: date(2026, 11, 13, 8)))
    }

    @Test func groupedRows() {
        let rows = regular.groupedRows()
        #expect(rows.map(\.label) == ["Mo–Fr", "Samstag", "Sonntag"])
        #expect(rows.map(\.hours) == ["06:00–23:00", "09:00–20:00", "geschlossen"])
        let allDay = WeeklyHours.aroundTheClock.groupedRows()
        #expect(allDay.map(\.label) == ["Täglich"])
        #expect(allDay.map(\.hours) == ["24 Stunden"])
    }
}

@MainActor
struct BuiltInStudioHoursTests {
    @Test func wandsbekByName() {
        let hours = BuiltInStudioHours.hours(name: "john reed wandsbek", address: "")
        #expect(hours?.opening == .aroundTheClock)
        #expect(hours?.staffed == .daily([TimeRange(open: 8 * 60, close: 22 * 60)]))
    }

    @Test func wandsbekByAddressWhenRenamed() {
        let hours = BuiltInStudioHours.hours(name: "Mein Gym", address: "Walddörferstraße 140-142, 22041 Hamburg, Deutschland")
        #expect(hours?.opening == .aroundTheClock)
    }

    @Test func unknownStudioHasNoHours() {
        #expect(BuiltInStudioHours.hours(name: "Anderes Studio", address: "Musterweg 1, Hamburg") == nil)
    }
}

@MainActor
struct MembershipContractTests {
    @Test func withinMinimumTerm() {
        let contract = MembershipContract(startDate: date(2026, 3, 1), minimumTermMonths: 12, noticeValue: 1, noticeUnit: .months)
        let next = contract.nextCancellation(after: date(2026, 11, 12), calendar: berlin)
        #expect(next?.termEnd == date(2027, 2, 28))
        #expect(next?.deadline == date(2027, 1, 28))
    }

    @Test func afterMinimumTermRenewsMonthly() {
        let contract = MembershipContract(startDate: date(2024, 3, 1), minimumTermMonths: 12, noticeValue: 1, noticeUnit: .months, renewalMonths: 1)
        let next = contract.nextCancellation(after: date(2026, 11, 12), calendar: berlin)
        #expect(next?.termEnd == date(2026, 12, 31))
        #expect(next?.deadline == date(2026, 11, 30))
    }

    @Test func missedDeadlineMovesToNextPeriod() {
        let contract = MembershipContract(startDate: date(2025, 12, 1), minimumTermMonths: 12, noticeValue: 4, noticeUnit: .weeks, renewalMonths: 12)
        // Term ends 30 Nov 2026, deadline 2 Nov 2026 — already missed on 12 Nov.
        let next = contract.nextCancellation(after: date(2026, 11, 12), calendar: berlin)
        #expect(next?.termEnd == date(2027, 11, 30))
        #expect(next?.deadline == date(2027, 11, 2))
    }

    @Test func deadlineTodayStillCounts() {
        let contract = MembershipContract(startDate: date(2026, 1, 13), minimumTermMonths: 12, noticeValue: 2, noticeUnit: .months)
        let next = contract.nextCancellation(after: date(2026, 11, 12, 18), calendar: berlin)
        #expect(next?.deadline == date(2026, 11, 12))
    }

    @Test func monthEndStartDate() {
        let contract = MembershipContract(startDate: date(2026, 1, 31), minimumTermMonths: 1, noticeValue: 7, noticeUnit: .days)
        #expect(contract.minimumTermEnd(calendar: berlin) == date(2026, 2, 28))
        // Computed from the start date, so no drift to the 28th later on.
        let next = contract.nextCancellation(after: date(2026, 4, 1), calendar: berlin)
        #expect(next?.termEnd == date(2026, 4, 30))
        #expect(next?.deadline == date(2026, 4, 23))
    }

    @Test func reminderDateBeforeDeadline() {
        let contract = MembershipContract(startDate: date(2026, 3, 1), minimumTermMonths: 12, reminderLeadDays: 14)
        let reminder = ContractReminder.reminderDate(for: contract, now: date(2026, 11, 12), calendar: berlin)
        #expect(reminder == date(2027, 1, 14, 9))
    }

    @Test func noReminderWhenLeadTimePassed() {
        let contract = MembershipContract(startDate: date(2024, 3, 1), minimumTermMonths: 12, reminderLeadDays: 30)
        #expect(ContractReminder.reminderDate(for: contract, now: date(2026, 11, 12), calendar: berlin) == nil)
    }
}

@MainActor
struct LockerTests {
    @Test func lockerExpiresAfterTwelveHours() {
        let gym = Gym(name: "Test")
        let start = date(2026, 11, 12, 18)
        gym.setLocker(" 142 ", now: start)
        #expect(gym.currentLocker(now: start.addingTimeInterval(3600)) == "142")
        #expect(gym.currentLocker(now: start.addingTimeInterval(12 * 3600 + 1)) == nil)
    }

    @Test func emptyInputClearsLocker() {
        let gym = Gym(name: "Test")
        gym.setLocker("7")
        gym.setLocker("   ")
        #expect(gym.lockerNumber == nil)
        #expect(gym.currentLocker() == nil)
    }

    @Test func lockerKeepsOnlyDigits() {
        let gym = Gym(name: "A")
        gym.setLocker("Nr. 1-42")
        #expect(gym.lockerNumber == "142")
        gym.setLocker("1234567")
        #expect(gym.lockerNumber == "12345")
        gym.setLocker("abc")
        #expect(gym.lockerNumber == nil)
        #expect(Gym.lockerDigits("٣4") == "4", "only ASCII digits")
    }
}

