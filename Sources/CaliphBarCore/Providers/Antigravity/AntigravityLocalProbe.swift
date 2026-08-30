import Foundation

struct AntigravityQuotaSummary: Sendable, Equatable {
    let groups: [AntigravityQuotaGroup]
}

struct AntigravityQuotaGroup: Sendable, Equatable {
    let displayName: String
    let buckets: [AntigravityQuotaBucket]
}

struct AntigravityQuotaBucket: Sendable, Equatable {
    let id: String
    let displayName: String
    let remainingFraction: Double?
    let resetsAt: Date?
    let disabled: Bool
}

enum AntigravityQuotaSummaryParser {
    static func parse(_ data: Data) throws -> AntigravityQuotaSummary {
        let response = try JSONDecoder().decode(QuotaSummaryResponse.self, from: data)
        guard let payload = response.response ?? response.summary ?? response.rootPayload else {
            throw AntigravityProbeError.invalidPayload("Missing quota summary payload")
        }

        let groups = payload.groups.compactMap { group -> AntigravityQuotaGroup? in
            let buckets = (group.buckets ?? []).compactMap { bucket -> AntigravityQuotaBucket? in
                guard let id = cleaned(bucket.bucketId), !id.isEmpty else { return nil }
                return AntigravityQuotaBucket(
                    id: id,
                    displayName: cleaned(bucket.displayName) ?? id,
                    remainingFraction: bucket.resolvedRemainingFraction.map { max(0, min(1, $0)) },
                    resetsAt: bucket.resetTime?.date,
                    disabled: bucket.disabled ?? false
                )
            }
            guard !buckets.isEmpty else { return nil }
            return AntigravityQuotaGroup(
                displayName: cleaned(group.displayName) ?? "Quota",
                buckets: buckets
            )
        }

        guard !groups.isEmpty else {
            throw AntigravityProbeError.invalidPayload("No quota groups were returned")
        }
        return AntigravityQuotaSummary(groups: groups)
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AntigravityLocalProbe: Sendable {
    struct Result: Sendable {
        let summary: AntigravityQuotaSummary
        let sourceLabel: String
    }

    func fetch() async throws -> Result {
        let candidates = try Self.processCandidates()
        guard !candidates.isEmpty else {
            throw AntigravityProbeError.notRunning
        }

        var lastError: Error?
        for candidate in candidates {
            let ports = try Self.listeningPorts(pid: candidate.pid)
            for port in ports.prefix(12) {
                do {
                    let data = try await Self.requestQuotaSummary(
                        port: port,
                        csrfToken: candidate.csrfToken
                    )
                    let summary = try AntigravityQuotaSummaryParser.parse(data)
                    return Result(summary: summary, sourceLabel: candidate.sourceLabel)
                } catch {
                    lastError = error
                }
            }
        }

        if let lastError { throw lastError }
        throw AntigravityProbeError.noReachableQuotaEndpoint
    }

    // MARK: - Process discovery

    private enum CandidateKind: Int, Sendable {
        case app = 0
        case cli = 1
    }

    private struct ProcessCandidate: Sendable {
        let pid: Int
        let csrfToken: String?
        let kind: CandidateKind

        var sourceLabel: String {
            switch kind {
            case .app: return "Antigravity app local quota summary"
            case .cli: return "Antigravity agy local quota summary"
            }
        }
    }

    private static func processCandidates() throws -> [ProcessCandidate] {
        let output = try runCommand("/bin/ps", arguments: ["-ax", "-o", "pid=,command="])
        guard output.status == 0 else {
            throw AntigravityProbeError.commandFailed("ps", output.status)
        }

        var candidates: [ProcessCandidate] = []
        for line in output.stdout.split(whereSeparator: \.isNewline) {
            let parts = line.split(
                maxSplits: 1,
                omittingEmptySubsequences: true,
                whereSeparator: { $0.isWhitespace }
            )
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }
            let command = String(parts[1])
            let lower = command.lowercased()

            if isAntigravityAppLanguageServer(lower) {
                guard let csrf = extractFlag("--csrf_token", from: command), !csrf.isEmpty else {
                    continue
                }
                candidates.append(ProcessCandidate(pid: pid, csrfToken: csrf, kind: .app))
            } else if isAntigravityCLI(lower) {
                candidates.append(ProcessCandidate(pid: pid, csrfToken: nil, kind: .cli))
            }
        }

        // Prefer the richer Antigravity 2.x desktop payload. A signed-in, already-running
        // agy process is a local fallback; CaliphBar never starts or kills user CLI processes.
        return candidates.sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.pid < rhs.pid
        }
    }

