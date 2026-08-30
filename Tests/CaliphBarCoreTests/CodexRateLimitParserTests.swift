import Foundation
import Testing
@testable import CaliphBarCore

@Suite struct CodexRateLimitParserTests {
    @Test func parsesPrimarySecondaryAndPlan() throws {
        let json = #"{"payload":{"rate_limits":{"primary":{"used_percent":21,"resets_at":1788100000},"secondary":{"used_percent":52.5,"resets_at":1788500000},"plan_type":"plus"}}}"#
        let parsed = CodexRateLimitParser.parse(lineData: Data(json.utf8))
        #expect(parsed?.primaryPercent == 21)
        #expect(parsed?.secondaryPercent == 52.5)
        #expect(parsed?.planType == "plus")
        #expect(parsed?.primaryResetsAt != nil)
        #expect(parsed?.secondaryResetsAt != nil)
    }
}
