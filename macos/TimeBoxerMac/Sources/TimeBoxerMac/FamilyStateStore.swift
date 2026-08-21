import Foundation

final class FamilyStateStore {
    let stateURL: URL
    let heartbeatURL: URL

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directory = directoryURL ?? applicationSupport.appendingPathComponent("TimeBoxer", isDirectory: true)
        stateURL = directory.appendingPathComponent("family-state.json")
        heartbeatURL = directory.appendingPathComponent("mac-heartbeat.json")

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("TimeBoxer could not prepare family state storage: %@", error.localizedDescription)
        }
    }

    func loadEnvelope() -> [String: Any]? {
        do {
            let data = try Data(contentsOf: stateURL)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            NSLog("TimeBoxer could not read family state: %@", error.localizedDescription)
            return nil
        }
    }

    var revision: Int {
        loadEnvelope()?["revision"] as? Int ?? 0
    }

    @discardableResult
    func save(state: [String: Any], sourceId: String) throws -> [String: Any] {
        guard JSONSerialization.isValidJSONObject(state) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        let envelope: [String: Any] = [
            "schemaVersion": 1,
            "revision": revision + 1,
            "updatedAt": Int64(Date().timeIntervalSince1970 * 1_000),
            "sourceId": sourceId,
            "state": state,
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: stateURL, options: .atomic)
        return envelope
    }

    func touchMacHeartbeat() {
        let heartbeat: [String: Any] = [
            "macHeartbeatAt": Int64(Date().timeIntervalSince1970 * 1_000),
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: heartbeat, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: heartbeatURL, options: .atomic)
        } catch {
            NSLog("TimeBoxer could not update device heartbeat: %@", error.localizedDescription)
        }
    }
}
