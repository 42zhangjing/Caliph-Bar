import Foundation

public struct AntigravityProvider: UsageProvider {
    // Keep the existing stable provider id so v0.1 UserDefaults/cache entries continue to load.
    public let id: ProviderID = .gemini
    private let probe = AntigravityLocalProbe()

    public init() {}

    public func fetch(context _: ProviderFetchContext) async -> ProviderFetchResult {
        do {
            let result = try await probe.fetch()
            let snapshot = try Self.makeSnapshot(from: result.summary, sourceLabel: result.sourceLabel)
            return ProviderFetchResult(provider: id, liveSnapshot: snapshot)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return ProviderFetchResult(
                provider: id,
                liveSnapshot: nil,
                errorDescription: message
            )
        }
    }

    static func makeSnapshot(
        from summary: AntigravityQuotaSummary,
        sourceLabel: String = "Antigravity local quota summary"
    ) throws -> ProviderSnapshot {
        let candidates = summary.groups.flatMap { group in
            group.buckets.compactMap { bucket -> QuotaCandidate? in
                guard !bucket.disabled, let remaining = bucket.remainingFraction else { return nil }
                return QuotaCandidate(
                    family: family(for: group.displayName),
                    cadence: cadence(for: bucket),
                    usedFraction: max(0, min(1, 1 - remaining)),
                    resetsAt: bucket.resetsAt,
                    title: bucket.displayName
                )
            }
        }

        guard !candidates.isEmpty else {
            throw AntigravityProbeError.invalidPayload("No quota bucket contained a real remaining fraction")
        }

        var windows: [UsageWindow] = []
        let knownFamilies: [(Family, String, String)] = [
            (.gemini, "gemini", "Gemini"),
            (.claudeGPT, "claude-gpt", "Claude/GPT"),
        ]
        for (family, slug, label) in knownFamilies {
            let familyCandidates = candidates.filter { sameFamily($0.family, family) }
            if let session = mostConstrained(.session, in: familyCandidates) {
                windows.append(UsageWindow(
                    id: "antigravity-\(slug)-session",
                    title: "\(label) 5-hour",
                    usedFraction: session.usedFraction,
                    resetsAt: session.resetsAt
                ))
            }
            if let weekly = mostConstrained(.weekly, in: familyCandidates) {
                windows.append(UsageWindow(
                    id: "antigravity-\(slug)-weekly",
                    title: "\(label) Weekly",
                    usedFraction: weekly.usedFraction,
                    resetsAt: weekly.resetsAt
                ))
            }
        }

        // Future/unknown bucket names should still be useful without inventing a cadence.
        if windows.isEmpty, let fallback = candidates.max(by: { $0.usedFraction < $1.usedFraction }) {
            windows.append(UsageWindow(
                id: "quota",
                title: fallback.title,
                usedFraction: fallback.usedFraction,
                resetsAt: fallback.resetsAt
            ))
        }

        let drivers = [
            mostConstrained(.session, in: candidates).map { "5h=\($0.family.label)" },
            mostConstrained(.weekly, in: candidates).map { "weekly=\($0.family.label)" },
        ].compactMap { $0 }.joined(separator: ", ")

        return ProviderSnapshot(
            provider: .gemini,
            source: .live,
            sourceDetail: drivers.isEmpty ? sourceLabel : "\(sourceLabel) · \(drivers)",
            windows: windows,
            note: nil
        )
    }

    private enum Family: Sendable {
        case gemini
        case claudeGPT
        case other(String)

        var label: String {
            switch self {
            case .gemini: return "Gemini"
            case .claudeGPT: return "Claude/GPT"
            case let .other(value): return value
            }
        }
    }

    private enum Cadence: Sendable {
        case session
        case weekly
        case other
    }

    private struct QuotaCandidate: Sendable {
        let family: Family
        let cadence: Cadence
        let usedFraction: Double
        let resetsAt: Date?
        let title: String
    }

    private static func mostConstrained(_ cadence: Cadence, in candidates: [QuotaCandidate]) -> QuotaCandidate? {
        candidates
            .filter { sameCadence($0.cadence, cadence) }
            .max { lhs, rhs in lhs.usedFraction < rhs.usedFraction }
    }

    private static func sameCadence(_ lhs: Cadence, _ rhs: Cadence) -> Bool {
        switch (lhs, rhs) {
        case (.session, .session), (.weekly, .weekly), (.other, .other): return true
        default: return false
        }
    }

    private static func sameFamily(_ lhs: Family, _ rhs: Family) -> Bool {
        switch (lhs, rhs) {
        case (.gemini, .gemini), (.claudeGPT, .claudeGPT): return true
        case let (.other(lhs), .other(rhs)): return lhs == rhs
        default: return false
        }
    }

    private static func family(for displayName: String) -> Family {
        let lower = displayName.lowercased()
        if lower.contains("gemini") { return .gemini }
        if lower.contains("claude") || lower.contains("gpt") { return .claudeGPT }
        return .other(displayName)
    }

    private static func cadence(for bucket: AntigravityQuotaBucket) -> Cadence {
        let normalized = [bucket.id, bucket.displayName]
            .joined(separator: " ")
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        if normalized.contains("weekly") || normalized.contains("week") {
            return .weekly
        }
        if normalized.contains("5h") ||
            normalized.contains("5-hour") ||
            normalized.contains("five-hour") ||
            normalized.contains("five hour") ||
            normalized.contains("session") {
            return .session
        }
        return .other
    }
}
