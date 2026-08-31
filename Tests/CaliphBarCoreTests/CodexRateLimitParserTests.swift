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
        #expect(parsed?.primaryWindowMinutes == 300)
        #expect(parsed?.secondaryPercent == 60)
        #expect(parsed?.secondaryWindowMinutes == 10_080)
        #expect(parsed?.planType == "plus")
        #expect(parsed?.primaryResetsAt != nil)
    }

    @Test func parsesLiveAppServerSnakeCasePayload() throws {
        let json = #"{"id":2,"result":{"rate_limits":{"primary":{"used_percent":12.5,"window_duration_mins":300,"resets_at":1788200000},"secondary":{"used_percent":35,"window_duration_mins":10080,"resets_at":1788600000},"plan_type":"pro"}}}"#
        let parsed = CodexAppServerRateLimitParser.parse(data: Data(json.utf8))
        #expect(parsed?.primaryPercent == 12.5)
        #expect(parsed?.primaryWindowMinutes == 300)
        #expect(parsed?.secondaryPercent == 35)
        #expect(parsed?.secondaryWindowMinutes == 10_080)
        #expect(parsed?.planType == "pro")
    }

    @Test func parsesAndSurfacesModelSpecificSparkBuckets() throws {
        let json = #"{"id":2,"result":{"rateLimits":{"limitId":"codex","limitName":"Codex","primary":{"usedPercent":0,"windowDurationMins":300,"resetsAt":1788200000},"secondary":{"usedPercent":60,"windowDurationMins":10080,"resetsAt":1788600000},"planType":"plus"},"rateLimitsByLimitId":{"codex":{"limitId":"codex","limitName":"Codex","primary":{"usedPercent":0,"windowDurationMins":300,"resetsAt":1788200000},"secondary":{"usedPercent":60,"windowDurationMins":10080,"resetsAt":1788600000},"planType":"plus"},"codex-spark":{"limitId":"codex-spark","limitName":"GPT-5.3-Codex-Spark","primary":{"usedPercent":10,"windowDurationMins":300,"resetsAt":1788210000},"secondary":{"usedPercent":25,"windowDurationMins":10080,"resetsAt":1788610000},"planType":"plus"}}}}"#

        let parsed = try #require(CodexAppServerRateLimitParser.parse(data: Data(json.utf8)))
        #expect(parsed.extraRateLimits.count == 1)
        #expect(parsed.extraRateLimits[0].id == "codex-spark")
        #expect(parsed.extraRateLimits[0].primaryPercent == 10)
        #expect(parsed.extraRateLimits[0].secondaryPercent == 25)

        let windows = CodexProvider.normalizedWindows(from: parsed)
        #expect(windows.map(\.id) == ["session", "weekly", "codex-spark-session", "codex-spark-weekly"])
        #expect(windows.map { Int(($0.remainingFraction * 100).rounded()) } == [100, 40, 90, 75])
    }

    @Test func mapsFiveHourAndWeeklyByDurationEvenWhenSlotsAreSwapped() {
        let limits = CodexRateLimits(
            primaryPercent: 60,
            primaryResetsAt: Date(timeIntervalSince1970: 1_788_600_000),
            primaryWindowMinutes: 10_080,
            secondaryPercent: 0,
            secondaryResetsAt: Date(timeIntervalSince1970: 1_788_200_000),
            secondaryWindowMinutes: 300,
            planType: "plus"
        )

        let windows = CodexProvider.normalizedWindows(from: limits)
        #expect(windows.map(\.id) == ["session", "weekly"])
        #expect(windows[0].usedFraction == 0)
        #expect(windows[1].usedFraction == 0.60)
    }

    @Test func legacyPayloadWithoutDurationsKeepsPrimarySecondaryFallback() {
        let limits = CodexRateLimits(
            primaryPercent: 25,
            primaryResetsAt: nil,
            secondaryPercent: 50,
            secondaryResetsAt: nil,
            planType: "plus"
        )

        let windows = CodexProvider.normalizedWindows(from: limits)
        #expect(windows.map(\.id) == ["session", "weekly"])
        #expect(windows[0].usedFraction == 0.25)
        #expect(windows[1].usedFraction == 0.50)
    }

    @Test func includesDesktopBundledCodexCandidates() {
        let candidates = CodexBundledCLIEnvironment.wellKnownCandidates(home: "/Users/tester")
        #expect(candidates.contains("/Applications/ChatGPT.app/Contents/Resources/codex"))
        #expect(candidates.contains("/Applications/Codex.app/Contents/Resources/codex"))
        #expect(candidates.contains("/Users/tester/Applications/ChatGPT.app/Contents/Resources/codex"))
        #expect(candidates.contains("/Users/tester/Applications/Codex.app/Contents/Resources/codex"))
    }
}
