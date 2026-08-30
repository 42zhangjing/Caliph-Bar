import Foundation
import UserNotifications
import CaliphBarCore

enum UsageNotifier {
    private static let threshold = 0.90
    private static let prefix = "caliphbar.notified."

    static func requestAuthorizationIfNeeded() {
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
        let key = "\(prefix)\(snapshot.provider.rawValue).\(window.id)"
        if window.usedFraction < threshold {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        let resetKey = window.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "no-reset"
        guard UserDefaults.standard.string(forKey: key) != resetKey else { return }
        UserDefaults.standard.set(resetKey, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "\(snapshot.provider.displayName) usage is high"
        let estimate = snapshot.source == .estimated ? " (estimated)" : ""
        content.body = "\(window.title) is at \(Int(window.usedFraction * 100))% used\(estimate)."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "\(snapshot.provider.rawValue)-\(window.id)-\(resetKey)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
