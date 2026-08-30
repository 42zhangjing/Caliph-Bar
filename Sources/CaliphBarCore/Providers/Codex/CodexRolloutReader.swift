import Foundation

public struct CodexRateLimits: Equatable, Sendable {
    public let primaryPercent: Double
    public let primaryResetsAt: Date?
    public let secondaryPercent: Double?
    public let secondaryResetsAt: Date?
    public let planType: String?

    public init(
        primaryPercent: Double,
        primaryResetsAt: Date?,
        secondaryPercent: Double?,
        secondaryResetsAt: Date?,
        planType: String?
    ) {
        self.primaryPercent = primaryPercent
        self.primaryResetsAt = primaryResetsAt
        self.secondaryPercent = secondaryPercent
        self.secondaryResetsAt = secondaryResetsAt
        self.planType = planType
    }
}

public enum CodexRateLimitParser {
    public static func parse(lineData: Data) -> CodexRateLimits? {
        guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let payload = object["payload"] as? [String: Any],
              let rateLimits = payload["rate_limits"] as? [String: Any],
              let primary = rateLimits["primary"] as? [String: Any],
              let primaryPercent = number(primary["used_percent"])
        else { return nil }

        let secondary = rateLimits["secondary"] as? [String: Any]
        return CodexRateLimits(
            primaryPercent: primaryPercent,
            primaryResetsAt: date(primary["resets_at"]),
            secondaryPercent: number(secondary?["used_percent"]),
            secondaryResetsAt: date(secondary?["resets_at"]),
            planType: rateLimits["plan_type"] as? String
        )
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double: return value
        case let value as Int: return Double(value)
        case let value as NSNumber: return value.doubleValue
        default: return nil
        }
    }

    private static func date(_ value: Any?) -> Date? {
        guard let seconds = number(value) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

public struct CodexRolloutReader: Sendable {
    private let tailLimit = 4 * 1024 * 1024

    public init() {}

    public func latestRateLimits() -> CodexRateLimits? {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return nil }
        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? URL(fileURLWithPath: home).appendingPathComponent(".codex")
        let sessions = codexHome.appendingPathComponent("sessions")
        guard let latest = mostRecentRollout(in: sessions) else { return nil }

        if let limits = parseTail(of: latest) { return limits }

        // Rare fallback: if the latest rate-limit event is older than the tail window,
        // stream the file without loading the whole rollout into memory.
        var last: CodexRateLimits?
        try? JSONLReader.forEachLine(at: latest) { line in
            if let parsed = CodexRateLimitParser.parse(lineData: line) { last = parsed }
        }
        return last
    }

    private func mostRecentRollout(in directory: URL) -> URL? {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var best: (url: URL, date: Date)?
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl", url.lastPathComponent.hasPrefix("rollout-") else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { continue }
            if best == nil || modified > best!.date { best = (url, modified) }
        }
        return best?.url
    }

    private func parseTail(of url: URL) -> CodexRateLimits? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let end = try? handle.seekToEnd() else { return nil }
        let start = end > UInt64(tailLimit) ? end - UInt64(tailLimit) : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd(), let data, !data.isEmpty else { return nil }

        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        for line in lines.reversed() {
            guard line.count > 20 else { continue }
            let lineData = Data(line)
            guard let text = String(data: lineData, encoding: .utf8), text.contains("\"rate_limits\"") else { continue }
            if let parsed = CodexRateLimitParser.parse(lineData: lineData) { return parsed }
        }
        return nil
    }
}
