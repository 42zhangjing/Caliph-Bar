import Foundation

/// Reads the same live account quota state exposed by the official Codex CLI app-server.
///
/// This stays local: CaliphBar launches `codex app-server` in read-only / never-approve mode
/// and asks for `account/rateLimits/read` over JSON-RPC on stdin/stdout. It does not read
/// Codex OAuth tokens and does not call ChatGPT private HTTP endpoints itself.
struct CodexAppServerProbe: Sendable {
    func fetchRateLimits() async throws -> CodexRateLimits {
        try await Task.detached(priority: .utility) {
            let session = try CodexRPCSession()
            defer { session.shutdown() }
            return try session.fetchRateLimitsOneShot()
        }.value
    }
}

enum CodexAppServerRateLimitParser {
    static func parse(message: [String: Any]) -> CodexRateLimits? {
        guard let result = dictionary(message["result"]),
              let rateLimits = dictionary(result["rateLimits"]) ?? dictionary(result["rate_limits"]),
              let primary = dictionary(rateLimits["primary"]),
              let primaryPercent = number(primary["usedPercent"] ?? primary["used_percent"])
        else { return nil }

        let secondary = dictionary(rateLimits["secondary"])
        let primaryResetsAt = date(primary["resetsAt"] ?? primary["resets_at"])
        let primaryWindowMinutes = number(primary["windowDurationMins"] ?? primary["window_duration_mins"])
        let secondaryPercent = number(secondary?["usedPercent"] ?? secondary?["used_percent"])
        let secondaryResetsAt = date(secondary?["resetsAt"] ?? secondary?["resets_at"])
        let secondaryWindowMinutes = number(secondary?["windowDurationMins"] ?? secondary?["window_duration_mins"])

        return CodexRateLimits(
            primaryPercent: primaryPercent,
            primaryResetsAt: primaryResetsAt,
            primaryWindowMinutes: primaryWindowMinutes,
            secondaryPercent: secondaryPercent,
            secondaryResetsAt: secondaryResetsAt,
            secondaryWindowMinutes: secondaryWindowMinutes,
            planType: string(rateLimits["planType"] ?? rateLimits["plan_type"]),
            extraRateLimits: parseExtraRateLimits(
                result: result,
                main: MainWindowSignature(
                    primaryPercent: primaryPercent,
                    primaryResetsAt: primaryResetsAt,
                    primaryWindowMinutes: primaryWindowMinutes,
                    secondaryPercent: secondaryPercent,
                    secondaryResetsAt: secondaryResetsAt,
                    secondaryWindowMinutes: secondaryWindowMinutes
                )
            )
        )
    }

