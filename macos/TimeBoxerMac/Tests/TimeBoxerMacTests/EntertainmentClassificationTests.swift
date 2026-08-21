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
}
