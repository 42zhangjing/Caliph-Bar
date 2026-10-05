import Foundation

/// Public AIHOT events only; never account quota or a prediction of the next reset.
public struct AIHotResetFeed: Codable, Sendable {
    public let schemaVersion: Int
    public let checkedAt: Date?
    public let events: [AIHotResetEvent]
    public let monitor: Monitor?

    public struct Monitor: Codable, Sendable {
        public let status: String
        public let lastVerifiedAt: Date?
    }

    public var verifiedAt: Date? { checkedAt ?? monitor?.lastVerifiedAt }

    public var selectedEvent: AIHotResetEvent? {
        // Pending direct resets take priority. Card grants remain a separate event kind.
        let sorted = events.filter { ["direct_reset", "reset_credit"].contains($0.type) && ["announced", "confirmed"].contains($0.status) }.sorted { $0.updatedAt > $1.updatedAt }
        return sorted.first { $0.type == "direct_reset" && $0.status == "announced" }
            ?? sorted.first { $0.type == "direct_reset" }
            ?? sorted.first
    }

    public static func parse(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: raw) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid source timestamp"))
            }
            return date
        }
        let feed = try decoder.decode(Self.self, from: data)
        guard feed.schemaVersion == 1 else { throw URLError(.cannotParseResponse) }
        return feed
    }
}

public struct AIHotResetEvent: Codable, Equatable, Sendable {
    public let id: String
    public let type: String
    public let status: String
    public let updatedAt: Date
    public let confirmedAt: Date?
    public let displayLabel: String?
    public let scope: String?
    public let presentation: Presentation?
    public let estimate: Estimate?
    public let schedule: Schedule?
    public let url: URL?

    public struct Presentation: Codable, Equatable, Sendable {
        public let status: String
        public let scopeKnown: Bool?
        public let scopeLabel: String?
    }
    public struct Estimate: Codable, Equatable, Sendable {
        public let through: Date
        public let basis: String
    }
    public struct Schedule: Codable, Equatable, Sendable {
        public let through: Date
    }

    public var displayStatus: String { presentation?.status ?? status }
    public var isConfirmed: Bool { status == "confirmed" }
    public var isDirectReset: Bool { type == "direct_reset" }
    public var target: Date? { isConfirmed ? nil : (estimate?.through ?? schedule?.through) }

    public func headline(isChinese: Bool) -> String {
        let kind = isDirectReset ? (isChinese ? "额度重置" : "Quota reset") : (isChinese ? "重置卡发放" : "Reset credits")
        switch displayStatus {
        case "confirmed": return isChinese ? "\(kind)已确认" : "\(kind) confirmed"
        case "in_progress": return isChinese ? "\(kind)进行中" : "\(kind) in progress"
        case "expired_unconfirmed": return isChinese ? "\(kind)等待确认" : "\(kind) awaiting confirmation"
        case "likely_completed": return isChinese ? "\(kind)应已生效 · 未确认" : "\(kind) likely landed · unconfirmed"
        case "announced": return isChinese ? "\(kind)已宣布" : "\(kind) announced"
        default: return isChinese ? "\(kind)状态未知" : "\(kind) status unknown"
        }
    }

    public func detail(isChinese: Bool) -> String {
        if isConfirmed {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            formatter.dateFormat = "MM/dd HH:mm"
            let time = confirmedAt.map { formatter.string(from: $0) } ?? "—"
            return isChinese ? "确认帖：\(time)（北京时间）；不代表个人到账时间。" : "Confirmed post: \(time) (UTC+8); not your account arrival time."
        }
        if target != nil {
            return isChinese ? "AIHOT 预计窗口，尚无完成确认；个人额度以本机读取为准。" : "AIHOT estimated window, not confirmed; check local account quota."
        }
        return isChinese ? "已宣布，生效时间未知；个人额度以本机读取为准。" : "Announced, arrival time unknown; check local account quota."
    }
}
