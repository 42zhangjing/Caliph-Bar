import Foundation
import Testing
@testable import CaliphBarCore

@Suite struct ClaudeProviderTests {
    private let credentials = ClaudeCredentials(
        accessToken: "test", rateLimitTier: nil, subscriptionType: nil
    )

    @Test func credentialFailuresDoNotEstimateQuota() async {
        for error in [ClaudeCredentialError.notFound, .keychainInteractionRequired] {
            let result = await ClaudeProvider().fetch(credentials: .failure(error)) { _ in
                throw ClaudeOAuthError.invalidResponse
            }
            #expect(result.liveSnapshot == nil)
            #expect(result.fallbackSnapshot == nil)
            #expect(result.errorDescription == error.errorDescription)
        }
    }

    @Test func oauthFailureDoesNotEstimateQuota() async {
        for error in [ClaudeOAuthError.unauthorized, .serverStatus(429)] {
            let result = await ClaudeProvider().fetch(credentials: .success(credentials)) { _ in
                throw error
            }
            #expect(result.liveSnapshot == nil)
            #expect(result.fallbackSnapshot == nil)
            #expect(result.errorDescription == error.errorDescription)
        }
    }

    @Test func successfulOAuthPreservesLiveQuota() async {
        let snapshot = ProviderSnapshot(
            provider: .claude, source: .live, sourceDetail: "test",
            windows: [UsageWindow(id: "session", title: "Session", usedFraction: 0.25, resetsAt: nil)]
        )
        let result = await ClaudeProvider().fetch(credentials: .success(credentials)) { supplied in
            #expect(supplied.accessToken == "test")
            return snapshot
        }
        #expect(result.liveSnapshot == snapshot)
        #expect(result.liveSnapshot?.headlineRemainingFraction == 0.75)
        #expect(result.fallbackSnapshot == nil)
        #expect(result.errorDescription == nil)
    }
}
