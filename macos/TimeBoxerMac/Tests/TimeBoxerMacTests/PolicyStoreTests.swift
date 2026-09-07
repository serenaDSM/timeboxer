import Foundation
import XCTest
@testable import TimeBoxerMac

final class PolicyStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeBoxerPolicyStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testRevokesPersistedPlayPermission() throws {
        let store = PolicyStore(directoryURL: temporaryDirectory)
        var policy = store.policy
        policy.activeEntertainmentUntil = Date().addingTimeInterval(1_200)
        try store.save(policy)

        XCTAssertTrue(try store.revokeActiveEntertainmentPermission())
        XCTAssertNil(store.policy.activeEntertainmentUntil)

        let reloadedStore = PolicyStore(directoryURL: temporaryDirectory)
        XCTAssertNil(reloadedStore.policy.activeEntertainmentUntil)
    }

    func testRevokingWithoutActivePlayIsANoOp() throws {
        let store = PolicyStore(directoryURL: temporaryDirectory)

        XCTAssertFalse(try store.revokeActiveEntertainmentPermission())
        XCTAssertNil(store.policy.activeEntertainmentUntil)
    }
}
