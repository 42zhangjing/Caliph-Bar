import Foundation
import Combine
import CaliphBarCore

@MainActor
final class SelectionModel: ObservableObject {
    @Published private(set) var selected: ProviderID {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Self.key) }
    }
    @Published private(set) var sidePreview: ProviderID? = nil
    @Published var sidePointerOffset: CGFloat = 0

    private static let key = "caliphbar.selectedProvider"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        selected = raw.flatMap(ProviderID.init(rawValue:)) ?? .claude
    }

    func selectFromMenu(_ provider: ProviderID) {
        selected = provider
    }

    func previewFromPill(_ provider: ProviderID) {
        sidePreview = provider
    }
}
