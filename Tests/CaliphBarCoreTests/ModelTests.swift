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

    @Test func antigravityHeadlineUsesMostConstrainedVisibleFamily() {
        let snapshot = ProviderSnapshot(
            provider: .gemini,
            source: .live,
            sourceDetail: "test",
            windows: [
                UsageWindow(id: "antigravity-gemini-session", title: "Gemini 5-hour", usedFraction: 0.10, resetsAt: nil),
                UsageWindow(id: "antigravity-gemini-weekly", title: "Gemini Weekly", usedFraction: 0.88, resetsAt: nil),
                UsageWindow(id: "antigravity-claude-gpt-session", title: "Claude/GPT 5-hour", usedFraction: 0.30, resetsAt: nil),
            ]
        )
        #expect(snapshot.headlineRemainingFraction == 0.12)
    }
}
