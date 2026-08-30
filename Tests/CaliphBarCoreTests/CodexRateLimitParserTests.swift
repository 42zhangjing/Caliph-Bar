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

    @Test func parsesLiveAppServerCamelCasePayload() throws {
        let json = #"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":0,"windowDurationMins":300,"resetsAt":1788200000},"secondary":{"usedPercent":60,"windowDurationMins":10080,"resetsAt":1788600000},"planType":"plus"}}}"#
        let parsed = CodexAppServerRateLimitParser.parse(data: Data(json.utf8))
        #expect(parsed?.primaryPercent == 0)
        #expect(parsed?.secondaryPercent == 60)
        #expect(parsed?.planType == "plus")
        #expect(parsed?.primaryResetsAt != nil)
    }

    @Test func parsesLiveAppServerSnakeCasePayload() throws {
        let json = #"{"id":2,"result":{"rate_limits":{"primary":{"used_percent":12.5,"resets_at":1788200000},"secondary":{"used_percent":35,"resets_at":1788600000},"plan_type":"pro"}}}"#
        let parsed = CodexAppServerRateLimitParser.parse(data: Data(json.utf8))
        #expect(parsed?.primaryPercent == 12.5)
        #expect(parsed?.secondaryPercent == 35)
        #expect(parsed?.planType == "pro")
    }
}
