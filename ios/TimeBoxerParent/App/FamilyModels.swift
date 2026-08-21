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

struct ParentDashboardSnapshot: Equatable, Sendable {
    var device: ChildDeviceSummary
    var pendingRequests: [ExtraTimeRequest]
    var alerts: [FamilyAlert]

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
        ]
    )
}

protocol FamilyCloudService: Sendable {
    func loadDashboard() async throws -> ParentDashboardSnapshot
    func resolveRequest(id: UUID, approved: Bool) async throws
    func createPairingSession() async throws -> PairingSession
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
}
