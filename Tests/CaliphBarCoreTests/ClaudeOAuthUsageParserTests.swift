import XCTest
@testable import CaliphBarCore

final class ClaudeOAuthUsageParserTests: XCTestCase {
    func testParsesSessionWeeklyScopedAndPlan() throws {
        let json = #"{"five_hour":{"utilization":73,"resets_at":"2026-08-30T10:00:00Z"},"seven_day":{"utilization":7,"resets_at":"2026-09-03T00:00:00Z"},"limits":[{"kind":"weekly_scoped","percent":52,"resets_at":"2026-09-03T00:00:00Z","scope":{"model":{"display_name":"Fable"}}}]}"#
        let credentials = ClaudeCredentials(
            accessToken: "test",
            rateLimitTier: "default_claude_max_20x",
            subscriptionType: "max"
        )
        let snapshot = try ClaudeOAuthUsageParser.parse(
            data: Data(json.utf8),
            credentials: credentials,
            now: Date(timeIntervalSince1970: 1_788_000_000)
        )
        XCTAssertEqual(snapshot.source, .live)
        XCTAssertEqual(snapshot.planLabel, "Max 20x")
        XCTAssertEqual(snapshot.windows.count, 3)
        XCTAssertEqual(snapshot.windows[0].usedFraction, 0.73, accuracy: 0.0001)
        XCTAssertEqual(snapshot.windows[1].usedFraction, 0.07, accuracy: 0.0001)
        XCTAssertEqual(snapshot.windows[2].usedFraction, 0.52, accuracy: 0.0001)
    }
}
