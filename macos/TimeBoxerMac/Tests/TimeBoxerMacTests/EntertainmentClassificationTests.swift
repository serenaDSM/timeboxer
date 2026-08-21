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
}
