import Foundation
import UserNotifications
import CaliphBarCore

@MainActor
enum UsageNotifier {
    private static let threshold = 0.90
    private static let prefix = "caliphbar.notified."

    static func requestAuthorizationIfNeeded() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static func check(snapshots: [ProviderSnapshot], enabled: Bool) {
        guard enabled else { return }
        for snapshot in snapshots where snapshot.source == .live || snapshot.source == .estimated {
            for window in snapshot.windows {
                check(snapshot: snapshot, window: window)
            }
        }
    }

    private static func check(snapshot: ProviderSnapshot, window: UsageWindow) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let key = "\(prefix)\(snapshot.provider.rawValue).\(window.id)"
        if window.usedFraction < threshold {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        let resetKey = window.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "no-reset"
        guard UserDefaults.standard.string(forKey: key) != resetKey else { return }
        UserDefaults.standard.set(resetKey, forKey: key)

        let content = UNMutableNotificationContent()
        let l10n = L10n.shared
        let remainingPercent = Int((window.remainingFraction * 100).rounded())
        
        if l10n.isChinese {
            content.title = "\(snapshot.provider.displayName) 额度告警"
            let windowTitle = window.id == "session" ? "当前会话" : (window.id == "weekly" ? "每周限额" : window.title)
            content.body = "\(windowTitle)仅剩 \(remainingPercent)% 剩余额度。"
        } else {
            content.title = "\(snapshot.provider.displayName) quota alert"
            content.body = "\(window.title) has only \(remainingPercent)% remaining."
        }
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "\(snapshot.provider.rawValue)-\(window.id)-\(resetKey)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
