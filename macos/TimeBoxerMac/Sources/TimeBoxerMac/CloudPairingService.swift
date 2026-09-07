import Foundation
import Security

struct CloudPairingResult: Codable, Equatable, Sendable {
    let deviceId: UUID
    let childId: UUID
    let deviceSecret: String
    let policyRevision: Int
}

struct CloudHeartbeatResult: Codable, Equatable, Sendable {
    let deviceId: UUID
    let lastSeenAt: String
    let policyRevision: Int
    let policy: CloudPolicyDocument?
    let requestUpdates: [CloudRequestUpdate]?
}

struct CloudRequestUpdate: Codable, Equatable, Sendable {
    let id: UUID
    let clientRequestId: UUID
    let requestedMinutes: Int
    let status: String
    let requestedAt: String
    let resolvedAt: String?
}

struct CloudDeviceEvent: Codable, Equatable, Sendable {
    var version = 1
    let clientEventId: UUID
    let eventType: String
    let severity: String
    let subjectLabel: String?
    let occurredAt: String
    let payload: [String: String]
}

struct CloudPolicyDayPlan: Codable, Equatable, Sendable {
    let baseMinutes: Int
    let earnCapMinutes: Int
}

struct CloudPolicyDayPlans: Codable, Equatable, Sendable {
    let school: CloudPolicyDayPlan
    let weekend: CloudPolicyDayPlan
    let holiday: CloudPolicyDayPlan
}

struct CloudPolicyEarnTask: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let durationMinutes: Int
    let rewardMinutes: Int
}

struct CloudPolicyDocument: Codable, Equatable, Sendable {
    let version: Int
    let dayPlans: CloudPolicyDayPlans
    let maxSessionMinutes: Int
    let cooldownMinutes: Int
    let cooldownTriggerMinutes: Int
    let bedtimeBufferMinutes: Int
    let earnTasks: [CloudPolicyEarnTask]
    let protectedApplications: [String]
    let protectedDomains: [String]
    let todayPlan: TimeBoxerDayType?
    let todayPlanDate: String?
    let parentBonusMinutes: Int?
    let parentBonusDate: String?
}

private struct CloudDeviceIdentity: Codable {
    let installationId: UUID
    let publicKey: Data
    var deviceId: UUID?
    var childId: UUID?
    var policyRevision: Int?
}

private struct ConsumePairingRequest: Encodable {
    let action = "consume"
    let code: String
    let installationId: UUID
    let displayName: String
    let appVersion: String
    let osVersion: String
    let publicKey: String
}

private struct HeartbeatRequest: Encodable {
    let action = "heartbeat"
    let deviceId: UUID
    let installationId: UUID
    let deviceSecret: String
    let appVersion: String
    let osVersion: String
    let knownPolicyRevision: Int
    let applicationInventory: [InstalledApplicationRecord]?
}

private struct DeviceEventRequest: Encodable {
    let action = "recordEvent"
    let deviceId: UUID
    let installationId: UUID
    let deviceSecret: String
    let event: CloudDeviceEvent
}

private struct ExtraTimeRequestBody: Encodable {
    let action = "requestExtraTime"
    let deviceId: UUID
    let installationId: UUID
    let deviceSecret: String
    let clientRequestId: UUID
    let requestedMinutes: Int
}

private struct DeviceEventResponse: Decodable {
    let accepted: Bool
    let duplicate: Bool
}

private struct ExtraTimeRequestResponse: Decodable {
    let id: UUID
    let status: String
    let requestedMinutes: Int
}

private struct CloudDeviceCredentials {
    let identity: CloudDeviceIdentity
    let secret: String
}

private struct PairingErrorResponse: Decodable {
    let error: String
}

enum CloudPairingError: LocalizedError {
    case configurationMissing
    case invalidCode
    case server(String)
    case invalidResponse
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            "TimeBoxer cloud configuration is missing."
        case .invalidCode:
            "Enter the six-digit code shown on the parent’s iPhone."
        case .server(let message):
            message
        case .invalidResponse:
            "The TimeBoxer cloud returned an invalid response."
        case .keychain(let status):
            "The device credential could not be saved to Keychain (\(status))."
        }
    }
}

final class CloudPairingService: @unchecked Sendable {
    private let endpoint: URL?
    private let publishableKey: String?
    private let gatewayToken: String?
    private let store: CloudDeviceStore
    private let session: URLSession

    init(bundle: Bundle = .main, session: URLSession = .shared) {
        let baseURL = bundle.object(forInfoDictionaryKey: "TIMEBOXER_SUPABASE_URL") as? String
        endpoint = baseURL.flatMap(URL.init(string:))?.appending(path: "functions/v1/timeboxer-pairing")
        publishableKey = bundle.object(forInfoDictionaryKey: "TIMEBOXER_SUPABASE_PUBLISHABLE_KEY") as? String
        gatewayToken = bundle.object(forInfoDictionaryKey: "TIMEBOXER_SUPABASE_ANON_JWT") as? String
        store = CloudDeviceStore()
        self.session = session
    }

