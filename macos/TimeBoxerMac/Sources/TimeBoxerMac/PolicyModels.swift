import Foundation

enum EnforcementMode: String, Codable, Sendable {
    case observe
    case enforce
}

enum TimeBoxerDayType: String, Codable, Sendable {
    case school
    case weekend
    case holiday
}

struct DailyLimits: Codable, Equatable, Sendable {
    var school: Int
    var weekend: Int
    var holiday: Int

    static let balanced = DailyLimits(school: 20, weekend: 30, holiday: 40)
}

struct FamilyPolicy: Codable, Equatable, Sendable {
    var childName: String
    var bedtime: String
    var bedtimeBufferMinutes: Int
    var limits: DailyLimits
    var usedMinutesToday: Int
    var bonusMinutesToday: Int
    var dayOverride: TimeBoxerDayType?
    var blockedBundleIdentifiers: Set<String>
    var enforcementMode: EnforcementMode

    static let safeDefault = FamilyPolicy(
        childName: "Alex",
        bedtime: "20:30",
        bedtimeBufferMinutes: 60,
        limits: .balanced,
        usedMinutesToday: 0,
        bonusMinutesToday: 0,
        dayOverride: nil,
        blockedBundleIdentifiers: [
            "com.valvesoftware.steam",
            "com.roblox.Roblox",
            "com.mojang.minecraftlauncher",
        ],
        enforcementMode: .observe
    )
}

enum BlockReason: Equatable, Sendable {
    case bedtime
    case dailyLimitReached

    var title: String {
        switch self {
        case .bedtime: "Entertainment is finished for today"
        case .dailyLimitReached: "Today’s entertainment time is used up"
        }
    }

    var detail: String {
        switch self {
        case .bedtime: "Your family plan stops entertainment one hour before bedtime."
        case .dailyLimitReached: "Earn more time or ask a parent for a one-day exception."
        }
    }
}

struct RuleDecision: Equatable, Sendable {
    var isAllowed: Bool
    var reason: BlockReason?

    static let allowed = RuleDecision(isAllowed: true, reason: nil)

    static func blocked(_ reason: BlockReason) -> RuleDecision {
        RuleDecision(isAllowed: false, reason: reason)
    }
}
