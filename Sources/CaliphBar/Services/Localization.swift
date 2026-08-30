import Foundation
import Combine
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统 (Follow System)"
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

@MainActor
public final class L10n: ObservableObject {
    public static let shared = L10n()

    private enum Keys {
        static let language = "caliphbar.appLanguage"
    }

    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Keys.language)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: raw) {
            currentLanguage = lang
        } else {
            currentLanguage = .system
        }
    }

    public var isChinese: Bool {
        switch currentLanguage {
        case .zhHans:
            return true
        case .en:
            return false
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.starts(with: "zh")
        }
    }

    // MARK: - Strings

    public var appTitle: String { "CaliphBar" }

    public var sessionUsage: String {
        isChinese ? "当前会话" : "Current session"
    }

    public var weeklyUsage: String {
        isChinese ? "每周限额" : "Weekly limit"
    }

    public var remaining: String {
        isChinese ? "剩余" : "remaining"
    }

    public func providerUsageTitle(_ providerName: String) -> String {
        isChinese ? "\(providerName) 用量" : "\(providerName) Usage"
    }

    public var usageUnavailable: String {
        isChinese ? "暂无用量数据" : "Usage unavailable"
    }

    public func remainingPercentText(_ percent: Int) -> String {
        isChinese ? "剩余 \(percent)%" : "\(percent)% remaining"
    }

    public func usedPercentText(_ percent: Int) -> String {
        isChinese ? "已用 \(percent)%" : "\(percent)% used"
    }

    public var statusLive: String {
        isChinese ? "实时" : "LIVE"
    }

    public var statusStale: String {
        isChinese ? "旧数据" : "STALE"
    }

    public var statusEstimated: String {
        isChinese ? "估算" : "ESTIMATED"
    }

    public var statusOffline: String {
        isChinese ? "离线" : "OFFLINE"
    }

    public func resetsText(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = isChinese ? "E HH:mm" : "E h:mm a"
        let str = formatter.string(from: date)
        return isChinese ? "重置于 \(str)" : "Resets \(str)"
    }

    public func updatedAtText(date: Date?) -> String {
        guard let date else {
            return isChinese ? "等待首次刷新" : "Waiting for first refresh"
        }
        let formatter = DateFormatter()
        formatter.locale = isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.timeStyle = .short
        return isChinese ? "更新于 \(formatter.string(from: date))" : "Updated \(formatter.string(from: date))"
    }

    public var settingsTitle: String {
        isChinese ? "偏好设置" : "Settings"
    }

    public var launchAtLogin: String {
        isChinese ? "开机自动启动" : "Launch at Login"
    }

    public var showFloatingPill: String {
        isChinese ? "屏幕边缘悬浮胶囊" : "Show Floating Side Pill"
    }

    public var notchBehaviorLabel: String {
        isChinese ? "胶囊侧边栏形态" : "Notch Display Mode"
    }

    public var notchBehaviorAuto: String {
        isChinese ? "静默折叠 (悬停展开)" : "Auto Collapse (Hover to expand)"
    }

    public var notchBehaviorAlways: String {
        isChinese ? "常驻展开" : "Always Expanded"
    }

    public var quotaNotifications: String {
        isChinese ? "用量阈值通知" : "Quota Notifications"
    }

    public var languageLabel: String {
        isChinese ? "显示语言" : "Language"
    }

    public var claudeRepairKeychain: String {
        isChinese ? "修复 Claude Keychain 权限" : "Repair Claude Keychain Access"
    }

    public var claudeNotFoundHelp: String {
        isChinese ? "未检测到 Claude 凭据，请在终端运行 claude login 登录" : "Claude credentials not found. Run `claude login`."
    }

    public var geminiUnimplemented: String {
        isChinese ? "Gemini 当前未实现，敬请期待" : "Gemini is not implemented in CaliphBar 0.2."
    }

    public var refresh: String {
        isChinese ? "刷新" : "Refresh"
    }

    public var quit: String {
        isChinese ? "退出 CaliphBar" : "Quit CaliphBar"
    }
}
