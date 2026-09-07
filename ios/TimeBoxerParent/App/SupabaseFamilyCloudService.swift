import Foundation
import Supabase

actor SupabaseFamilyCloudService: FamilyCloudService {
    private struct BootstrapBody: Encodable { let action = "bootstrap" }
    private struct BootstrapResponse: Decodable {
        let familyId: UUID
        let childId: UUID
        let childName: String
    }
    private struct CreatePairingBody: Encodable {
        let action = "create"
        let childId: UUID
    }
    private struct PairingResponse: Decodable {
        let code: String
        let expiresAt: Date
    }
    private struct UpdatePolicyBody: Encodable {
        let action = "updatePolicy"
        let childId: UUID
        let expectedRevision: Int
        let policyDocument: FamilyPolicyDocument
    }
    private struct ResolveRequestBody: Encodable {
        let action = "resolveRequest"
        let requestId: UUID
        let approved: Bool
    }
    private struct ResolveRequestResponse: Decodable {
        let id: UUID
        let status: String
    }
    private struct PolicyRow: Decodable {
        let revision: Int
        let document: FamilyPolicyDocument
    }
    private struct DeviceRow: Decodable {
        let id: UUID
        let displayName: String
        let lastSeenAt: Date?
        let revokedAt: Date?
        let applicationInventory: [DetectedApplication]
        let applicationInventoryScannedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case lastSeenAt = "last_seen_at"
            case revokedAt = "revoked_at"
            case applicationInventory = "application_inventory"
            case applicationInventoryScannedAt = "application_inventory_scanned_at"
        }
    }
    private struct RequestRow: Decodable {
        let id: UUID
        let requestedMinutes: Int
        let requestedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case requestedMinutes = "requested_minutes"
            case requestedAt = "requested_at"
        }
    }
    private struct EventRow: Decodable {
        let id: UUID
        let eventType: String
        let subjectLabel: String?
        let occurredAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case eventType = "event_type"
            case subjectLabel = "subject_label"
            case occurredAt = "occurred_at"
        }
    }
    private let client: SupabaseClient
    private var bootstrap: BootstrapResponse?

    init(client: SupabaseClient = SupabaseEnvironment.client) {
        self.client = client
    }

    func loadDashboard() async throws -> ParentDashboardSnapshot {
        let family = try await ensureFamily()
        let database = try await authenticatedDatabase()
        let devices: [DeviceRow] = try await database
            .from("child_devices")
            .select("id, display_name, last_seen_at, revoked_at, application_inventory, application_inventory_scanned_at")
            .eq("child_id", value: family.childId)
            .is("revoked_at", value: nil)
            .order("last_seen_at", ascending: false)
            .limit(1)
            .execute()
            .value

        let policies: [PolicyRow] = try await database
            .from("family_policies")
            .select("revision, document")
            .eq("child_id", value: family.childId)
            .limit(1)
            .execute()
            .value

        let requests: [RequestRow] = try await database
            .from("extra_time_requests")
            .select("id, requested_minutes, requested_at")
            .eq("child_id", value: family.childId)
            .eq("status", value: "pending")
            .order("requested_at", ascending: false)
            .limit(10)
            .execute()
            .value

        let events: [EventRow] = try await database
            .from("activity_events")
            .select("id, event_type, subject_label, occurred_at")
            .eq("child_id", value: family.childId)
            .in("event_type", values: ["app_blocked", "website_blocked"])
            .order("occurred_at", ascending: false)
            .limit(10)
            .execute()
            .value

        let now = Date()
        let policy = policies.first.map { FamilyPolicy(revision: $0.revision, document: $0.document) }
            ?? FamilyPolicy(revision: 1, document: .balanced)
        let dateKey = Self.localDateKey(now)
        let currentDayPlan: FamilyDayPlan
        if policy.document.todayPlanDate == dateKey, let override = policy.document.todayPlan {
            currentDayPlan = override
        } else {
            let weekday = Calendar.current.component(.weekday, from: now)
            currentDayPlan = weekday == 1 || weekday == 7 ? .weekend : .school
        }
        let baseDailyLimit = policy.document.dayPlans[currentDayPlan].baseMinutes
        let parentBonus = policy.document.parentBonusDate == dateKey
            ? max(0, policy.document.parentBonusMinutes ?? 0)
            : 0
        let dailyLimit = min(120, baseDailyLimit + parentBonus)
        let device = devices.first
        let state: ChildDeviceState
        if let lastSeen = device?.lastSeenAt, now.timeIntervalSince(lastSeen) < 90 {
            state = .online(lastSeen: lastSeen)
        } else {
            state = .offline(lastSeen: device?.lastSeenAt)
        }

        return ParentDashboardSnapshot(
            device: ChildDeviceSummary(
                id: device?.id ?? family.childId,
                childName: family.childName,
                deviceName: device?.displayName ?? "No Mac paired yet",
                state: state,
                currentActivity: device == nil ? "Pair a child Mac to begin" : "Family protection configured",
                availableMinutes: dailyLimit,
                usedMinutes: 0,
                dailyLimit: dailyLimit
            ),
            pendingRequests: requests.map {
                ExtraTimeRequest(
                    id: $0.id,
                    childName: family.childName,
                    minutes: $0.requestedMinutes,
                    createdAt: $0.requestedAt
                )
            },
            alerts: events.map {
                let website = $0.eventType == "website_blocked"
                let label = $0.subjectLabel ?? (website ? "A website" : "An app")
                return FamilyAlert(
                    id: $0.id,
                    title: "\(label) activated the focus shield",
                    detail: website
                        ? "The child Mac covered the screen, sounded an alarm, and recorded the protected website activity."
                        : "The child Mac covered the screen, sounded an alarm, and recorded the entertainment app activity.",
                    createdAt: $0.occurredAt,
                    severity: .violation,
                    isRead: false
                )
            },
            policy: policy,
            currentDayPlan: currentDayPlan,
            applications: device?.applicationInventory ?? [],
            applicationInventoryScannedAt: device?.applicationInventoryScannedAt
        )
    }

    func resolveRequest(id: UUID, approved: Bool) async throws {
        let identity = try await authenticatedIdentity()
        client.functions.setAuth(token: identity.accessToken)
        let _: ResolveRequestResponse = try await client.functions.invoke(
            "timeboxer-pairing",
            options: FunctionInvokeOptions(
                body: ResolveRequestBody(requestId: id, approved: approved)
            )
        )
    }

    func createPairingSession() async throws -> PairingSession {
        let family = try await ensureFamily()
        let identity = try await authenticatedIdentity()
        client.functions.setAuth(token: identity.accessToken)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response: PairingResponse = try await client.functions.invoke(
            "timeboxer-pairing",
            options: FunctionInvokeOptions(body: CreatePairingBody(childId: family.childId)),
            decoder: decoder
        )
        return PairingSession(code: response.code, expiresAt: response.expiresAt)
    }

    func savePolicy(_ policy: FamilyPolicy) async throws -> FamilyPolicy {
        let family = try await ensureFamily()
        let identity = try await authenticatedIdentity()
        client.functions.setAuth(token: identity.accessToken)
        return try await client.functions.invoke(
            "timeboxer-pairing",
            options: FunctionInvokeOptions(
                body: UpdatePolicyBody(
                    childId: family.childId,
                    expectedRevision: policy.revision,
                    policyDocument: policy.document
                )
            )
        )
    }

    private func ensureFamily() async throws -> BootstrapResponse {
        if let bootstrap { return bootstrap }
        let identity = try await authenticatedIdentity()
        client.functions.setAuth(token: identity.accessToken)
        let response: BootstrapResponse = try await client.functions.invoke(
            "timeboxer-pairing",
            options: FunctionInvokeOptions(body: BootstrapBody())
        )
        bootstrap = response
        return response
    }

    private func authenticatedDatabase() async throws -> PostgrestClient {
        let identity = try await authenticatedIdentity()
        return client.schema("public").setAuth(identity.accessToken)
    }

    private func authenticatedIdentity() async throws -> SupabaseSessionIdentity {
        if let identity = await SupabaseEnvironment.sessionStore.current() {
            return identity
        }
        let session = try await client.auth.session
        let identity = SupabaseSessionIdentity(
            accessToken: session.accessToken,
            userID: session.user.id
        )
        await SupabaseEnvironment.sessionStore.set(
            accessToken: identity.accessToken,
            userID: identity.userID
        )
        return identity
    }


    private static func localDateKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
