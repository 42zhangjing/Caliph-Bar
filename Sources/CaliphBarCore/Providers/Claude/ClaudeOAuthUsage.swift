import Foundation

public enum ClaudeOAuthError: Error, LocalizedError, Sendable {
    case invalidResponse
    case unauthorized
    case serverStatus(Int)
    case malformedPayload

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Anthropic usage request returned an invalid response."
        case .unauthorized: return "Claude OAuth token is expired or unauthorized. Run `claude login`."
        case let .serverStatus(status): return "Anthropic usage API returned HTTP \(status)."
        case .malformedPayload: return "Anthropic usage payload did not contain expected quota windows."
        }
    }
}

public enum ClaudeOAuthUsageParser {
    public static func parse(data: Data, credentials: ClaudeCredentials, now: Date = Date()) throws -> ProviderSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeOAuthError.malformedPayload
        }

        var windows: [UsageWindow] = []
        if let session = parseWindow(root["five_hour"], id: "session", title: "Current session") {
            windows.append(session)
        }
        if let weekly = parseWindow(root["seven_day"], id: "weekly", title: "All models") {
            windows.append(weekly)
        }

        if let limits = root["limits"] as? [[String: Any]] {
            for (index, limit) in limits.enumerated() {
                guard (limit["kind"] as? String) == "weekly_scoped",
                      let percent = number(limit["percent"]),
                      let scope = limit["scope"] as? [String: Any],
                      let model = scope["model"] as? [String: Any]
                else { continue }

                let display = (model["display_name"] as? String)
                    ?? (model["id"] as? String)
                    ?? "Model"
                let reset = (limit["resets_at"] as? String).flatMap(parseDate)
                windows.append(UsageWindow(
                    id: "weekly-scoped-\(index)-\(display.lowercased().replacingOccurrences(of: " ", with: "-"))",
                    title: "\(display) weekly",
                    usedFraction: percent / 100.0,
                    resetsAt: reset
                ))
            }
        }

        guard !windows.isEmpty else { throw ClaudeOAuthError.malformedPayload }

        return ProviderSnapshot(
            provider: .claude,
            source: .live,
            sourceDetail: "Anthropic OAuth API",
            planLabel: planLabel(credentials: credentials),
            windows: windows,
            capturedAt: now,
            note: "Live usage from your Claude account"
        )
    }

    private static func parseWindow(_ value: Any?, id: String, title: String) -> UsageWindow? {
        guard let object = value as? [String: Any], let utilization = number(object["utilization"]) else {
            return nil
        }
        let reset = (object["resets_at"] as? String).flatMap(parseDate)
        return UsageWindow(id: id, title: title, usedFraction: utilization / 100.0, resetsAt: reset)
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double: return value
        case let value as Int: return Double(value)
        case let value as NSNumber: return value.doubleValue
        default: return nil
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func planLabel(credentials: ClaudeCredentials) -> String? {
        func words(_ string: String?) -> [String] {
            (string ?? "").lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        }

        func base(_ string: String?) -> String? {
            let values = words(string)
            if values.contains("max") { return "Max" }
            if values.contains("pro") { return "Pro" }
            if values.contains("team") { return "Team" }
            if values.contains("enterprise") { return "Enterprise" }
            if values.contains("ultra") { return "Ultra" }
            return nil
        }

        guard let plan = base(credentials.subscriptionType) ?? base(credentials.rateLimitTier) else { return nil }
        guard plan == "Max" else { return plan }

        let tierWords = words(credentials.rateLimitTier)
        if let maxIndex = tierWords.firstIndex(of: "max"), tierWords.indices.contains(maxIndex + 1) {
            let multiplier = tierWords[maxIndex + 1]
            if multiplier.hasSuffix("x"), Int(multiplier.dropLast()) != nil {
                return "Max \(multiplier)"
            }
        }
        return plan
    }
}

public struct ClaudeOAuthClient: Sendable {
    public init() {}

    public func fetch(credentials: ClaudeCredentials) async throws -> ProviderSnapshot {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw ClaudeOAuthError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        // Keep parity with Claude Code's known-working OAuth usage request surface.
        request.setValue("claude-code/2.1.233", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeOAuthError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw ClaudeOAuthError.unauthorized
        default: throw ClaudeOAuthError.serverStatus(http.statusCode)
        }
        return try ClaudeOAuthUsageParser.parse(data: data, credentials: credentials)
    }
}