    static func parse(data: Data) -> CodexRateLimits? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return parse(message: object)
    }

    private struct MainWindowSignature {
        let primaryPercent: Double
        let primaryResetsAt: Date?
        let primaryWindowMinutes: Double?
        let secondaryPercent: Double?
        let secondaryResetsAt: Date?
        let secondaryWindowMinutes: Double?
    }

    private static func parseExtraRateLimits(
        result: [String: Any],
        main: MainWindowSignature
    ) -> [CodexExtraRateLimit] {
        guard let byLimitID = dictionary(result["rateLimitsByLimitId"] ?? result["rate_limits_by_limit_id"]) else {
            return []
        }

        return byLimitID.compactMap { key, rawValue -> CodexExtraRateLimit? in
            guard let snapshot = dictionary(rawValue) else { return nil }

            let limitID = string(snapshot["limitId"] ?? snapshot["limit_id"]) ?? key
            let limitName = string(snapshot["limitName"] ?? snapshot["limit_name"])
            let primary = dictionary(snapshot["primary"])
            let secondary = dictionary(snapshot["secondary"])
            let primaryPercent = number(primary?["usedPercent"] ?? primary?["used_percent"])
            let primaryResetsAt = date(primary?["resetsAt"] ?? primary?["resets_at"])
            let primaryWindowMinutes = number(primary?["windowDurationMins"] ?? primary?["window_duration_mins"])
            let secondaryPercent = number(secondary?["usedPercent"] ?? secondary?["used_percent"])
            let secondaryResetsAt = date(secondary?["resetsAt"] ?? secondary?["resets_at"])
            let secondaryWindowMinutes = number(secondary?["windowDurationMins"] ?? secondary?["window_duration_mins"])

            guard primaryPercent != nil || secondaryPercent != nil else { return nil }

            // `rateLimitsByLimitId` includes the ordinary Codex bucket as well as any
            // model-specific buckets. Exclude the ordinary bucket so the main 5h/weekly
            // lanes are not duplicated in the UI.
            let normalizedID = limitID.lowercased()
            let normalizedKey = key.lowercased()
            if normalizedID == "codex" || normalizedKey == "codex" {
                return nil
            }
            if sameAsMain(
                primaryPercent: primaryPercent,
                primaryResetsAt: primaryResetsAt,
                primaryWindowMinutes: primaryWindowMinutes,
                secondaryPercent: secondaryPercent,
                secondaryResetsAt: secondaryResetsAt,
                secondaryWindowMinutes: secondaryWindowMinutes,
                main: main
            ) {
                return nil
            }

            return CodexExtraRateLimit(
                id: limitID,
                name: limitName,
                primaryPercent: primaryPercent,
                primaryResetsAt: primaryResetsAt,
                primaryWindowMinutes: primaryWindowMinutes,
                secondaryPercent: secondaryPercent,
                secondaryResetsAt: secondaryResetsAt,
                secondaryWindowMinutes: secondaryWindowMinutes
            )
        }
        .sorted { lhs, rhs in
            let lhsSpark = isSpark(lhs)
            let rhsSpark = isSpark(rhs)
            if lhsSpark != rhsSpark { return lhsSpark && !rhsSpark }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }
    }

    private static func isSpark(_ limit: CodexExtraRateLimit) -> Bool {
        [limit.id, limit.name]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains("spark") }
    }

    private static func sameAsMain(
        primaryPercent: Double?,
        primaryResetsAt: Date?,
        primaryWindowMinutes: Double?,
        secondaryPercent: Double?,
        secondaryResetsAt: Date?,
        secondaryWindowMinutes: Double?,
        main: MainWindowSignature
    ) -> Bool {
        primaryPercent == main.primaryPercent &&
            primaryResetsAt == main.primaryResetsAt &&
            primaryWindowMinutes == main.primaryWindowMinutes &&
            secondaryPercent == main.secondaryPercent &&
            secondaryResetsAt == main.secondaryResetsAt &&
            secondaryWindowMinutes == main.secondaryWindowMinutes
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double: return value
        case let value as Int: return Double(value)
        case let value as NSNumber: return value.doubleValue
        case let value as String: return Double(value)
        default: return nil
        }
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func date(_ value: Any?) -> Date? {
        guard let seconds = number(value) else { return nil }
        return Date(timeIntervalSince1970: seconds > 1_000_000_000_000 ? seconds / 1000 : seconds)
    }
}

private final class CodexRPCSession: @unchecked Sendable {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let lock = NSLock()
    private var stdoutBuffer = Data()
    private var nextID = 1
    private var didShutdown = false

    init() throws {
        guard let executable = Self.resolveExecutable() else {
            throw CodexAppServerError.executableNotFound
        }

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-s", "read-only", "-a", "never", "app-server"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = Self.environmentForExecutable(executable)

        do {
            try process.run()
        } catch {
            throw CodexAppServerError.launchFailed(error.localizedDescription)
        }
    }

    /// Current alpha builds of the bundled Codex CLI can buffer stdout while stdin stays open.
    /// Queue the read-only handshake and snapshot request, allow the local request to finish,
    /// then close stdin so the JSONL response is flushed. The app refreshes this snapshot every
    /// minute; no OAuth token or private HTTP endpoint is accessed by CaliphBar.
    func fetchRateLimitsOneShot() throws -> CodexRateLimits {
        try write([
            "id": 1,
            "method": "initialize",
            "params": ["clientInfo": ["name": "caliphbar", "title": "CaliphBar", "version": "0.2"]],
        ])
        try sendNotification(method: "initialized")
        try write([
            "id": 2,
            "method": "account/rateLimits/read",
            "params": NSNull(),
        ])

        Thread.sleep(forTimeInterval: 5.0)
        try? stdinPipe.fileHandleForWriting.close()
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

        for line in data.split(separator: 0x0A) {
            guard let message = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  Self.integer(message["id"]) == 2
            else { continue }
            if let error = message["error"] {
                throw CodexAppServerError.rpcError(String(describing: error))
            }
            guard let limits = CodexAppServerRateLimitParser.parse(message: message) else {
                throw CodexAppServerError.invalidPayload("missing rateLimits.primary.usedPercent")
            }
            return limits
        }

        throw CodexAppServerError.invalidPayload("account/rateLimits/read did not return before the local snapshot closed")
    }

    func initialize() async throws {
        _ = try await request(
            method: "initialize",
            params: ["clientInfo": ["name": "caliphbar", "title": "CaliphBar", "version": "0.2"]],
            // Codex Desktop itself allows roughly 30 seconds for the app-server handshake.
            // Real installations with substantial local state / MCP configuration can exceed
            // the previous 8-second CaliphBar deadline even though the server is healthy.
            timeout: 30.0
        )
        try sendNotification(method: "initialized")
    }

