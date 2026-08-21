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

        XCTAssertEqual(engine.dailyLimit(for: policy, date: friday, calendar: calendar), 20)
        XCTAssertEqual(engine.dailyLimit(for: policy, date: saturday, calendar: calendar), 30)
    }

    func testHolidayOverrideAndBonusStayUnderCeiling() {
        var policy = FamilyPolicy.safeDefault
        policy.dayOverride = .holiday
        policy.bonusMinutesToday = 100

        let date = makeDate(year: 2026, month: 8, day: 14, hour: 12)
        XCTAssertEqual(engine.dailyLimit(for: policy, date: date, calendar: calendar), 120)
    }

    func testBlocksWhenDailyLimitIsUsed() {
        var policy = FamilyPolicy.safeDefault
        policy.activeEntertainmentUntil = makeDate(year: 2026, month: 8, day: 14, hour: 13)
        policy.usedMinutesToday = 20
        let date = makeDate(year: 2026, month: 8, day: 14, hour: 12)

        XCTAssertEqual(engine.decision(for: policy, date: date, calendar: calendar), .blocked(.dailyLimitReached))
    }

    func testBlocksOneHourBeforeBedtimeAndOvernight() {
        var policy = FamilyPolicy.safeDefault
        policy.activeEntertainmentUntil = makeDate(year: 2026, month: 8, day: 15, hour: 2)
        let beforeCutoff = makeDate(year: 2026, month: 8, day: 14, hour: 19, minute: 29)
        let afterCutoff = makeDate(year: 2026, month: 8, day: 14, hour: 19, minute: 30)
        let overnight = makeDate(year: 2026, month: 8, day: 15, hour: 1)

        XCTAssertEqual(engine.decision(for: policy, date: beforeCutoff, calendar: calendar), .allowed)
        XCTAssertEqual(engine.decision(for: policy, date: afterCutoff, calendar: calendar), .blocked(.bedtime))
        XCTAssertEqual(engine.decision(for: policy, date: overnight, calendar: calendar), .blocked(.bedtime))
    }

    func testBlocksEntertainmentUntilPlayStarts() {
        let policy = FamilyPolicy.safeDefault
        let date = makeDate(year: 2026, month: 8, day: 14, hour: 12)

        XCTAssertEqual(
            engine.decision(for: policy, date: date, calendar: calendar),
            .blocked(.outsideApprovedSession)
        )
    }

    func testAllowsEntertainmentOnlyInsideApprovedPlaySession() {
        var policy = FamilyPolicy.safeDefault
        let date = makeDate(year: 2026, month: 8, day: 14, hour: 12)
        policy.activeEntertainmentUntil = makeDate(year: 2026, month: 8, day: 14, hour: 12, minute: 20)

        XCTAssertEqual(engine.decision(for: policy, date: date, calendar: calendar), .allowed)
        XCTAssertEqual(
            engine.decision(
                for: policy,
                date: makeDate(year: 2026, month: 8, day: 14, hour: 12, minute: 20),
                calendar: calendar
            ),
            .blocked(.outsideApprovedSession)
        )
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
