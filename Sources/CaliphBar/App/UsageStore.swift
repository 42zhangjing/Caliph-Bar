import Foundation
import Combine
import CaliphBarCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var items: [ProviderSnapshot] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false
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

    @Published var claudeSessionBudget: Double {
        didSet { UserDefaults.standard.set(claudeSessionBudget, forKey: Keys.sessionBudget) }
    }

    @Published var claudeWeeklyBudget: Double {
        didSet { UserDefaults.standard.set(claudeWeeklyBudget, forKey: Keys.weeklyBudget) }
    }

    private enum Keys {
        static let notifications = "caliphbar.notificationsEnabled"
        static let pillVisible = "caliphbar.pillVisible"
        static let sessionBudget = "caliphbar.claudeSessionBudget"
        static let weeklyBudget = "caliphbar.claudeWeeklyBudget"
    }

    private let providers: [any UsageProvider] = [ClaudeProvider(), CodexProvider(), GeminiProvider()]
    private let cache = SnapshotCache()
    private var liveCache: [ProviderID: ProviderSnapshot]
    private var timer: Timer?

    init() {
        let defaults = UserDefaults.standard
        notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? true
        pillVisible = defaults.object(forKey: Keys.pillVisible) as? Bool ?? true
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
        let context = ProviderFetchContext(
            claudeSessionBudget: claudeSessionBudget,
            claudeWeeklyBudget: claudeWeeklyBudget
        )
        let providers = self.providers

        Task {
            let results = await withTaskGroup(of: ProviderFetchResult.self, returning: [ProviderFetchResult].self) { group in
                for provider in providers {
                    group.addTask { await provider.fetch(context: context) }
                }
                var output: [ProviderFetchResult] = []
                for await result in group { output.append(result) }
                return output
            }
            publish(results: results)
        }
    }

    func repairClaudeKeychainAccess() {
        credentialRepairMessage = "Requesting Claude Code Keychain access…"
        Task.detached {
            let result = ClaudeCredentialLoader().repairKeychainAccess()
            await MainActor.run {
                switch result {
                case .success:
                    self.credentialRepairMessage = "Claude Keychain access granted."
                    self.refresh()
                case let .failure(error):
                    self.credentialRepairMessage = error.errorDescription ?? "Claude Keychain repair failed."
                }
            }
        }
    }

    private func publish(results: [ProviderFetchResult]) {
        let byProvider = Dictionary(uniqueKeysWithValues: results.map { ($0.provider, $0) })
        var resolved: [ProviderSnapshot] = []
        var cacheChanged = false

        for provider in ProviderID.allCases {
            guard let result = byProvider[provider] else {
                resolved.append(.unavailable(provider: provider, note: "Provider did not return a result."))
                continue
            }

            if let live = result.liveSnapshot {
                resolved.append(live)
                liveCache[provider] = live
                cacheChanged = true
                continue
            }

            if let cached = liveCache[provider],
               let stale = cache.staleSnapshot(from: cached, error: result.errorDescription) {
                resolved.append(stale)
                continue
            }

            if let fallback = result.fallbackSnapshot {
                resolved.append(fallback)
                continue
            }

            resolved.append(.unavailable(
                provider: provider,
                note: result.errorDescription ?? "Usage is unavailable."
            ))
        }

        items = resolved
        lastUpdated = Date()
        isRefreshing = false
        if cacheChanged { cache.save(liveCache) }
        UsageNotifier.check(snapshots: resolved, enabled: notificationsEnabled)
    }
}
