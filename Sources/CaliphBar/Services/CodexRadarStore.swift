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

struct CodexRadarSnapshot: Codable, Equatable, Sendable {
    let windowOpen: Bool?
    let status: String?
    let recommendedAction: String?
    let message: String?
    let predictionLevel: String?
    let probability24h: Double?
    let probability48h: Double?
    let summary: String?
    let sourceURL: URL?
    let sourceUpdatedAt: Date?
    let fetchedAt: Date

    func signal(now: Date = Date()) -> CodexRadarSignal {
        let freshnessDate = sourceUpdatedAt ?? fetchedAt
        if now.timeIntervalSince(freshnessDate) > 2 * 60 * 60 {
            return .stale
        }

        if windowOpen == true { return .hot }

        let words = [status, predictionLevel, recommendedAction, summary]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if ["hot", "high", "strong", "confirmed", "open", "active"].contains(where: words.contains) {
            return .hot
        }
        if let probability24h, probability24h >= 0.65 { return .hot }

        if ["watch", "medium", "likely", "pending", "possible"].contains(where: words.contains) {
            return .watch
        }
        if let probability24h, probability24h >= 0.35 { return .watch }
        return .quiet
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
        static let cache = "caliphbar.codexRadar.cache.v1"
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
    private var timer: Timer?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Keys.cache),
           let cached = try? JSONDecoder().decode(CodexRadarSnapshot.self, from: data)
        {
            snapshot = cached
            signal = cached.signal()
        }

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    func refresh() {
        guard !isRefreshing else { return }
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
            }
        }
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
                content.body = snapshot.windowOpen == true
                    ? "检测到新的额度重置窗口信号。"
                    : "检测到高强度额度重置信号。"
            } else if let probability = snapshot.probability24h {
                content.body = "重置信号升至关注状态，24 小时概率 \(Int((probability * 100).rounded()))%。"
            } else {
                content.body = "重置信号升至关注状态。"
            }
        } else {
            content.body = current == .hot
                ? "A strong Codex reset signal was detected."
                : "Codex reset intelligence moved to WATCH."
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

private struct CodexRadarClient: Sendable {
    private let url = URL(string: "https://codexradar.com/current.json")!

    func fetch() async throws -> CodexRadarSnapshot {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CaliphBar/0.2 personal-macOS-client", forHTTPHeaderField: "User-Agent")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try CodexRadarParser.parse(data)
    }
}

private enum CodexRadarParser {
    static func parse(_ data: Data, fetchedAt: Date = Date()) throws -> CodexRadarSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        let window = dictionary(root["window"])
        let prediction = dictionary(root["prediction"])

        let windowOpen = bool(window?["open"] ?? root["window_open"] ?? root["windowOpen"])
        let status = string(window?["status"] ?? root["status"])
        let action = string(window?["action"] ?? root["recommended_action"] ?? root["recommendedAction"])
        let message = string(window?["message"] ?? root["message"])
        let predictionLevel = string(prediction?["level"] ?? root["prediction_level"])
        let probability24h = probability(prediction?["probability_24h"] ?? prediction?["probability24h"] ?? root["probability_24h"])
        let probability48h = probability(prediction?["probability_48h"] ?? prediction?["probability48h"] ?? root["probability_48h"])
        let summary = string(prediction?["summary"] ?? root["summary"])
        let sourceURL = string(window?["source_url"] ?? window?["sourceURL"] ?? root["source_url"])
            .flatMap(URL.init(string:))

        let updated = date(prediction?["updated_at"])
            ?? date(root["monitored_at"])
            ?? date(root["updated_at"])
            ?? date(window?["opened_at"])
            ?? date(window?["closed_at"])

        guard windowOpen != nil || status != nil || predictionLevel != nil || probability24h != nil || summary != nil else {
            throw URLError(.cannotParseResponse)
        }

        return CodexRadarSnapshot(
            windowOpen: windowOpen,
            status: status,
            recommendedAction: action,
            message: message,
            predictionLevel: predictionLevel,
            probability24h: probability24h,
            probability48h: probability48h,
            summary: summary,
            sourceURL: sourceURL,
            sourceUpdatedAt: updated,
            fetchedAt: fetchedAt
        )
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? { value as? [String: Any] }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool: return value
        case let value as NSNumber: return value.boolValue
        case let value as String:
            switch value.lowercased() {
            case "true", "1", "yes", "open", "active": return true
            case "false", "0", "no", "closed", "inactive": return false
            default: return nil
            }
        default: return nil
        }
    }

    private static func probability(_ value: Any?) -> Double? {
        let raw: Double?
        switch value {
        case let value as Double: raw = value
        case let value as Int: raw = Double(value)
        case let value as NSNumber: raw = value.doubleValue
        case let value as String: raw = Double(value.replacingOccurrences(of: "%", with: ""))
        default: raw = nil
        }
        guard var raw else { return nil }
        if raw > 1 { raw /= 100 }
        return min(1, max(0, raw))
    }

    private static func date(_ value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            return Date(timeIntervalSince1970: raw > 1_000_000_000_000 ? raw / 1000 : raw)
        }
        guard let raw = value as? String else { return nil }
        if let epoch = Double(raw) {
            return Date(timeIntervalSince1970: epoch > 1_000_000_000_000 ? epoch / 1000 : epoch)
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: raw)
    }
}
