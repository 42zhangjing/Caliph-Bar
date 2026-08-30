import Foundation

public enum ProviderID: String, CaseIterable, Codable, Sendable {
    case claude
    case codex
    // Stable v0.1 raw id retained for cache/UserDefaults compatibility; the provider is now Antigravity-backed.
    case gemini

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Antigravity"
        }
    }
}

public enum UsageSourceKind: String, Codable, Sendable {
    case live
    case estimated
    case stale
    case unavailable
}

public struct UsageWindow: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let usedFraction: Double
    public let resetsAt: Date?

    public init(id: String, title: String, usedFraction: Double, resetsAt: Date?) {
        self.id = id
        self.title = title
        self.usedFraction = usedFraction
        self.resetsAt = resetsAt
    }

    public var remainingFraction: Double {
        max(0.0, min(1.0, 1.0 - usedFraction))
    }
}

public struct ProviderSnapshot: Identifiable, Codable, Equatable, Sendable {
    public var id: ProviderID { provider }
    public let provider: ProviderID
    public let source: UsageSourceKind
    public let sourceDetail: String
    public let planLabel: String?
    public let windows: [UsageWindow]
    public let capturedAt: Date
    public let note: String?

    public init(
        provider: ProviderID,
        source: UsageSourceKind,
        sourceDetail: String,
        planLabel: String? = nil,
        windows: [UsageWindow],
        capturedAt: Date = Date(),
        note: String? = nil
    ) {
        self.provider = provider
        self.source = source
        self.sourceDetail = sourceDetail
        self.planLabel = planLabel
        self.windows = windows
        self.capturedAt = capturedAt
        self.note = note
    }

    public var headlineFraction: Double? {
        windows.first?.usedFraction
    }

    public var headlineRemainingFraction: Double? {
        windows.first?.remainingFraction
    }

    public static func unavailable(provider: ProviderID, note: String) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            source: .unavailable,
            sourceDetail: "Unavailable",
            windows: [],
            note: note
        )
    }
}

public struct ProviderFetchContext: Sendable {
    public let claudeSessionBudget: Double
    public let claudeWeeklyBudget: Double

    public init(claudeSessionBudget: Double, claudeWeeklyBudget: Double) {
        self.claudeSessionBudget = claudeSessionBudget
        self.claudeWeeklyBudget = claudeWeeklyBudget
    }
}

public struct ProviderFetchResult: Sendable {
    public let provider: ProviderID
    public let liveSnapshot: ProviderSnapshot?
    public let fallbackSnapshot: ProviderSnapshot?
    public let errorDescription: String?

    public init(
        provider: ProviderID,
        liveSnapshot: ProviderSnapshot?,
        fallbackSnapshot: ProviderSnapshot? = nil,
        errorDescription: String? = nil
    ) {
        self.provider = provider
        self.liveSnapshot = liveSnapshot
        self.fallbackSnapshot = fallbackSnapshot
        self.errorDescription = errorDescription
    }
}
