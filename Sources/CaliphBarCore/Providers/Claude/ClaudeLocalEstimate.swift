import Foundation

public struct ClaudeLocalEstimator: Sendable {
    private struct Pricing {
        let input: Double
        let output: Double
        let cacheWrite5m: Double
        let cacheWrite1h: Double
        let cacheRead: Double
    }

    private static let opus = Pricing(input: 15/1e6, output: 75/1e6, cacheWrite5m: 18.75/1e6, cacheWrite1h: 30/1e6, cacheRead: 1.5/1e6)
    private static let sonnet = Pricing(input: 3/1e6, output: 15/1e6, cacheWrite5m: 3.75/1e6, cacheWrite1h: 6/1e6, cacheRead: 0.3/1e6)
    private static let haiku = Pricing(input: 0.8/1e6, output: 4/1e6, cacheWrite5m: 1/1e6, cacheWrite1h: 1.6/1e6, cacheRead: 0.08/1e6)

    public init() {}

    public func estimate(sessionBudget: Double, weeklyBudget: Double, now: Date = Date()) -> ProviderSnapshot? {
        let roots = projectRoots()
        guard !roots.isEmpty else { return nil }

        let weekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        var sessionCost = 0.0
        var weeklyCost = 0.0
        var earliestSession: Date?
        var earliestWeek: Date?
        var foundUsage = false

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "jsonl" else { continue }
                if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modified = values.contentModificationDate,
                   modified < weekAgo {
                    continue
                }

                try? JSONLReader.forEachLine(at: fileURL) { lineData in
                    guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          let timestampString = object["timestamp"] as? String,
                          let timestamp = formatter.date(from: timestampString),
                          timestamp >= weekAgo,
                          let message = object["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any]
                    else { return }

                    foundUsage = true
                    let pricing = Self.pricing(for: message["model"] as? String)
                    let input = Self.number(usage["input_tokens"])
                    let output = Self.number(usage["output_tokens"])
                    let cacheRead = Self.number(usage["cache_read_input_tokens"])
                    let creation = usage["cache_creation"] as? [String: Any]
                    let write5m = Self.number(creation?["ephemeral_5m_input_tokens"])
                    let write1h = Self.number(creation?["ephemeral_1h_input_tokens"])
                    let flatWrite = (write5m == 0 && write1h == 0) ? Self.number(usage["cache_creation_input_tokens"]) : 0

                    let cost = input * pricing.input
                        + output * pricing.output
                        + write5m * pricing.cacheWrite5m
                        + write1h * pricing.cacheWrite1h
                        + flatWrite * pricing.cacheWrite5m
                        + cacheRead * pricing.cacheRead

                    weeklyCost += cost
                    if earliestWeek == nil || timestamp < earliestWeek! { earliestWeek = timestamp }
                    if timestamp >= fiveHoursAgo {
                        sessionCost += cost
                        if earliestSession == nil || timestamp < earliestSession! { earliestSession = timestamp }
                    }
                }
            }
        }

        guard foundUsage else { return nil }
        let safeSessionBudget = max(sessionBudget, 1)
        let safeWeeklyBudget = max(weeklyBudget, 1)
        let sessionReset = (earliestSession ?? now).addingTimeInterval(5 * 3600)
        let weeklyReset = (earliestWeek ?? now).addingTimeInterval(7 * 24 * 3600)

        return ProviderSnapshot(
            provider: .claude,
            source: .estimated,
            sourceDetail: "Local cost estimate",
            windows: [
                UsageWindow(id: "session", title: "Current session", usedFraction: sessionCost / safeSessionBudget, resetsAt: sessionReset),
                UsageWindow(id: "weekly", title: "All models", usedFraction: weeklyCost / safeWeeklyBudget, resetsAt: weeklyReset),
            ],
            capturedAt: now,
            note: "Estimated from local Claude JSONL token costs; sign in with `claude login` for exact usage"
        )
    }

    private func projectRoots() -> [URL] {
        let fm = FileManager.default
        var roots: [URL] = []
        if let configured = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !configured.isEmpty {
            for entry in configured.split(separator: ",") {
                let root = URL(fileURLWithPath: String(entry)).expandingTildeInPath().appendingPathComponent("projects")
                if fm.fileExists(atPath: root.path) { roots.append(root) }
            }
        }
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            for relative in [".config/claude/projects", ".claude/projects"] {
                let root = URL(fileURLWithPath: home).appendingPathComponent(relative)
                if fm.fileExists(atPath: root.path), !roots.contains(root) { roots.append(root) }
            }
        }
        return roots
    }

    private static func pricing(for model: String?) -> Pricing {
        let value = (model ?? "").lowercased()
        if value.contains("opus") { return opus }
        if value.contains("haiku") { return haiku }
        return sonnet
    }

    private static func number(_ value: Any?) -> Double {
        switch value {
        case let value as Double: return value
        case let value as Int: return Double(value)
        case let value as NSNumber: return value.doubleValue
        default: return 0
        }
    }
}

private extension URL {
    func expandingTildeInPath() -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
}
