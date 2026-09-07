import XCTest
@testable import TimeBoxerMac

final class EntertainmentClassificationTests: XCTestCase {
    func testRecognisesGenericAndSpecificGameCategories() {
        XCTAssertTrue(EntertainmentClassification.isGameCategory("public.app-category.games"))
        XCTAssertTrue(EntertainmentClassification.isGameCategory("public.app-category.board-games"))
        XCTAssertTrue(EntertainmentClassification.isGameCategory("public.app-category.strategy-games"))
        XCTAssertTrue(EntertainmentClassification.isGameCategory("public.app-category.role-playing-games"))
    }

    func testDoesNotTreatLearningAndProductivityCategoriesAsGames() {
        XCTAssertFalse(EntertainmentClassification.isGameCategory("public.app-category.education"))
        XCTAssertFalse(EntertainmentClassification.isGameCategory("public.app-category.productivity"))
        XCTAssertFalse(EntertainmentClassification.isGameCategory("public.app-category.developer-tools"))
    }

    func testRecommendsDetectedEntertainmentWithoutRecommendingProductivity() {
        XCTAssertTrue(InstalledApplicationScanner.isRecommendedEntertainment(
            bundleIdentifier: "com.example.game",
            category: "public.app-category.strategy-games"
        ))
        XCTAssertTrue(InstalledApplicationScanner.isRecommendedEntertainment(
            bundleIdentifier: "com.apple.TV",
            category: "public.app-category.video"
        ))
        XCTAssertFalse(InstalledApplicationScanner.isRecommendedEntertainment(
            bundleIdentifier: "us.zoom.xos",
            category: "public.app-category.video"
        ))
        XCTAssertFalse(InstalledApplicationScanner.isRecommendedEntertainment(
            bundleIdentifier: "com.apple.ImagePlayground",
            category: "public.app-category.entertainment"
        ))
        XCTAssertFalse(InstalledApplicationScanner.isRecommendedEntertainment(
            bundleIdentifier: "com.example.homework",
            category: "public.app-category.education"
        ))
    }

    func testApplicationInventoryHasStableBundleIdentifierTieBreak() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        for bundleIdentifier in ["com.example.zeta", "com.example.alpha"] {
            let contents = root
                .appendingPathComponent("\(bundleIdentifier).app", isDirectory: true)
                .appendingPathComponent("Contents", isDirectory: true)
            try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
            let info: [String: Any] = [
                "CFBundleIdentifier": bundleIdentifier,
                "CFBundleName": "Same name",
                "LSApplicationCategoryType": "public.app-category.productivity",
            ]
            let plist = try PropertyListSerialization.data(
                fromPropertyList: info,
                format: .xml,
                options: 0
            )
            try plist.write(to: contents.appendingPathComponent("Info.plist"))
        }

        let first = InstalledApplicationScanner.scan(directories: [root])
        let second = InstalledApplicationScanner.scan(directories: [root])
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.bundleIdentifier), ["com.example.alpha", "com.example.zeta"])
    }

    func testStandaloneProtectionUsesEveryDetectedRecommendedGame() {
        let applications = [
            InstalledApplicationRecord(
                bundleIdentifier: "com.example.game",
                name: "Example Game",
                category: "public.app-category.strategy-games",
                recommended: true
            ),
            InstalledApplicationRecord(
                bundleIdentifier: "com.example.homework",
                name: "Homework",
                category: "public.app-category.education",
                recommended: false
            ),
        ]

        XCTAssertEqual(
            InstalledApplicationScanner.recommendedBundleIdentifiers(in: applications),
            ["com.example.game"]
        )
    }
}
