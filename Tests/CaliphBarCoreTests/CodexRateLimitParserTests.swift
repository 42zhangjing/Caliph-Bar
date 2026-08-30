import XCTest
@testable import CaliphBarCore

final class CodexRateLimitParserTests: XCTestCase {
    func testParsesPrimarySecondaryAndPlan() throws {
        let json = #"{"payload":{"rate_limits":{"primary":{"used_percent":21,"resets_at":1788100000},"secondary":{"used_percent":52.5,"resets_at":1788500000},"plan_type":"plus"}}}"#
        let parsed = CodexRateLimitParser.parse(lineData: Data(json.utf8))
        XCTAssertEqual(parsed?.primaryPercent, 21)
        XCTAssertEqual(parsed?.secondaryPercent, 52.5)
        XCTAssertEqual(parsed?.planType, "plus")
        XCTAssertNotNil(parsed?.primaryResetsAt)
        XCTAssertNotNil(parsed?.secondaryResetsAt)
    }
}
