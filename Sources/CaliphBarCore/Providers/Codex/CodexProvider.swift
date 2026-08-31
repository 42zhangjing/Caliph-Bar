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

    private struct RawLane {
        let usedPercent: Double
        let resetsAt: Date?
        let windowMinutes: Double?
    }

    private static func snapshot(
        from limits: CodexRateLimits,
        source: UsageSourceKind,
        sourceDetail: String,
        note: String?
    ) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: .codex,
            source: source,
            sourceDetail: sourceDetail,
            planLabel: limits.planType,
            windows: normalizedWindows(from: limits),
            note: note
        )
    }

    /// `primary` and `secondary` are transport slots, not durable product names. Prefer the
    /// official `windowDurationMins` value when available so a future slot reordering cannot
    /// silently swap the 5-hour and weekly labels. Older rollout data often lacks duration,
    /// so only that legacy shape falls back to primary=session / secondary=weekly.
    private static func normalizedWindows(
        from limits: CodexRateLimits,
        now: Date? = nil,
        discardExpired: Bool = false
    ) -> [UsageWindow] {
        var lanes = [RawLane(
            usedPercent: limits.primaryPercent,
            resetsAt: limits.primaryResetsAt,
            windowMinutes: limits.primaryWindowMinutes
        )]
        if let secondary = limits.secondaryPercent {
            lanes.append(RawLane(
                usedPercent: secondary,
                resetsAt: limits.secondaryResetsAt,
                windowMinutes: limits.secondaryWindowMinutes
            ))
        }

        func isUsable(_ lane: RawLane) -> Bool {
            guard discardExpired, let now, let reset = lane.resetsAt else { return true }
            return reset > now
        }

        func makeWindow(_ lane: RawLane, id: String, title: String) -> UsageWindow? {
            guard isUsable(lane) else { return nil }
            return UsageWindow(
                id: id,
                title: title,
                usedFraction: lane.usedPercent / 100.0,
                resetsAt: lane.resetsAt
            )
        }

        let hasDurationMetadata = lanes.contains { $0.windowMinutes != nil }
        if hasDurationMetadata {
            var windows: [UsageWindow] = []
            if let session = lanes.first(where: { $0.windowMinutes.map { abs($0 - 300) < 0.5 } == true }),
               let window = makeWindow(session, id: "session", title: "Current session")
            {
                windows.append(window)
            }
            if let weekly = lanes.first(where: { $0.windowMinutes.map { abs($0 - 10_080) < 0.5 } == true }),
               let window = makeWindow(weekly, id: "weekly", title: "Weekly limit")
            {
                windows.append(window)
            }
            return windows
        }

        // Backward compatibility for historical rollout payloads that had no duration metadata.
        var windows: [UsageWindow] = []
        if let primary = lanes.first,
           let window = makeWindow(primary, id: "session", title: "Current session")
        {
            windows.append(window)
        }
        if lanes.count > 1,
           let window = makeWindow(lanes[1], id: "weekly", title: "Weekly limit")
        {
            windows.append(window)
        }
        return windows
    }

    private static func rolloutFallback(
        from limits: CodexRateLimits,
        rpcError: String,
        now: Date = Date()
    ) -> ProviderSnapshot? {
        let windows = normalizedWindows(from: limits, now: now, discardExpired: true)
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
