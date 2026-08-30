import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // General Toggles
            Toggle(l10n.launchAtLogin, isOn: $store.launchAtLogin)
            Toggle(l10n.quotaNotifications, isOn: $store.notificationsEnabled)
            Toggle(l10n.showFloatingPill, isOn: $store.pillVisible)

            if store.pillVisible {
                HStack {
                    Text(l10n.notchBehaviorLabel)
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $store.pillBehavior) {
                        Text(l10n.notchBehaviorAlways).tag(UsageStore.PillBehavior.alwaysExpanded)
                        Text(l10n.notchBehaviorAuto).tag(UsageStore.PillBehavior.autoCollapse)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }
            }

            // Language Selector
            HStack {
                Text(l10n.languageLabel)
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $l10n.currentLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 170)
            }

            Divider().overlay(Color.white.opacity(0.09))

            // Claude Credentials & Keychain
            VStack(alignment: .leading, spacing: 7) {
                Button(l10n.claudeRepairKeychain) {
                    store.repairClaudeKeychainAccess()
                }
                .buttonStyle(.bordered)

                if let message = store.credentialRepairMessage {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(.green)
        .font(.system(size: 12))
        .foregroundStyle(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.42)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07)))
    }
}