    private static func isAntigravityAppLanguageServer(_ lowerCommand: String) -> Bool {
        let isLanguageServer = lowerCommand.contains("language_server") || lowerCommand.contains("language-server")
        guard isLanguageServer else { return false }

        let appMarker = lowerCommand.contains("/antigravity.app/")
        let dataDirMarker = lowerCommand.contains("--app_data_dir antigravity") ||
            lowerCommand.contains("--app_data_dir=antigravity")
        let isIDE = lowerCommand.contains("antigravity-ide") || lowerCommand.contains("antigravity_ide")
        return !isIDE && (appMarker || dataDirMarker)
    }

    private static func isAntigravityCLI(_ lowerCommand: String) -> Bool {
        let firstToken = lowerCommand.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        let executableName = URL(fileURLWithPath: firstToken).lastPathComponent
        if executableName == "agy" { return true }
        if firstToken.contains("antigravity-cli") || firstToken.contains("antigravity_cli") { return true }
        return lowerCommand.contains("/antigravity-cli/") || lowerCommand.contains("/antigravity_cli/")
    }

    private static func extractFlag(_ flag: String, from command: String) -> String? {
        let tokens = command.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        for index in tokens.indices {
            if tokens[index] == flag, tokens.indices.contains(index + 1) {
                return unquote(tokens[index + 1])
            }
            let prefix = flag + "="
            if tokens[index].hasPrefix(prefix) {
                return unquote(String(tokens[index].dropFirst(prefix.count)))
            }
        }
        return nil
    }

    private static func unquote(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func listeningPorts(pid: Int) throws -> [Int] {
        let output = try runCommand(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-a", "-p", String(pid)]
        )
        // lsof returns 1 when a process has no matching sockets. Treat that as an empty set.
        guard output.status == 0 || output.status == 1 else {
            throw AntigravityProbeError.commandFailed("lsof", output.status)
        }

        var ports: Set<Int> = []
        for line in output.stdout.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard let tcpIndex = fields.firstIndex(where: { $0 == "TCP" }), fields.indices.contains(tcpIndex + 1) else {
                continue
            }
            let address = String(fields[tcpIndex + 1]).split(separator: "-").first.map(String.init) ?? ""
            guard let portText = address.split(separator: ":").last,
                  let port = Int(portText),
                  (1...65535).contains(port)
            else { continue }
            ports.insert(port)
        }
        return ports.sorted()
    }

    private struct CommandOutput {
        let stdout: String
        let status: Int32
    }

    private static func runCommand(_ executable: String, arguments: [String]) throws -> CommandOutput {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandOutput(
            stdout: String(data: data, encoding: .utf8) ?? "",
            status: process.terminationStatus
        )
    }

    // MARK: - Local HTTPS quota endpoint

    private static func requestQuotaSummary(port: Int, csrfToken: String?) async throws -> Data {
        guard let url = URL(string:
            "https://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary")
        else {
            throw AntigravityProbeError.invalidURL
        }

        let body = try JSONSerialization.data(withJSONObject: ["forceRefresh": true])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 1.5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        if let csrfToken, !csrfToken.isEmpty {
            request.setValue(csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        }

        let delegate = LocalhostTrustDelegate()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 2.0
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AntigravityProbeError.invalidHTTPResponse
        }
        guard http.statusCode == 200 else {
            throw AntigravityProbeError.httpStatus(http.statusCode)
        }
        return data
    }
}

