import XCTest
@testable import CaliphBarCore

final class ModelTests: XCTestCase {
    func testHeadlineUsesFirstWindow() {
        let snapshot = ProviderSnapshot(
            provider: .codex,
            source: .live,
            sourceDetail: "test",
            windows: [UsageWindow(id: "session", title: "Session", usedFraction: 0.42, resetsAt: nil)]
        )
        XCTAssertEqual(snapshot.headlineFraction, 0.42)
    }
}
