import Foundation
import Combine
import CaliphBarCore

@MainActor
final class SelectionModel: ObservableObject {
    @Published var selected: ProviderID {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Self.key) }
    }

    private static let key = "caliphbar.selectedProvider"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        selected = raw.flatMap(ProviderID.init(rawValue:)) ?? .claude
    }
}