    var isPaired: Bool {
        store.isPaired
    }

    func pair(code rawCode: String) async throws -> CloudPairingResult {
        let code = rawCode.filter(\.isNumber)
        guard code.count == 6 else { throw CloudPairingError.invalidCode }
        guard
            let endpoint,
            let publishableKey,
            publishableKey.hasPrefix("sb_publishable_"),
            let gatewayToken,
            gatewayToken.split(separator: ".").count == 3
        else {
            throw CloudPairingError.configurationMissing
        }

        let identity = try store.loadOrCreateIdentity()
        let body = ConsumePairingRequest(
            code: code,
            installationId: identity.installationId,
            displayName: Host.current().localizedName ?? "Child Mac",
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            publicKey: identity.publicKey.base64EncodedString()
        )

        let request = try configuredRequest(
            endpoint: endpoint,
            bodyData: JSONEncoder().encode(body)
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudPairingError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = (try? JSONDecoder().decode(PairingErrorResponse.self, from: data).error)
                ?? "The Mac could not be paired."
            throw CloudPairingError.server(message)
        }

        let result = try JSONDecoder().decode(CloudPairingResult.self, from: data)
        try store.save(result: result)
        return result
    }

    func heartbeat(applicationInventory: [InstalledApplicationRecord]? = nil) async throws -> CloudHeartbeatResult {
        guard
            let endpoint,
            let publishableKey,
            publishableKey.hasPrefix("sb_publishable_"),
            let gatewayToken,
            gatewayToken.split(separator: ".").count == 3
        else {
            throw CloudPairingError.configurationMissing
        }
        guard let credentials = store.loadPairedCredentials(), let deviceID = credentials.identity.deviceId else {
            throw CloudPairingError.invalidResponse
        }

        let body = HeartbeatRequest(
            deviceId: deviceID,
            installationId: credentials.identity.installationId,
            deviceSecret: credentials.secret,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            knownPolicyRevision: credentials.identity.policyRevision ?? 0,
            applicationInventory: applicationInventory
        )
        let request = try configuredRequest(
            endpoint: endpoint,
            bodyData: JSONEncoder().encode(body)
        )
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudPairingError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = (try? JSONDecoder().decode(PairingErrorResponse.self, from: data).error)
                ?? "The Mac heartbeat was rejected."
            throw CloudPairingError.server(message)
        }

