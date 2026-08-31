import Foundation

public struct CodexProvider: UsageProvider {
    public let id: ProviderID = .codex
    private let rpc = CodexAppServerProbe()
    private let reader = CodexRolloutReader()

    public init() {
        // Menu-bar apps often do not inherit the shell PATH that contains `codex`.
        // If ChatGPT/Codex desktop bundles the official executable, expose that exact
        // local binary to the existing app-server probe without touching user auth.
        CodexBundledCLIEnvironment.installOverrideIfNeeded()
    }

    public func fetch(context _: ProviderFetchContext) async -> ProviderFetchResult {
        do {
            let limits = try await rpc.fetchRateLimits()
            return ProviderFetchResult(
                provider: .codex,
                liveSnapshot: Self.snapshot(
                    from: limits,
                    source: .live,
                    sourceDetail: "Codex app-server account/rateLimits/read",
                    note: "Live quota read from the official local Codex CLI"
                )
            )
        } catch {
            let rpcError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

            // Rollout JSONL remains a local fallback, but it is a historical observation rather
            // than a live query. Never label an expired rollout window as LIVE: that was the bug
            // that could leave CaliphBar showing an old 15% after Codex had already reset to 100%.
            if let limits = reader.latestRateLimits(),
               let fallback = Self.rolloutFallback(from: limits, rpcError: rpcError)
            {
                return ProviderFetchResult(
                    provider: .codex,
                    liveSnapshot: nil,
                    fallbackSnapshot: fallback,
                    errorDescription: rpcError
                )
            }

            return ProviderFetchResult(
                provider: .codex,
                liveSnapshot: nil,
                errorDescription: rpcError
            )
        }
    }

    private static func snapshot(
        from limits: CodexRateLimits,
        source: UsageSourceKind,
        sourceDetail: String,
        note: String?
    ) -> ProviderSnapshot {
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

        return ProviderSnapshot(
            provider: .codex,
            source: source,
            sourceDetail: sourceDetail,
            planLabel: limits.planType,
            windows: windows,
            note: note
        )
    }

    private static func rolloutFallback(
        from limits: CodexRateLimits,
        rpcError: String,
        now: Date = Date()
    ) -> ProviderSnapshot? {
        var windows: [UsageWindow] = []

        // If a reset timestamp is already in the past, its percentage belongs to the previous
        // window and must not be displayed as the current quota. Keep only still-valid lanes.
        if limits.primaryResetsAt.map({ $0 > now }) ?? true {
            windows.append(UsageWindow(
                id: "session",
                title: "Current session",
                usedFraction: limits.primaryPercent / 100.0,
                resetsAt: limits.primaryResetsAt
            ))
        }

        if let secondary = limits.secondaryPercent,
           limits.secondaryResetsAt.map({ $0 > now }) ?? true
        {
            windows.append(UsageWindow(
                id: "weekly",
                title: "Weekly limit",
                usedFraction: secondary / 100.0,
                resetsAt: limits.secondaryResetsAt
            ))
        }

        guard !windows.isEmpty else { return nil }
        return ProviderSnapshot(
            provider: .codex,
            source: .stale,
            sourceDetail: "Codex rollout fallback",
            planLabel: limits.planType,
            windows: windows,
            note: "Live Codex RPC unavailable; showing only unexpired local rollout data. \(rpcError)"
        )
    }
}
