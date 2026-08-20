import Foundation
import XCTest
@testable import TimeBoxerMac

final class RuleEngineTests: XCTestCase {
    private let engine = RuleEngine()
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        return calendar
    }

    func testSelectsSchoolAndWeekendLimits() {
        let policy = FamilyPolicy.safeDefault
        let friday = makeDate(year: 2026, month: 8, day: 14, hour: 12)
        let saturday = makeDate(year: 2026, month: 8, day: 15, hour: 12)

        XCTAssertEqual(engine.dailyLimit(for: policy, date: friday, calendar: calendar), 30)
        XCTAssertEqual(engine.dailyLimit(for: policy, date: saturday, calendar: calendar), 60)
    }

    func testHolidayOverrideAndBonusStayUnderCeiling() {
        var policy = FamilyPolicy.safeDefault
        policy.dayOverride = .holiday
        policy.bonusMinutesToday = 50

        let date = makeDate(year: 2026, month: 8, day: 14, hour: 12)
        XCTAssertEqual(engine.dailyLimit(for: policy, date: date, calendar: calendar), 120)
    }

    func testBlocksWhenDailyLimitIsUsed() {
        var policy = FamilyPolicy.safeDefault
        policy.usedMinutesToday = 30
        let date = makeDate(year: 2026, month: 8, day: 14, hour: 12)

        XCTAssertEqual(engine.decision(for: policy, date: date, calendar: calendar), .blocked(.dailyLimitReached))
    }

    func testBlocksOneHourBeforeBedtimeAndOvernight() {
        let policy = FamilyPolicy.safeDefault
        let beforeCutoff = makeDate(year: 2026, month: 8, day: 14, hour: 19, minute: 29)
        let afterCutoff = makeDate(year: 2026, month: 8, day: 14, hour: 19, minute: 30)
        let overnight = makeDate(year: 2026, month: 8, day: 15, hour: 1)

        XCTAssertEqual(engine.decision(for: policy, date: beforeCutoff, calendar: calendar), .allowed)
        XCTAssertEqual(engine.decision(for: policy, date: afterCutoff, calendar: calendar), .blocked(.bedtime))
        XCTAssertEqual(engine.decision(for: policy, date: overnight, calendar: calendar), .blocked(.bedtime))
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
