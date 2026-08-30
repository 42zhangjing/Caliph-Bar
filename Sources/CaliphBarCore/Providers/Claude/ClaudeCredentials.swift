import Foundation
import Security
import LocalAuthentication

public struct ClaudeCredentials: Sendable {
    public let accessToken: String
    public let rateLimitTier: String?
    public let subscriptionType: String?

    public init(accessToken: String, rateLimitTier: String?, subscriptionType: String?) {
        self.accessToken = accessToken
        self.rateLimitTier = rateLimitTier
        self.subscriptionType = subscriptionType
    }
}

public enum ClaudeCredentialError: Error, LocalizedError, Sendable {
    case notFound
    case keychainInteractionRequired
    case missingOAuthPayload
    case malformedCredentials
    case keychainStatus(Int32)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Claude OAuth credentials were not found. Run `claude login`."
        case .keychainInteractionRequired:
            return "Claude credentials exist in Keychain but require user approval. Use Repair Claude Keychain Access in Settings."
        case .missingOAuthPayload:
            return "Claude Code credentials do not contain a usable claudeAiOauth token. Re-authenticate with `claude login`."
        case .malformedCredentials:
            return "Claude credentials are present but could not be parsed."
        case let .keychainStatus(status):
            return "Claude Keychain access failed (OSStatus \(status))."
        }
    }
}

public struct ClaudeCredentialLoader: Sendable {
    public init() {}

    public func load(interactive: Bool = false) -> Result<ClaudeCredentials, ClaudeCredentialError> {
        if let fileResult = loadFromFile() {
            return fileResult
        }
        return loadFromKeychain(interactive: interactive)
    }

    /// User-initiated repair path. This intentionally bypasses the credentials-file
    /// preference and asks macOS for the foreign Claude Code Keychain item.
    public func repairKeychainAccess() -> Result<ClaudeCredentials, ClaudeCredentialError> {
        loadFromKeychain(interactive: true)
    }

    private func loadFromFile() -> Result<ClaudeCredentials, ClaudeCredentialError>? {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return nil }
        let url = URL(fileURLWithPath: home).appendingPathComponent(".claude/.credentials.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return .failure(.malformedCredentials) }
        return parse(data: data)
    }

    private func loadFromKeychain(interactive: Bool) -> Result<ClaudeCredentials, ClaudeCredentialError> {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        // Background refreshes must never summon a Keychain authorization sheet.
        // LAContext.interactionNotAllowed is the modern macOS replacement for the
        // deprecated kSecUseAuthenticationUIFail query flag.
        var authenticationContext: LAContext?
        if !interactive {
            let context = LAContext()
            context.interactionNotAllowed = true
            authenticationContext = context
            query[kSecUseAuthenticationContext as String] = context
        }

        // Keep the context strongly alive for the duration of SecItemCopyMatching.
        _ = authenticationContext
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return .failure(.malformedCredentials) }
            return parse(data: data)
        case errSecItemNotFound:
            return .failure(.notFound)
        case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
            return .failure(.keychainInteractionRequired)
        default:
            return .failure(.keychainStatus(status))
        }
    }

    private func parse(data: Data) -> Result<ClaudeCredentials, ClaudeCredentialError> {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.malformedCredentials)
        }
        guard let oauth = root["claudeAiOauth"] as? [String: Any] else {
            return root["mcpOAuth"] != nil ? .failure(.missingOAuthPayload) : .failure(.malformedCredentials)
        }
        guard let token = oauth["accessToken"] as? String, !token.isEmpty else {
            return .failure(.missingOAuthPayload)
        }

        return .success(ClaudeCredentials(
            accessToken: token,
            rateLimitTier: oauth["rateLimitTier"] as? String,
            subscriptionType: oauth["subscriptionType"] as? String
        ))
    }
}
