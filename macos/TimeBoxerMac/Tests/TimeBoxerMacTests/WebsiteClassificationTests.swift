import XCTest
@testable import TimeBoxerMac

final class WebsiteClassificationTests: XCTestCase {
    func testExtractsAndNormalisesHosts() {
        XCTAssertEqual(
            WebsiteClassification.host(from: "https://www.youtube.com/watch?v=example"),
            "youtube.com"
        )
        XCTAssertEqual(
            WebsiteClassification.host(from: "https://space.bilibili.com/123"),
            "space.bilibili.com"
        )
        XCTAssertEqual(WebsiteClassification.host(from: "chrome://newtab"), "newtab")
        XCTAssertFalse(WebsiteClassification.isRestrictedHost("newtab"))
    }

    func testRestrictsVideoAndWebGameDomainsIncludingSubdomains() {
        XCTAssertTrue(WebsiteClassification.isRestrictedHost("youtube.com"))
        XCTAssertTrue(WebsiteClassification.isRestrictedHost("m.youtube.com"))
        XCTAssertTrue(WebsiteClassification.isRestrictedHost("youtu.be"))
        XCTAssertTrue(WebsiteClassification.isRestrictedHost("www.youtube-nocookie.com"))
        XCTAssertTrue(WebsiteClassification.isRestrictedHost("www.poki.com"))
        XCTAssertTrue(WebsiteClassification.isRestrictedHost("space.bilibili.com"))
    }

    func testAllowsHomeworkAndProductivityDomains() {
        XCTAssertFalse(WebsiteClassification.isRestrictedHost("docs.google.com"))
        XCTAssertFalse(WebsiteClassification.isRestrictedHost("education.govt.nz"))
        XCTAssertFalse(WebsiteClassification.isRestrictedHost("youtube.com.example.org"))
    }

    func testParentSelectionControlsWhichDomainsAreRestricted() {
        let parentSelection: Set<String> = ["poki.com"]

        XCTAssertTrue(WebsiteClassification.isRestrictedHost(
            "www.poki.com",
            restrictedDomains: parentSelection
        ))
        XCTAssertFalse(WebsiteClassification.isRestrictedHost(
            "youtube.com",
            restrictedDomains: parentSelection
        ))
    }

    func testUsesSafeReplacementPagesForSupportedBrowsers() {
        XCTAssertEqual(
            WebsiteClassification.safeReplacementURL(for: "com.google.Chrome"),
            "chrome://newtab/"
        )
        XCTAssertEqual(
            WebsiteClassification.safeReplacementURL(for: "com.apple.Safari"),
            "about:blank"
        )
        XCTAssertNil(WebsiteClassification.safeReplacementURL(for: "com.example.browser"))
    }
}