private final class LocalhostTrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let host = challenge.protectionSpace.host.lowercased()
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              host == "127.0.0.1" || host == "localhost",
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Antigravity's loopback language server uses a self-signed certificate.
        // Trust is relaxed only for the literal local hostnames above; requests never leave this Mac.
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

enum AntigravityProbeError: LocalizedError {
    case notRunning
    case noReachableQuotaEndpoint
    case invalidURL
    case invalidHTTPResponse
    case httpStatus(Int)
    case commandFailed(String, Int32)
    case invalidPayload(String)

    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Antigravity is not running. Open and sign in to Antigravity, or run a signed-in agy session."
        case .noReachableQuotaEndpoint:
            return "No readable Antigravity local quota endpoint was found."
        case .invalidURL:
            return "Antigravity local quota URL is invalid."
        case .invalidHTTPResponse:
            return "Antigravity local quota endpoint returned an invalid response."
        case let .httpStatus(status):
            return "Antigravity local quota endpoint returned HTTP \(status)."
        case let .commandFailed(command, status):
            return "Local Antigravity discovery command \(command) failed with status \(status)."
        case let .invalidPayload(message):
            return "Antigravity quota payload could not be parsed: \(message)."
        }
    }
}

private struct QuotaSummaryResponse: Decodable {
    let response: QuotaSummaryPayload?
    let summary: QuotaSummaryPayload?
    let description: String?
    let groups: [QuotaSummaryGroupPayload]?

    var rootPayload: QuotaSummaryPayload? {
        guard let groups else { return nil }
        return QuotaSummaryPayload(description: description, groups: groups)
    }
}

private struct QuotaSummaryPayload: Decodable {
    let description: String?
    let groups: [QuotaSummaryGroupPayload]

    init(description: String?, groups: [QuotaSummaryGroupPayload]) {
        self.description = description
        self.groups = groups
    }

    private enum CodingKeys: String, CodingKey {
        case description
        case groups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        groups = try container.decodeIfPresent([QuotaSummaryGroupPayload].self, forKey: .groups) ?? []
    }
}

private struct QuotaSummaryGroupPayload: Decodable {
    let displayName: String?
    let buckets: [QuotaSummaryBucketPayload]?
}

private struct QuotaSummaryBucketPayload: Decodable {
    let bucketId: String?
    let displayName: String?
    let disabled: Bool?
    let remainingFraction: Double?
    let remaining: QuotaSummaryRemainingPayload?
    let resetTime: FlexibleDateValue?

    var resolvedRemainingFraction: Double? {
        remainingFraction ?? remaining?.remainingFraction
    }
}

private struct QuotaSummaryRemainingPayload: Decodable {
    let remainingFraction: Double?

    private enum CodingKeys: String, CodingKey {
        case remainingFraction
        case oneofCase = "case"
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let direct = try container.decodeIfPresent(Double.self, forKey: .remainingFraction) {
            remainingFraction = direct
            return
        }

        let oneofCase = try container.decodeIfPresent(String.self, forKey: .oneofCase)
        if oneofCase == "remainingFraction" {
            remainingFraction = try container.decodeIfPresent(Double.self, forKey: .value)
        } else {
            remainingFraction = nil
        }
    }
}

private enum FlexibleDateValue: Decodable {
    case string(String)
    case number(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            throw DecodingError.typeMismatch(
                FlexibleDateValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected date string or epoch")
            )
        }
    }

    var date: Date? {
        switch self {
        case let .number(raw):
            return Date(timeIntervalSince1970: raw > 1_000_000_000_000 ? raw / 1000 : raw)
        case let .string(raw):
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
}
