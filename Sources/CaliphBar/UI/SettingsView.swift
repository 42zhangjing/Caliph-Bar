import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var l10n = L10n.shared

    private let controlWidth: CGFloat = 154

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            settingsSection(title: l10n.settingsGeneral) {
                toggleRow(l10n.launchAtLogin, isOn: $store.launchAtLogin)
                toggleRow(l10n.quotaNotifications, isOn: $store.notificationsEnabled)
                toggleRow(l10n.showFloatingPill, isOn: $store.pillVisible)
            }

            settingsSection(title: l10n.settingsInterface) {
                if store.pillVisible {
                    pickerRow(l10n.notchBehaviorLabel) {
                        Picker("", selection: $store.pillBehavior) {
                            Text(l10n.notchBehaviorAlways).tag(UsageStore.PillBehavior.alwaysExpanded)
                            Text(l10n.notchBehaviorAuto).tag(UsageStore.PillBehavior.autoCollapse)
                        }
                    }
                }

                pickerRow(l10n.languageLabel) {
                    Picker("", selection: $l10n.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(localizedLanguageName(lang)).tag(lang)
                        }
                    }
                }
            }

            settingsSection(title: l10n.settingsClaude) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.claudeKeychainTitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.86))
                        Text(l10n.claudeKeychainSubtitle)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.36))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Button(l10n.claudeRepairKeychain) {
                        store.repairClaudeKeychainAccess()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let message = store.credentialRepairMessage {
                    Text(message)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.46))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.55)
                .foregroundStyle(.white.opacity(0.30))
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.055), lineWidth: 0.75)
            )
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(1)

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.green)
                .frame(width: controlWidth, alignment: .trailing)
        }
        .frame(height: 27)
    }

    @ViewBuilder
    private func pickerRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(1)

            Spacer(minLength: 8)

            content()
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: controlWidth, alignment: .trailing)
        }
        .frame(height: 29)
    }

    private func localizedLanguageName(_ language: AppLanguage) -> String {
        switch (l10n.isChinese, language) {
        case (true, .system): return "跟随系统"
        case (true, .zhHans): return "简体中文"
        case (true, .en): return "English"
        case (false, .system): return "Follow System"
        case (false, .zhHans): return "Simplified Chinese"
        case (false, .en): return "English"
        }
    }
}
