import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Bridges the PATH gap common to macOS GUI apps.
///
/// ChatGPT/Codex desktop apps bundle the official `codex` executable inside the app bundle,
/// but that executable is often absent from the shell PATH inherited by a menu-bar app.
/// CaliphBar installs a process-local `CODEX_CLI_PATH` override only when the user has not
/// already supplied one explicitly.
enum CodexBundledCLIEnvironment {
    static func installOverrideIfNeeded(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        guard environment["CODEX_CLI_PATH"] == nil else { return }

        let home = environment["HOME"] ?? NSHomeDirectory()
        guard let bundled = wellKnownCandidates(home: home)
            .first(where: { fileManager.isExecutableFile(atPath: $0) })
        else { return }

        #if canImport(Darwin)
        _ = setenv("CODEX_CLI_PATH", bundled, 0)
        #endif
    }

    static func wellKnownCandidates(home: String) -> [String] {
        [
            "\(home)/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
        ]
    }
}
