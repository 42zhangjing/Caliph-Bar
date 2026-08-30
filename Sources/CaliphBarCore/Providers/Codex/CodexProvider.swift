import Foundation

public struct CodexProvider: UsageProvider {
    public let id: ProviderID = .codex
    private let reader = CodexRolloutReader()

    public init() {}

    public func fetch(context _: ProviderFetchContext) async -> ProviderFetchResult {
        guard let limits = reader.latestRateLimits() else {
            return ProviderFetchResult(
                provider: .codex,
                liveSnapshot: nil,
                errorDescription: "No recent Codex CLI rate-limit data found in ~/.codex/sessions."
            )
        }

        var windows = [
            UsageWindow(
                id: "session",
                title: "Current session",
                usedFraction: limits.primaryPercent / 100.0,
                resetsAt: limits.primaryResetsAt
            )
        ]
        if let secondary = limits.secondaryPercent {
            windows.append(UsageWindow(
                id: "weekly",
                title: "Weekly limit",
                usedFraction: secondary / 100.0,
                resetsAt: limits.secondaryResetsAt
            ))
        }

        let snapshot = ProviderSnapshot(
            provider: .codex,
            source: .live,
            sourceDetail: "Codex rollout rate_limits",
            planLabel: limits.planType,
            windows: windows,
            note: "Real rate-limit data written by Codex CLI; no estimation"
        )
        return ProviderFetchResult(provider: .codex, liveSnapshot: snapshot)
    }
}
