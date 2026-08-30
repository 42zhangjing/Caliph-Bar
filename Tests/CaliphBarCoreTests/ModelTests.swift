import Foundation
import Testing
@testable import CaliphBarCore

@Suite struct ModelTests {
    @Test func headlineUsesFirstWindow() {
        let snapshot = ProviderSnapshot(
            provider: .codex,
            source: .live,
            sourceDetail: "test",
            windows: [UsageWindow(id: "session", title: "Session", usedFraction: 0.42, resetsAt: nil)]
        )
        #expect(snapshot.headlineFraction == 0.42)
    }
}
