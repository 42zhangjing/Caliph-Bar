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
    static func normalizedWindows(
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

        var windows: [UsageWindow] = []
        let hasDurationMetadata = lanes.contains { $0.windowMinutes != nil }
        if hasDurationMetadata {
            if let session = lanes.first(where: { isFiveHour($0.windowMinutes) }),
               let window = makeWindow(session, id: "session", title: "Current session")
            {
                windows.append(window)
            }
            if let weekly = lanes.first(where: { isWeekly($0.windowMinutes) }),
               let window = makeWindow(weekly, id: "weekly", title: "Weekly limit")
            {
                windows.append(window)
            }
        } else {
            // Backward compatibility for historical rollout payloads that had no duration metadata.
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
        }

        // Current Codex app-server exposes a multi-bucket view keyed by metered limit id.
        // Model-specific buckets (for example Codex Spark) remain account truth and are
        // appended after the ordinary 5-hour / weekly lanes. Rollout fallback has no such data.
        if !discardExpired {
            for extra in limits.extraRateLimits {
                windows.append(contentsOf: extraWindows(from: extra))
            }
        }
        return windows
    }

    private static func extraWindows(from extra: CodexExtraRateLimit) -> [UsageWindow] {
        let label = extra.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseLabel = (label?.isEmpty == false ? label! : extra.id)
        let spark = [extra.id, label]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains("spark") }
        let slug = stableSlug(extra.id)

        var candidates: [(RawLane, Bool)] = []
        if let primary = extra.primaryPercent {
            candidates.append((RawLane(
                usedPercent: primary,
                resetsAt: extra.primaryResetsAt,
                windowMinutes: extra.primaryWindowMinutes
            ), true))
        }
        if let secondary = extra.secondaryPercent {
            candidates.append((RawLane(
                usedPercent: secondary,
                resetsAt: extra.secondaryResetsAt,
                windowMinutes: extra.secondaryWindowMinutes
            ), false))
        }

        return candidates.enumerated().map { index, candidate in
            let lane = candidate.0
            let primaryFallback = candidate.1
            let kind: String
            if isFiveHour(lane.windowMinutes) {
                kind = "session"
            } else if isWeekly(lane.windowMinutes) {
                kind = "weekly"
            } else {
                kind = primaryFallback ? "session" : "weekly"
            }

            let id: String
            let title: String
            if spark {
                if kind == "weekly" {
                    id = "codex-spark-weekly"
                    title = "Codex Spark Weekly"
                } else {
                    id = "codex-spark-session"
                    title = "Codex Spark 5-hour"
                }
            } else {
                id = "codex-extra-\(slug)-\(kind)-\(index)"
                title = kind == "weekly" ? "\(baseLabel) Weekly" : "\(baseLabel) 5-hour"
            }

            return UsageWindow(
                id: id,
                title: title,
                usedFraction: lane.usedPercent / 100.0,
                resetsAt: lane.resetsAt
            )
        }
    }

    private static func isFiveHour(_ minutes: Double?) -> Bool {
        guard let minutes else { return false }
        return abs(minutes - 300) < 0.5
    }

    private static func isWeekly(_ minutes: Double?) -> Bool {
        guard let minutes else { return false }
        return abs(minutes - 10_080) < 0.5
    }

    private static func stableSlug(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let raw = String(scalars)
        return raw
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
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
