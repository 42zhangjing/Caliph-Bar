import Foundation

public struct ClaudeProvider: UsageProvider {
    public let id: ProviderID = .claude
    private let credentials = ClaudeCredentialLoader()
    private let oauth = ClaudeOAuthClient()
    private let estimator = ClaudeLocalEstimator()

    public init() {}

    public func fetch(context: ProviderFetchContext) async -> ProviderFetchResult {
        var failure: String?
        var signedOut = false

        switch credentials.load(interactive: false) {
        case let .success(creds):
            do {
                let snapshot = try await oauth.fetch(credentials: creds)
                return ProviderFetchResult(provider: .claude, liveSnapshot: snapshot)
            } catch {
                failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        case let .failure(error):
            failure = error.errorDescription
            switch error {
            case .notFound, .missingOAuthPayload: signedOut = true
            default: break
            }
        }

        // Without Claude Code credentials the budget-based estimate is not
        // anchored to any real quota, so show "not signed in" instead of a
        // plausible-looking percentage.
        if signedOut {
            return ProviderFetchResult(
                provider: .claude,
                liveSnapshot: nil,
                errorDescription: failure ?? "Claude credentials were not found."
            )
        }

        let estimate = estimator.estimate(
            sessionBudget: context.claudeSessionBudget,
            weeklyBudget: context.claudeWeeklyBudget
        )
        return ProviderFetchResult(
            provider: .claude,
            liveSnapshot: nil,
            fallbackSnapshot: estimate,
            errorDescription: failure ?? "Claude live usage is unavailable."
        )
    }
}