        return try JSONDecoder().decode(CloudHeartbeatResult.self, from: data)
    }

    func record(event: CloudDeviceEvent) async throws {
        let credentials = try pairedCredentials()
        let body = DeviceEventRequest(
            deviceId: credentials.deviceID,
            installationId: credentials.identity.installationId,
            deviceSecret: credentials.secret,
            event: event
        )
        let _: DeviceEventResponse = try await sendPairedRequest(body)
    }

    func requestExtraTime(clientRequestID: UUID, minutes: Int) async throws {
        let credentials = try pairedCredentials()
        let body = ExtraTimeRequestBody(
            deviceId: credentials.deviceID,
            installationId: credentials.identity.installationId,
            deviceSecret: credentials.secret,
            clientRequestId: clientRequestID,
            requestedMinutes: minutes
        )
        let _: ExtraTimeRequestResponse = try await sendPairedRequest(body)
    }

    func acknowledgePolicyRevision(_ revision: Int) throws {
        try store.savePolicyRevision(revision)
    }

    private func pairedCredentials() throws -> (
        identity: CloudDeviceIdentity,
        deviceID: UUID,
        secret: String
    ) {
        guard
            let credentials = store.loadPairedCredentials(),
            let deviceID = credentials.identity.deviceId
        else {
            throw CloudPairingError.invalidResponse
        }
        return (credentials.identity, deviceID, credentials.secret)
    }

    private func sendPairedRequest<Body: Encodable, Result: Decodable>(
        _ body: Body
    ) async throws -> Result {
        guard
            let endpoint,
            let publishableKey,
            publishableKey.hasPrefix("sb_publishable_"),
            let gatewayToken,
            gatewayToken.split(separator: ".").count == 3
        else {
            throw CloudPairingError.configurationMissing
        }
        let request = try configuredRequest(
            endpoint: endpoint,
            bodyData: JSONEncoder().encode(body)
        )
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudPairingError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = (try? JSONDecoder().decode(PairingErrorResponse.self, from: data).error)
                ?? "The TimeBoxer cloud request was rejected."
            throw CloudPairingError.server(message)
        }
        return try JSONDecoder().decode(Result.self, from: data)
    }

    private func configuredRequest(endpoint: URL, bodyData: Data) throws -> URLRequest {
        guard let publishableKey, let gatewayToken else {
            throw CloudPairingError.configurationMissing
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(gatewayToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        return request
    }
}

private final class CloudDeviceStore {
    // Data Protection Keychain access is tied to the stable app identifier,
    // not an ad-hoc pilot build's changing code hash. This keeps device
    // credentials available when a tester installs a newer build.
    private static let keychainService = "nz.co.timeboxer.mac.device.v2"
    private struct LocalPilotCredential: Codable {
        let account: String
        let secret: Data
    }

    private let identityURL: URL
    private let pilotCredentialURL: URL
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let lock = NSLock()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directory = support.appendingPathComponent("TimeBoxer", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        identityURL = directory.appendingPathComponent("cloud-device.json")
        pilotCredentialURL = directory.appendingPathComponent("cloud-device-pilot-credential.json")
    }

    var isPaired: Bool {
        lock.withLock {
            guard let identity = loadIdentity(), let deviceID = identity.deviceId else { return false }
            return readSecret(account: deviceID.uuidString) != nil
        }
    }

    func loadOrCreateIdentity() throws -> CloudDeviceIdentity {
        try lock.withLock {
            if let identity = loadIdentity() { return identity }
            var key = Data(count: 32)
            let status = key.withUnsafeMutableBytes { bytes in
                SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
            }
            guard status == errSecSuccess else { throw CloudPairingError.keychain(status) }
            let identity = CloudDeviceIdentity(
                installationId: UUID(),
                publicKey: key,
                deviceId: nil,
                childId: nil,
                policyRevision: nil
            )
            try saveIdentity(identity)
            return identity
        }
    }

    func save(result: CloudPairingResult) throws {
        try lock.withLock {
            guard var identity = loadIdentity() else { throw CloudPairingError.invalidResponse }
            try saveSecret(Data(result.deviceSecret.utf8), account: result.deviceId.uuidString)
            identity.deviceId = result.deviceId
            identity.childId = result.childId
            identity.policyRevision = result.policyRevision
            try saveIdentity(identity)
        }
    }

    func loadPairedCredentials() -> CloudDeviceCredentials? {
        lock.withLock {
            guard
                let identity = loadIdentity(),
                let deviceID = identity.deviceId,
                let secretData = readSecret(account: deviceID.uuidString),
                let secret = String(data: secretData, encoding: .utf8),
                !secret.isEmpty
            else {
                return nil
            }
            return CloudDeviceCredentials(identity: identity, secret: secret)
        }
    }

    func savePolicyRevision(_ revision: Int) throws {
        try lock.withLock {
            guard var identity = loadIdentity(), identity.deviceId != nil else {
                throw CloudPairingError.invalidResponse
            }
            identity.policyRevision = revision
            try saveIdentity(identity)
        }
    }

    private func loadIdentity() -> CloudDeviceIdentity? {
        guard let data = try? Data(contentsOf: identityURL) else { return nil }
        return try? decoder.decode(CloudDeviceIdentity.self, from: data)
    }

    private func saveIdentity(_ identity: CloudDeviceIdentity) throws {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(identity).write(to: identityURL, options: .atomic)
    }

    private func readSecret(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess { return item as? Data }

        // Ad-hoc pilot builds do not have a provisioning profile that can
        // authorize Data Protection Keychain entitlements. Keep the random
        // device credential in a separate current-user-only file so an app
        // update cannot strand a paired test Mac. Distribution builds use
        // the keychain path above.
        guard
            let data = try? Data(contentsOf: pilotCredentialURL),
            let credential = try? decoder.decode(LocalPilotCredential.self, from: data),
            credential.account == account
        else { return nil }
        return credential.secret
    }

    private func saveSecret(_ secret: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let attributes = [kSecValueData as String: secret]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            try? fileManager.removeItem(at: pilotCredentialURL)
            return
        }
        if updateStatus == errSecMissingEntitlement {
            try savePilotCredential(secret, account: account)
            return
        }
        guard updateStatus == errSecItemNotFound else { throw CloudPairingError.keychain(updateStatus) }

        var insert = query
        insert[kSecValueData as String] = secret
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let insertStatus = SecItemAdd(insert as CFDictionary, nil)
        if insertStatus == errSecSuccess {
            try? fileManager.removeItem(at: pilotCredentialURL)
            return
        }
        if insertStatus == errSecMissingEntitlement {
            try savePilotCredential(secret, account: account)
            return
        }
        throw CloudPairingError.keychain(insertStatus)
    }

    private func savePilotCredential(_ secret: Data, account: String) throws {
        let credential = LocalPilotCredential(account: account, secret: secret)
        try JSONEncoder().encode(credential).write(to: pilotCredentialURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: pilotCredentialURL.path
        )
    }
}
