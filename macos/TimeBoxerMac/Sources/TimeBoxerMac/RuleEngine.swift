import Foundation

struct RuleEngine: Sendable {
    static let publicHealthCeilingMinutes = 120

    func dayType(for date: Date, calendar: Calendar, override: TimeBoxerDayType?) -> TimeBoxerDayType {
        if let override { return override }
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 ? .weekend : .school
    }

    func dailyLimit(for policy: FamilyPolicy, date: Date, calendar: Calendar) -> Int {
        let base: Int
        switch dayType(for: date, calendar: calendar, override: policy.dayOverride) {
        case .school: base = policy.limits.school
        case .weekend: base = policy.limits.weekend
        case .holiday: base = policy.limits.holiday
        }
        return min(Self.publicHealthCeilingMinutes, max(0, base + policy.bonusMinutesToday))
    }

    func remainingMinutes(for policy: FamilyPolicy, date: Date, calendar: Calendar) -> Int {
        max(0, dailyLimit(for: policy, date: date, calendar: calendar) - policy.usedMinutesToday)
    }

    func decision(for policy: FamilyPolicy, date: Date, calendar: Calendar) -> RuleDecision {
        if isInsideBedtimeBlock(policy: policy, date: date, calendar: calendar) {
            return .blocked(.bedtime)
        }
        if remainingMinutes(for: policy, date: date, calendar: calendar) <= 0 {
            return .blocked(.dailyLimitReached)
        }
        return .allowed
    }

    func isInsideBedtimeBlock(policy: FamilyPolicy, date: Date, calendar: Calendar) -> Bool {
        let parts = policy.bedtime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return false }

        let bedtimeMinutes = parts[0] * 60 + parts[1]
        let cutoff = (bedtimeMinutes - policy.bedtimeBufferMinutes + 1_440) % 1_440
        let now = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        // Keep entertainment blocked overnight until 5am.
        return now >= cutoff || now < 300
    }
}
