import Foundation
import CaliphBarCore

struct SnapshotCache {
    private let key = "caliphbar.liveSnapshotCache.v1"

    func load() -> [ProviderID: ProviderSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: ProviderSnapshot].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: decoded.compactMap { entry in
            guard let id = ProviderID(rawValue: entry.key) else { return nil }
            return (id, entry.value)
        })
    }

    func save(_ snapshots: [ProviderID: ProviderSnapshot]) {
        let raw = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func staleSnapshot(from cached: ProviderSnapshot, error: String?, now: Date = Date()) -> ProviderSnapshot? {
        guard now.timeIntervalSince(cached.capturedAt) <= 6 * 3600 else { return nil }
        let validWindows = cached.windows.filter { window in
            guard let reset = window.resetsAt else { return true }
            return reset > now.addingTimeInterval(-60)
        }
        guard !validWindows.isEmpty else { return nil }
        let suffix = error.map { " · \($0)" } ?? ""
        return ProviderSnapshot(
            provider: cached.provider,
            source: .stale,
            sourceDetail: "Last live reading",
            planLabel: cached.planLabel,
            windows: validWindows,
            capturedAt: cached.capturedAt,
            note: "Live refresh failed; showing last successful reading\(suffix)"
        )
    }
}
