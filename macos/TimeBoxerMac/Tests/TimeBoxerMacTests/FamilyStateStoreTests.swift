import Foundation
import XCTest
@testable import TimeBoxerMac

final class FamilyStateStoreTests: XCTestCase {
    func testKnownDefaultPINIsNeverAcceptedForProtectionChanges() {
        XCTAssertFalse(ParentPINPolicy.isSecure(nil))
        XCTAssertFalse(ParentPINPolicy.isSecure("1234"))
        XCTAssertFalse(ParentPINPolicy.isSecure("abcd"))
        XCTAssertTrue(ParentPINPolicy.isSecure("2468"))
        XCTAssertTrue(ParentPINPolicy.isSecure("135790"))
    }

    func testSavesOneVersionedEnvelopeForBothClients() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("timeboxer-family-state-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FamilyStateStore(directoryURL: directory)
        let first = try store.save(
            state: ["availableMinutes": 5, "todaySpent": 0],
            sourceId: "parent-test"
        )
        let second = try store.save(
            state: ["availableMinutes": 5, "todaySpent": 10],
            sourceId: "child-test"
        )

        XCTAssertEqual(first["revision"] as? Int, 1)
        XCTAssertEqual(second["revision"] as? Int, 2)
        XCTAssertEqual(store.revision, 2)
        store.touchMacHeartbeat()
        let heartbeatData = try Data(contentsOf: store.heartbeatURL)
        let heartbeat = try JSONSerialization.jsonObject(with: heartbeatData) as? [String: Any]
        XCTAssertNotNil(heartbeat?["macHeartbeatAt"] as? NSNumber)
        let savedState = store.loadEnvelope()?["state"] as? [String: Any]
        XCTAssertEqual(savedState?["availableMinutes"] as? Int, 5)
        XCTAssertEqual(savedState?["todaySpent"] as? Int, 10)
    }

    func testReadsParentPINFromSharedFamilyState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("timeboxer-parent-pin-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FamilyStateStore(directoryURL: directory)
        _ = try store.save(
            state: ["availableMinutes": 25, "parentPIN": "2468"],
            sourceId: "parent-test"
        )

        XCTAssertEqual(store.parentPIN, "2468")
    }
}