    func request(
        method: String,
        params: [String: Any]? = nil,
        timeout: TimeInterval
    ) async throws -> [String: Any] {
        let id = reserveID()
        var payload: [String: Any] = ["id": id, "method": method]
        if let params { payload["params"] = params }
        try write(payload)

        return try await withThrowingTaskGroup(of: [String: Any].self) { group in
            group.addTask { [self] in
                while true {
                    let line = try await readLine()
                    guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                        continue
                    }
                    if let messageID = Self.integer(message["id"]), messageID == id {
                        if let error = message["error"] {
                            throw CodexAppServerError.rpcError(String(describing: error))
                        }
                        return message
                    }
                }
            }

            group.addTask { [self] in
                try await Task.sleep(for: .seconds(timeout))
                shutdown()
                throw CodexAppServerError.timeout(method)
            }

            guard let first = try await group.next() else {
                throw CodexAppServerError.closed
            }
            group.cancelAll()
            return first
        }
    }

    func shutdown() {
        lock.lock()
        if didShutdown {
            lock.unlock()
            return
        }
        didShutdown = true
        lock.unlock()

        try? stdinPipe.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35) { [process] in
                if process.isRunning { process.interrupt() }
            }
        }
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()
    }

    private func sendNotification(method: String) throws {
        try write(["method": method])
    }

    private func reserveID() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextID
        nextID += 1
        return id
    }

    private func write(_ payload: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: payload)
        data.append(0x0A)
        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            throw CodexAppServerError.closed
        }
    }

    private func readLine() async throws -> Data {
        try await Task.detached(priority: .utility) { [self] in
            try readLineBlocking()
        }.value
    }

    private func readLineBlocking() throws -> Data {
        while true {
            lock.lock()
            if let newline = stdoutBuffer.firstIndex(of: 0x0A) {
                let line = stdoutBuffer[..<newline]
                stdoutBuffer.removeSubrange(...newline)
                lock.unlock()
                return Data(line)
            }
            lock.unlock()

            let chunk: Data
            do {
                chunk = try stdoutPipe.fileHandleForReading.read(upToCount: 4096) ?? Data()
            } catch {
                throw CodexAppServerError.closed
            }
            guard !chunk.isEmpty else { throw CodexAppServerError.closed }

            lock.lock()
            stdoutBuffer.append(chunk)
            lock.unlock()
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let value as Int: return value
        case let value as NSNumber: return value.intValue
        case let value as String: return Int(value)
        default: return nil
        }
    }

    private static func resolveExecutable() -> String? {
        let environment = ProcessInfo.processInfo.environment
        let fm = FileManager.default

        if let override = environment["CODEX_CLI_PATH"], fm.isExecutableFile(atPath: override) {
            return override
        }

        var candidates: [String] = []
        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { String($0) + "/codex" })
        }
        if let home = environment["HOME"] {
            candidates.append(contentsOf: [
                "\(home)/.local/bin/codex",
                "\(home)/.npm-global/bin/codex",
                "\(home)/.bun/bin/codex",
            ])
        }
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex",
        ])

        if let direct = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) {
            return direct
        }

        // GUI apps often inherit a minimal PATH. A login shell is a last-resort resolver only;
        // it is never used to execute arbitrary user-provided command text.
        let shell = environment["SHELL"] ?? "/bin/zsh"
        let resolver = Process()
        let output = Pipe()
        resolver.executableURL = URL(fileURLWithPath: shell)
        resolver.arguments = ["-lc", "command -v codex"]
        resolver.standardOutput = output
        resolver.standardError = Pipe()
        do {
            try resolver.run()
            resolver.waitUntilExit()
            guard resolver.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let value, fm.isExecutableFile(atPath: value) { return value }
        } catch {
            return nil
        }
        return nil
    }

    private static func environmentForExecutable(_ executable: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let parent = URL(fileURLWithPath: executable).deletingLastPathComponent().path
        let existing = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        if !existing.split(separator: ":").contains(Substring(parent)) {
            environment["PATH"] = parent + ":" + existing
        }
        return environment
    }
}

enum CodexAppServerError: LocalizedError {
    case executableNotFound
    case launchFailed(String)
    case timeout(String)
    case closed
    case rpcError(String)
    case invalidPayload(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Codex CLI executable was not found."
        case let .launchFailed(detail):
            return "Codex app-server could not start: \(detail)"
        case let .timeout(method):
            return "Codex app-server timed out during \(method)."
        case .closed:
            return "Codex app-server closed before returning quota data."
        case let .rpcError(detail):
            return "Codex app-server returned an RPC error: \(detail)"
        case let .invalidPayload(detail):
            return "Codex app-server quota payload is invalid: \(detail)"
        }
    }
}
