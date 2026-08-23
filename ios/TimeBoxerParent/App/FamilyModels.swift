import Foundation

enum ChildDeviceState: Equatable, Sendable {
    case online(lastSeen: Date)
    case offline(lastSeen: Date?)

    var isOnline: Bool {
        if case .online = self { return true }
        return false
    }
}

struct ChildDeviceSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    var childName: String
    var deviceName: String
    var state: ChildDeviceState
    var currentActivity: String
    var availableMinutes: Int
    var usedMinutes: Int
    var dailyLimit: Int
}

struct ExtraTimeRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    var childName: String
    var minutes: Int
    var createdAt: Date
}

struct FamilyAlert: Identifiable, Equatable, Sendable {
    enum Severity: Sendable {
        case information
        case warning
        case violation
    }

    let id: UUID
    var title: String
    var detail: String
    var createdAt: Date
    var severity: Severity
    var isRead: Bool
}

struct PairingSession: Equatable, Sendable {
    var code: String
    var expiresAt: Date
}

enum FamilyDayPlan: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case school
    case weekend
    case holiday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .school: "School day"
        case .weekend: "Weekend"
        case .holiday: "Holiday"
        }
    }
}

struct FamilyDayPlanLimits: Codable, Equatable, Sendable {
    var baseMinutes: Int
    var earnCapMinutes: Int
}

struct FamilyDayPlans: Codable, Equatable, Sendable {
    var school: FamilyDayPlanLimits
    var weekend: FamilyDayPlanLimits
    var holiday: FamilyDayPlanLimits

    subscript(plan: FamilyDayPlan) -> FamilyDayPlanLimits {
        switch plan {
        case .school: school
        case .weekend: weekend
        case .holiday: holiday
        }
    }
}

struct FamilyEarnTask: Codable, Equatable, Sendable {
    var id: String
    var title: String
    var durationMinutes: Int
    var rewardMinutes: Int
}

struct FamilyPolicyDocument: Codable, Equatable, Sendable {
    var version: Int
    var dayPlans: FamilyDayPlans
    var maxSessionMinutes: Int
    var cooldownMinutes: Int
    var cooldownTriggerMinutes: Int
    var bedtimeBufferMinutes: Int
    var earnTasks: [FamilyEarnTask]
    var protectedApplications: [String]
    var protectedDomains: [String]
    var todayPlan: FamilyDayPlan?
    var todayPlanDate: String?
    var parentBonusMinutes: Int?
    var parentBonusDate: String?

    static let balanced = FamilyPolicyDocument(
        version: 1,
        dayPlans: FamilyDayPlans(
            school: FamilyDayPlanLimits(baseMinutes: 20, earnCapMinutes: 10),
            weekend: FamilyDayPlanLimits(baseMinutes: 30, earnCapMinutes: 20),
            holiday: FamilyDayPlanLimits(baseMinutes: 40, earnCapMinutes: 20)
        ),
        maxSessionMinutes: 20,
        cooldownMinutes: 10,
        cooldownTriggerMinutes: 20,
        bedtimeBufferMinutes: 60,
        earnTasks: [],
        protectedApplications: [],
        protectedDomains: [],
        todayPlan: nil,
        todayPlanDate: nil,
        parentBonusMinutes: nil,
        parentBonusDate: nil
    )
}

struct FamilyPolicy: Codable, Equatable, Sendable {
    var revision: Int
    var document: FamilyPolicyDocument
}

struct ParentDashboardSnapshot: Equatable, Sendable {
    var device: ChildDeviceSummary
    var pendingRequests: [ExtraTimeRequest]
    var alerts: [FamilyAlert]
    var policy: FamilyPolicy
    var currentDayPlan: FamilyDayPlan

    static let preview = ParentDashboardSnapshot(
        device: ChildDeviceSummary(
            id: UUID(uuidString: "E7B79737-B5DC-42FB-A123-BBAEA5F01201")!,
            childName: "Alex",
            deviceName: "Alex’s MacBook Air",
            state: .online(lastSeen: .now),
            currentActivity: "Homework mode",
            availableMinutes: 30,
            usedMinutes: 0,
            dailyLimit: 30
        ),
        pendingRequests: [
            ExtraTimeRequest(
                id: UUID(uuidString: "7CBB1A61-C2AF-4C32-8F50-40E28BBCF902")!,
                childName: "Alex",
                minutes: 10,
                createdAt: .now.addingTimeInterval(-180)
            ),
        ],
        alerts: [
            FamilyAlert(
                id: UUID(uuidString: "395997B4-D146-48B7-8FE1-0CA541DCCB22")!,
                title: "YouTube was blocked",
                detail: "Chrome tried to open youtube.com outside Play time.",
                createdAt: .now.addingTimeInterval(-420),
                severity: .violation,
                isRead: false
            ),
        ],
        policy: FamilyPolicy(revision: 1, document: .balanced),
        currentDayPlan: .school
    )
}

protocol FamilyCloudService: Sendable {
    func loadDashboard() async throws -> ParentDashboardSnapshot
    func resolveRequest(id: UUID, approved: Bool) async throws
    func createPairingSession() async throws -> PairingSession
    func savePolicy(_ policy: FamilyPolicy) async throws -> FamilyPolicy
}

actor PreviewFamilyCloudService: FamilyCloudService {
    private var snapshot = ParentDashboardSnapshot.preview

    func loadDashboard() async throws -> ParentDashboardSnapshot {
        snapshot
    }

    func resolveRequest(id: UUID, approved: Bool) async throws {
        snapshot.pendingRequests.removeAll { $0.id == id }
        if approved {
            snapshot.device.availableMinutes += 10
            snapshot.device.dailyLimit += 10
        }
    }

    func createPairingSession() async throws -> PairingSession {
        PairingSession(code: "427190", expiresAt: .now.addingTimeInterval(600))
    }

    func savePolicy(_ policy: FamilyPolicy) async throws -> FamilyPolicy {
        let saved = FamilyPolicy(revision: policy.revision + 1, document: policy.document)
        snapshot.policy = saved
        let plan = saved.document.todayPlan ?? snapshot.currentDayPlan
        snapshot.currentDayPlan = plan
        snapshot.device.dailyLimit = min(
            120,
            saved.document.dayPlans[plan].baseMinutes + (saved.document.parentBonusMinutes ?? 0)
        )
        snapshot.device.availableMinutes = snapshot.device.dailyLimit
        return saved
    }
}
