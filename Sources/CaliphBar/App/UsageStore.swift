import Foundation
import Combine
import CaliphBarCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var items: [ProviderSnapshot] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshingProviders: Set<ProviderID> = []
    @Published var credentialRepairMessage: String?

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notifications)
            if notificationsEnabled { UsageNotifier.requestAuthorizationIfNeeded() }
        }
    }

    @Published var launchAtLogin: Bool {
        didSet { LaunchAtLogin.setEnabled(launchAtLogin) }
    }

    @Published var pillVisible: Bool {
        didSet { UserDefaults.standard.set(pillVisible, forKey: Keys.pillVisible) }
    }

    @Published var pillBehavior: PillBehavior {
        didSet { UserDefaults.standard.set(pillBehavior.rawValue, forKey: Keys.pillBehavior) }
    }

    @Published var pillSide: EdgeSide {
        didSet { UserDefaults.standard.set(pillSide.rawValue, forKey: Keys.pillSide) }
    }

    @Published var radarPinned: Bool {
        didSet { UserDefaults.standard.set(radarPinned, forKey: Keys.radarPinned) }
    }

    @Published var claudeSessionBudget: Double {
        didSet { UserDefaults.standard.set(claudeSessionBudget, forKey: Keys.sessionBudget) }
    }

    @Published var claudeWeeklyBudget: Double {
        didSet { UserDefaults.standard.set(claudeWeeklyBudget, forKey: Keys.weeklyBudget) }
    }

    public enum PillBehavior: String, CaseIterable, Identifiable {
        case autoCollapse = "autoCollapse"
        case alwaysExpanded = "alwaysExpanded"

        public var id: String { rawValue }
    }

    private enum Keys {
        static let notifications = "caliphbar.notificationsEnabled"
        static let pillVisible = "caliphbar.pillVisible"
        static let pillBehavior = "caliphbar.pillBehavior"
        static let pillSide = "caliphbar.pillSide"
        static let radarPinned = "caliphbar.radarPinned"
        static let sessionBudget = "caliphbar.claudeSessionBudget"
        static let weeklyBudget = "caliphbar.claudeWeeklyBudget"
    }

    private let providers: [any UsageProvider] = [ClaudeProvider(), CodexProvider(), AntigravityProvider()]
    private let cache = SnapshotCache()
    private var liveCache: [ProviderID: ProviderSnapshot]
    private var timer: Timer?

    init() {
        let defaults = UserDefaults.standard
        notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? true
        pillVisible = defaults.object(forKey: Keys.pillVisible) as? Bool ?? true
        let behaviorRaw = defaults.string(forKey: Keys.pillBehavior) ?? PillBehavior.alwaysExpanded.rawValue
        pillBehavior = PillBehavior(rawValue: behaviorRaw) ?? .alwaysExpanded
        pillSide = defaults.string(forKey: Keys.pillSide).flatMap(EdgeSide.init(rawValue:)) ?? .right
        radarPinned = defaults.object(forKey: Keys.radarPinned) as? Bool ?? false
        claudeSessionBudget = defaults.object(forKey: Keys.sessionBudget) as? Double ?? 40
        claudeWeeklyBudget = defaults.object(forKey: Keys.weeklyBudget) as? Double ?? 400
        launchAtLogin = LaunchAtLogin.isEnabled
        liveCache = cache.load()

        if notificationsEnabled { UsageNotifier.requestAuthorizationIfNeeded() }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    func item(for provider: ProviderID) -> ProviderSnapshot? {
        items.first { $0.provider == provider }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshingProviders = Set(ProviderID.allCases)
        let context = ProviderFetchContext(
            claudeSessionBudget: claudeSessionBudget,
            claudeWeeklyBudget: claudeWeeklyBudget
        )
        let providers = self.providers

        Task {
            await withTaskGroup(of: ProviderFetchResult.self) { group in
                for provider in providers {
                    group.addTask { await provider.fetch(context: context) }
                }
                for await result in group {
                    publish(result: result)
                }
            }
            isRefreshing = false
        }
    }

    func centerPill() {
        NotificationCenter.default.post(name: .caliphBarCenterPill, object: nil)
    }

    func repairClaudeKeychainAccess() {
        credentialRepairMessage = L10n.shared.claudeRepairRequesting
        Task.detached {
            let result = ClaudeCredentialLoader().repairKeychainAccess()
            await MainActor.run {
                switch result {
                case .success:
                    self.credentialRepairMessage = L10n.shared.claudeRepairSuccess
                    self.refresh()
                case let .failure(error):
                    self.credentialRepairMessage = L10n.shared.claudeRepairFailure(error.errorDescription)
                }
            }
        }
    }

    private func publish(result: ProviderFetchResult) {
        let resolved: ProviderSnapshot
        if let live = result.liveSnapshot {
            resolved = live
            liveCache[result.provider] = live
            cache.save(liveCache)
        } else if let cached = liveCache[result.provider],
                  let stale = cache.staleSnapshot(from: cached, error: result.errorDescription) {
            resolved = stale
        } else if let fallback = result.fallbackSnapshot {
            resolved = fallback
        } else {
            resolved = .unavailable(
                provider: result.provider,
                note: result.errorDescription ?? "Usage is unavailable."
            )
        }

        var byProvider = Dictionary(uniqueKeysWithValues: items.map { ($0.provider, $0) })
        byProvider[result.provider] = resolved
        items = ProviderID.allCases.compactMap { byProvider[$0] }
        lastUpdated = Date()
        refreshingProviders.remove(result.provider)
        UsageNotifier.check(snapshots: items, enabled: notificationsEnabled)

        if resolved.provider == .codex, resolved.source == .live {
            CodexRadarStore.shared.observeCodex(resolved)
        }
    }
}

extension Notification.Name {
    static let caliphBarCenterPill = Notification.Name("caliphbar.centerPill")
}
