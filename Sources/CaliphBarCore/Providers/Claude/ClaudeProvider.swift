import Foundation

public struct ClaudeProvider: UsageProvider {
    public let id: ProviderID = .claude
    private let credentials = ClaudeCredentialLoader()
    private let oauth = ClaudeOAuthClient()

    public init() {}

    public func fetch(context: ProviderFetchContext) async -> ProviderFetchResult {
        await fetch(credentials: credentials.load(interactive: false)) {
            try await oauth.fetch(credentials: $0)
        }
    }

    func fetch(
        credentials: Result<ClaudeCredentials, ClaudeCredentialError>,
        fetchUsage: (ClaudeCredentials) async throws -> ProviderSnapshot
    ) async -> ProviderFetchResult {
        var failure: String?

        switch credentials {
        case let .success(creds):
            do {
                let snapshot = try await fetchUsage(creds)
                return ProviderFetchResult(provider: .claude, liveSnapshot: snapshot)
            } catch {
                failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        case let .failure(error):
            failure = error.errorDescription
        }

        return ProviderFetchResult(
            provider: .claude,
            liveSnapshot: nil,
            errorDescription: failure ?? "Claude live usage is unavailable."
        )
    }
}
