import Foundation
import Combine
import UserNotifications
import CaliphBarCore

enum CodexRadarSignal: String, Codable, Sendable {
    case quiet
    case watch
    case hot
    case stale
    case offline

    var rank: Int {
        switch self {
        case .offline, .stale, .quiet: return 0
        case .watch: return 1
        case .hot: return 2
        }
    }
}

struct CodexRadarAnnouncement: Codable, Equatable, Sendable {
    let headline: String
    let lead: String?
    let detail: String?
    let closesAt: Date?
    let expiredText: String?
    let sourceURL: URL?

    init(
        headline: String,
        lead: String? = nil,
        detail: String? = nil,
        closesAt: Date? = nil,
        expiredText: String? = nil,
        sourceURL: URL? = nil
    ) {
        self.headline = headline
        self.lead = lead
        self.detail = detail
        self.closesAt = closesAt
        self.expiredText = expiredText
        self.sourceURL = sourceURL
    }
}

struct CodexRadarSnapshot: Codable, Equatable, Sendable {
    let windowOpen: Bool?
    let status: String?
    let recommendedAction: String?
    let message: String?
    let windowTitle: String?
    let windowScope: String?
    let openedAt: Date?
    let predictionLevel: String?
    let probability24h: Double?
    let probability48h: Double?
    let summary: String?
    let closedAt: Date?
    let sourceURL: URL?
    let sourceUpdatedAt: Date?
    let fetchedAt: Date
    let announcement: CodexRadarAnnouncement?

    var event: AIHotResetEvent? = nil
    var monitorStatus: String? = nil

    func signal(now: Date = Date()) -> CodexRadarSignal {
        // Verification age takes precedence, even for a previously active announcement.
        guard let verified = sourceUpdatedAt,
              now.timeIntervalSince(verified) <= 2 * 60 * 60,
              now.timeIntervalSince(fetchedAt) <= 2 * 60 * 60 else { return .stale }
        if monitorStatus == "delayed" || monitorStatus == "attention" || monitorStatus == "unknown" { return .stale }
        guard let event, event.isDirectReset else { return .quiet }
        switch event.displayStatus {
        case "in_progress": return .hot
        case "announced", "expired_unconfirmed", "likely_completed": return .watch
        default: return .quiet
        }
    }

}

struct CodexLocalResetConfirmation: Codable, Equatable, Sendable {
    enum Lane: String, Codable, Sendable { case session, weekly }

    let lane: Lane
    let beforeRemaining: Double
    let afterRemaining: Double
    let observedAt: Date
}

@MainActor
final class CodexRadarStore: ObservableObject {
    static let shared = CodexRadarStore()

    @Published private(set) var snapshot: CodexRadarSnapshot?
    @Published private(set) var signal: CodexRadarSignal = .offline
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var localConfirmation: CodexLocalResetConfirmation?

    private enum Keys {
        static let cache = "caliphbar.codexRadar.aihot.cache.v1"
        static let lastSignal = "caliphbar.codexRadar.lastSignal.v1"
        static let hasSeenSignal = "caliphbar.codexRadar.hasSeenSignal.v1"
        static let codexObservation = "caliphbar.codexRadar.codexObservation.v1"
        static let notifications = "caliphbar.notificationsEnabled"
    }

    private struct CodexObservation: Codable {
        let sessionRemaining: Double?
        let weeklyRemaining: Double?
        let sessionReset: Date?
        let weeklyReset: Date?
        let observedAt: Date
    }

