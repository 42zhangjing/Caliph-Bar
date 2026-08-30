import Foundation

public struct GeminiProvider: UsageProvider {
    public let id: ProviderID = .gemini

    public init() {}

    public func fetch(context _: ProviderFetchContext) async -> ProviderFetchResult {
        ProviderFetchResult(
            provider: .gemini,
            liveSnapshot: nil,
            errorDescription: "Gemini is intentionally not implemented in CaliphBar 0.1."
        )
    }
}
