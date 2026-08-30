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
        case .system: return "Follow System"
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

    public var settingsGeneral: String {
        isChinese ? "通用" : "General"
    }

    public var settingsInterface: String {
        isChinese ? "界面" : "Interface"
    }

    public var settingsClaude: String {
        "Claude"
    }

    public var launchAtLogin: String {
        isChinese ? "开机自动启动" : "Launch at Login"
    }

    public var showFloatingPill: String {
        isChinese ? "显示屏幕边缘侧栏" : "Show Edge Pill"
    }

    public var notchBehaviorLabel: String {
        isChinese ? "侧栏显示方式" : "Pill Behavior"
    }

    public var notchBehaviorAuto: String {
        isChinese ? "悬停展开" : "Expand on Hover"
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

    public var claudeKeychainTitle: String {
        isChinese ? "Claude 凭据访问" : "Claude Credential Access"
    }

    public var claudeKeychainSubtitle: String {
        isChinese ? "仅在你主动修复时请求系统授权" : "System permission is requested only when you repair access."
    }

    public var claudeRepairKeychain: String {
        isChinese ? "修复权限" : "Repair Access"
    }

    public var claudeRepairRequesting: String {
        isChinese ? "正在请求 Claude Code Keychain 权限…" : "Requesting Claude Code Keychain access…"
    }

    public var claudeRepairSuccess: String {
        isChinese ? "Claude Keychain 权限已授权。" : "Claude Keychain access granted."
    }

    public func claudeRepairFailure(_ detail: String?) -> String {
        if let detail, !detail.isEmpty {
            return isChinese ? "Claude Keychain 修复失败：\(detail)" : "Claude Keychain repair failed: \(detail)"
        }
        return isChinese ? "Claude Keychain 修复失败。" : "Claude Keychain repair failed."
    }

    public var claudeNotFoundHelp: String {
        isChinese ? "未检测到 Claude 凭据，请在终端运行 claude login 登录" : "Claude credentials not found. Run `claude login`."
    }

    // Legacy property name retained while the third provider slot is migrated from Gemini to Antigravity.
    public var geminiUnimplemented: String {
        isChinese
            ? "未读取到 Antigravity 本地额度。请先启动并登录 Antigravity，或保持已登录的 agy 正在运行。"
            : "Antigravity local quota is unavailable. Open and sign in to Antigravity, or keep a signed-in agy session running."
    }

    public var refresh: String {
        isChinese ? "刷新" : "Refresh"
    }

    public var quit: String {
        isChinese ? "退出 CaliphBar" : "Quit CaliphBar"
    }
}