    private let client = CodexRadarClient()
    private var lastAttemptAt: Date?
    private var timer: Timer?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Keys.cache),
           let cached = try? JSONDecoder().decode(CodexRadarSnapshot.self, from: data)
        {
            snapshot = cached
            signal = cached.signal()
        }

        refresh()
        rescheduleTimer()
    }

    deinit { timer?.invalidate() }

    func refresh() {
        guard !isRefreshing else { return }
        // Respect AIHOT's documented ten-minute polling interval, including UI refreshes.
        if let lastAttemptAt, Date().timeIntervalSince(lastAttemptAt) < 10 * 60 { return }
        lastAttemptAt = Date()
        isRefreshing = true

        Task {
            do {
                let fresh = try await client.fetch()
                apply(fresh)
            } catch {
                lastError = error.localizedDescription
                isRefreshing = false
                if let snapshot {
                    signal = snapshot.signal()
                } else {
                    signal = .offline
                }
                rescheduleTimer()
            }
        }
    }

    func refreshIfNeeded(olderThan: TimeInterval = 10 * 60) {
        guard !isRefreshing else { return }
        if let fetchedAt = snapshot?.fetchedAt, Date().timeIntervalSince(fetchedAt) < olderThan {
            return
        }
        refresh()
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    /// Correlates a public Radar event with a real local Codex quota discontinuity.
    /// Nothing is uploaded; only a tiny percentage/reset-timestamp record is kept locally.
    func observeCodex(_ snapshot: ProviderSnapshot) {
        guard snapshot.provider == .codex, snapshot.source == .live else { return }

        let session = snapshot.windows.first(where: { $0.id == "session" })
        let weekly = snapshot.windows.first(where: { $0.id == "weekly" })
        let current = CodexObservation(
            sessionRemaining: session?.remainingFraction,
            weeklyRemaining: weekly?.remainingFraction,
            sessionReset: session?.resetsAt,
            weeklyReset: weekly?.resetsAt,
            observedAt: Date()
        )

        if let data = UserDefaults.standard.data(forKey: Keys.codexObservation),
           let previous = try? JSONDecoder().decode(CodexObservation.self, from: data),
           Date().timeIntervalSince(previous.observedAt) < 12 * 60 * 60
        {
            if let confirmation = Self.detectReset(previous: previous, current: current) {
                localConfirmation = confirmation
            }
        }

        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: Keys.codexObservation)
        }
    }

    private func apply(_ fresh: CodexRadarSnapshot) {
        let previousSignal = signal
        snapshot = fresh
        signal = fresh.signal()
        lastError = nil
        isRefreshing = false

        if let data = try? JSONEncoder().encode(fresh) {
            UserDefaults.standard.set(data, forKey: Keys.cache)
        }
        notifyIfNeeded(previous: previousSignal, current: signal, snapshot: fresh)
        rescheduleTimer()
    }

    private func notifyIfNeeded(
        previous: CodexRadarSignal,
        current: CodexRadarSignal,
        snapshot: CodexRadarSnapshot
    ) {
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? true
        guard notificationsEnabled else { return }

        if !defaults.bool(forKey: Keys.hasSeenSignal) {
            defaults.set(true, forKey: Keys.hasSeenSignal)
            defaults.set(current.rawValue, forKey: Keys.lastSignal)
            return
        }

        let persisted = defaults.string(forKey: Keys.lastSignal).flatMap(CodexRadarSignal.init(rawValue:)) ?? previous
        defaults.set(current.rawValue, forKey: Keys.lastSignal)
        guard current.rank > persisted.rank, current == .watch || current == .hot else { return }
        guard Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        let l10n = L10n.shared
        content.title = "Codex Reset Radar"
        if l10n.isChinese {
            if current == .hot {
                if let ann = snapshot.announcement {
                    content.body = "\(ann.headline)：\(ann.lead ?? ann.detail ?? "官方重置窗口开启")"
                } else if snapshot.windowOpen == true {
                    content.body = "检测到新的额度重置窗口信号。"
                } else {
                    content.body = "检测到高强度额度重置信号。"
                }
            } else if let probability = snapshot.probability24h {
                content.body = "重置信号升至关注状态，24 小时概率 \(Int((probability * 100).rounded()))%。"
            } else {
                content.body = "重置信号升至关注状态。"
            }
        } else {
            if current == .hot {
                if let ann = snapshot.announcement {
                    content.body = "\(ann.headline) - \(ann.lead ?? "Reset window active")"
                } else {
                    content.body = snapshot.windowOpen == true
                        ? "A new Codex quota reset window was detected."
                        : "A strong Codex reset signal was detected."
                }
            } else {
                content.body = "Codex reset intelligence moved to WATCH."
            }
        }
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "codex-radar-\(current.rawValue)-\(Int(snapshot.fetchedAt.timeIntervalSince1970))",
                content: content,
                trigger: nil
            )
        )
    }

    private static func detectReset(
        previous: CodexObservation,
        current: CodexObservation
    ) -> CodexLocalResetConfirmation? {
        func confirmed(
            before: Double?,
            after: Double?,
            previousReset: Date?,
            currentReset: Date?,
            lane: CodexLocalResetConfirmation.Lane
        ) -> CodexLocalResetConfirmation? {
            guard let before, let after else { return nil }
            let jump = after - before
            guard jump >= 0.55, after >= 0.80 else { return nil }

            // A changed reset boundary is strong corroboration. If the old reset was already
            // crossed, also accept the large jump even when the new source omits a reset date.
            let boundaryChanged = previousReset != currentReset
            let crossedOldBoundary = previousReset.map { $0 <= current.observedAt } ?? false
            guard boundaryChanged || crossedOldBoundary else { return nil }

            return CodexLocalResetConfirmation(
                lane: lane,
                beforeRemaining: before,
                afterRemaining: after,
                observedAt: current.observedAt
            )
        }

        if let weekly = confirmed(
            before: previous.weeklyRemaining,
            after: current.weeklyRemaining,
            previousReset: previous.weeklyReset,
            currentReset: current.weeklyReset,
            lane: .weekly
        ) { return weekly }

        return confirmed(
            before: previous.sessionRemaining,
            after: current.sessionRemaining,
            previousReset: previous.sessionReset,
            currentReset: current.sessionReset,
            lane: .session
        )
    }
}

private actor CodexRadarClient {
    private let jsonURL = URL(string: "https://aihot.news/api/v1/codex-resets/recent")!
    private var etag: String?
    private var cachedFeed: AIHotResetFeed?
    private var retryAfter: Date?

    func fetch() async throws -> CodexRadarSnapshot {
        if let retryAfter, retryAfter > Date() { throw URLError(.resourceUnavailable) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: jsonURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("aihot-api/2.0.0 CaliphBar", forHTTPHeaderField: "User-Agent")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 429 || http.statusCode == 503 {
            let delay = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 600
            retryAfter = Date().addingTimeInterval(max(600, delay))
        }
        let feed: AIHotResetFeed
        if http.statusCode == 304, let cachedFeed {
            feed = cachedFeed
        } else {
            guard http.statusCode == 200, data.count <= 2_097_152 else { throw URLError(.badServerResponse) }
            feed = try AIHotResetFeed.parse(data)
            cachedFeed = feed
            etag = http.value(forHTTPHeaderField: "ETag")
        }
        // A 304 updates fetch time, never the source verification watermark.
        let event = feed.selectedEvent
        var result = CodexRadarSnapshot(
            windowOpen: event?.isDirectReset == true && event?.status == "announced",
            status: event?.displayStatus, recommendedAction: nil, message: nil,
            windowTitle: nil, windowScope: nil, openedAt: nil, predictionLevel: nil,
            probability24h: nil, probability48h: nil, summary: nil, closedAt: nil,
            sourceURL: URL(string: "https://aihot.news/codex-reset"),
            sourceUpdatedAt: feed.verifiedAt, fetchedAt: Date(), announcement: nil
        )
        result.event = event
        result.monitorStatus = feed.monitor?.status
        return result
    }
}
