import Foundation

public struct ClaudeProvider: UsageProvider {
    public let id: ProviderID = .claude
    private let credentials = ClaudeCredentialLoader()
    private let oauth = ClaudeOAuthClient()
    private let estimator = ClaudeLocalEstimator()

    public init() {}

    public func fetch(context: ProviderFetchContext) async -> ProviderFetchResult {
        var failure: String?

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
