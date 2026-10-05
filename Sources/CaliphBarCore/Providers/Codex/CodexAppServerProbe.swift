import Foundation
import Darwin

/// Reads the same live account quota state exposed by the official Codex CLI app-server.
///
/// This stays local: CaliphBar launches `codex app-server` in read-only / never-approve mode
/// and asks for `account/rateLimits/read` over JSON-RPC on stdin/stdout. It does not read
/// Codex OAuth tokens and does not call ChatGPT private HTTP endpoints itself.
struct CodexAppServerProbe: Sendable {
    func fetchRateLimits() async throws -> CodexRateLimits {
        let worker = Task.detached(priority: .utility) {
            let session = try CodexRPCSession()
            defer { session.shutdown() }
            return try await withTaskCancellationHandler {
                try Task.checkCancellation()
                return try session.fetchRateLimitsOneShot()
            } onCancel: {
                session.cancel()
            }
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
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

/// Owns only the quota probes this app launched, never other Codex processes.
public enum CodexQuotaProbeLifecycle {
    fileprivate static let lock = NSLock()
    fileprivate static var groups: Set<pid_t> = []
    fileprivate static var stopping = false

    public static func shutdown() {
        lock.lock()
        defer { lock.unlock() }
        stopping = true
        for pid in groups { kill(-pid, SIGKILL) }
    }
}

final class CodexRPCSession: @unchecked Sendable {
    private var pid: pid_t = 0
    private let input = Pipe()
    private let output = Pipe()
    private let errors = Pipe()
    private let timeout: TimeInterval
    private let flushAfter: TimeInterval

    init(executable: String? = nil, timeout: TimeInterval = 30, flushAfter: TimeInterval = 5) throws {
        guard let executable = executable ?? Self.resolveExecutable() else {
            throw CodexAppServerError.executableNotFound
        }
        self.timeout = timeout
        self.flushAfter = flushAfter

        // Sandbox/approval flags do not prevent plugin setup. Disable plugins for this
        // process only: quota reads must never clone or upgrade marketplace repositories.
        let arguments = [executable, "--disable", "plugins", "-s", "read-only", "-a", "never", "app-server"]
        let argv = arguments.map { strdup($0) } + [nil]
        let envp = Self.environmentForExecutable(executable).map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer {
            posix_spawn_file_actions_destroy(&actions)
            posix_spawnattr_destroy(&attributes)
        }
        for (handle, target) in [
            (input.fileHandleForReading, STDIN_FILENO),
            (output.fileHandleForWriting, STDOUT_FILENO),
            (errors.fileHandleForWriting, STDERR_FILENO),
        ] {
            posix_spawn_file_actions_adddup2(&actions, handle.fileDescriptor, target)
        }
        // A separate process group lets teardown include Git/helper descendants.
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setpgroup(&attributes, 0)
        CodexQuotaProbeLifecycle.lock.lock()
        defer { CodexQuotaProbeLifecycle.lock.unlock() }
        guard !CodexQuotaProbeLifecycle.stopping else { throw CodexAppServerError.closed }
        let status = argv.withUnsafeBufferPointer { args in
            envp.withUnsafeBufferPointer { env in
                posix_spawn(&pid, executable, &actions, &attributes, args.baseAddress!, env.baseAddress!)
            }
        }
        guard status == 0 else {
            throw CodexAppServerError.launchFailed(String(cString: strerror(status)))
        }
        CodexQuotaProbeLifecycle.groups.insert(pid)
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
        try? errors.fileHandleForWriting.close()
        for fd in [output.fileHandleForReading.fileDescriptor, errors.fileHandleForReading.fileDescriptor] {
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        }
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
    }

    deinit { shutdown() }

    func fetchRateLimitsOneShot() throws -> CodexRateLimits {
        let start = ProcessInfo.processInfo.systemUptime
        let requests: [[String: Any]] = [
            ["id": 1, "method": "initialize",
             "params": ["clientInfo": ["name": "caliphbar", "title": "CaliphBar", "version": "0.2"]]],
            ["method": "initialized"],
            ["id": 2, "method": "account/rateLimits/read", "params": NSNull()],
        ]
        var request = Data()
        for message in requests {
            request.append(try JSONSerialization.data(withJSONObject: message))
            request.append(0x0A)
        }
        // This small, single write fits into the empty pipe; it cannot fill the pipe.
        try input.fileHandleForWriting.write(contentsOf: request)
        var pending = Data()
        var received = 0
        var inputClosed = false
        var buffer = [UInt8](repeating: 0, count: 8192)
        while ProcessInfo.processInfo.systemUptime - start < timeout {
            // Some bundled CLI versions flush only after stdin closes.
            if !inputClosed && ProcessInfo.processInfo.systemUptime - start >= flushAfter {
                try? input.fileHandleForWriting.close()
                inputClosed = true
            }
            // Bounded nonblocking reads keep both stderr floods and missing EOF from
            // bypassing the overall deadline. No stderr/credentials are retained.
            let count = read(output.fileHandleForReading.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                received += count
                guard received <= 1_048_576 else {
                    throw CodexAppServerError.invalidPayload("quota response exceeds 1 MiB")
                }
                pending.append(contentsOf: buffer.prefix(count))
            } else if count < 0 && errno != EAGAIN && errno != EINTR {
                throw CodexAppServerError.closed
            }
            while let newline = pending.firstIndex(of: 0x0A) {
                let line = Data(pending[..<newline])
                pending.removeSubrange(...newline)
                if let limits = try Self.parseResponse(line) { return limits }
            }
            if count == 0 {
                if let limits = try Self.parseResponse(pending) { return limits }
                throw CodexAppServerError.closed
            }
            _ = read(errors.fileHandleForReading.fileDescriptor, &buffer, buffer.count)
            Thread.sleep(forTimeInterval: 0.01)
        }
        throw CodexAppServerError.timeout("account/rateLimits/read")
    }

    private static func parseResponse(_ line: Data) throws -> CodexRateLimits? {
        guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              String(describing: message["id"] ?? "") == "2" else { return nil }
        if message["error"] != nil {
            throw CodexAppServerError.rpcError("account/rateLimits/read failed")
        }
        guard let limits = CodexAppServerRateLimitParser.parse(message: message) else {
            throw CodexAppServerError.invalidPayload("missing rateLimits.primary.usedPercent")
        }
        return limits
    }

    func cancel() {
        CodexQuotaProbeLifecycle.lock.lock()
        defer { CodexQuotaProbeLifecycle.lock.unlock() }
        if pid > 0 { kill(-pid, SIGKILL) }
    }

    func shutdown() {
        CodexQuotaProbeLifecycle.lock.lock()
        defer { CodexQuotaProbeLifecycle.lock.unlock() }
        guard pid > 0 else { return }
        // Keep the direct child unreaped until the final group signal, preventing PID
        // reuse from targeting an unrelated group. Teardown also runs after success.
        kill(-pid, SIGTERM)
        Thread.sleep(forTimeInterval: 0.05)
        kill(-pid, SIGKILL)
        while waitpid(pid, nil, 0) < 0 && errno == EINTR {}
        CodexQuotaProbeLifecycle.groups.remove(pid)
        pid = 0
        try? input.fileHandleForWriting.close()
        try? output.fileHandleForReading.close()
        try? errors.fileHandleForReading.close()
    }

    private static func resolveExecutable() -> String? {
        let environment = ProcessInfo.processInfo.environment
        let fm = FileManager.default
        if let override = environment["CODEX_CLI_PATH"], fm.isExecutableFile(atPath: override) {
            return override
        }
        var candidates = (environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/codex" }
        if let home = environment["HOME"] {
            candidates += ["\(home)/.local/bin/codex", "\(home)/.npm-global/bin/codex", "\(home)/.bun/bin/codex"]
        }
        candidates += ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "/usr/bin/codex"]
        // Bundled CLI resolution is installed by CodexProvider. Never start an
        // unbounded login shell merely to discover an executable.
        return candidates.first(where: { fm.isExecutableFile(atPath: $0) })
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
