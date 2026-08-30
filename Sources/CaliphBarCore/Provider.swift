import Foundation

public protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    func fetch(context: ProviderFetchContext) async -> ProviderFetchResult
}
