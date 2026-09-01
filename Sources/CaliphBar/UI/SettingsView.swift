import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                settingsSection(title: l10n.settingsGeneral) {
                    settingToggle(l10n.launchAtLogin, isOn: $store.launchAtLogin)
                    divider
                    settingToggle(l10n.quotaNotifications, isOn: $store.notificationsEnabled)
                }

                settingsSection(title: l10n.settingsEdgeRail) {
                    settingToggle(l10n.showFloatingPill, isOn: $store.pillVisible)

                    if store.pillVisible {
                        divider
                        segmentedRow(l10n.notchBehaviorLabel) {
                            segment(l10n.notchBehaviorAlways, selected: store.pillBehavior == .alwaysExpanded) {
                                store.pillBehavior = .alwaysExpanded
                            }
                            segment(l10n.notchBehaviorAuto, selected: store.pillBehavior == .autoCollapse) {
                                store.pillBehavior = .autoCollapse
                            }
                        }
                        divider
                        segmentedRow(l10n.edgeSideLabel) {
                            segment(l10n.edgeSideLeft, selected: store.pillSide == .left) {
                                store.pillSide = .left
                            }
                            segment(l10n.edgeSideRight, selected: store.pillSide == .right) {
                                store.pillSide = .right
                            }
                        }
                        divider
                        segmentedRow(l10n.ringCoreLabel) {
                            segment(l10n.ringCoreDark, selected: store.ringCoreStyle == .dark) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    store.ringCoreStyle = .dark
                                }
                            }
                            segment(l10n.ringCorePorcelain, selected: store.ringCoreStyle == .porcelain) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    store.ringCoreStyle = .porcelain
                                }
                            }
                        }
                        divider
                        Button {
                            store.centerPill()
                        } label: {
                            HStack {
                                Label(l10n.centerEdgeRail, systemImage: "arrow.up.and.down")
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.white.opacity(0.38))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(height: 38)
                        }
                        .buttonStyle(.plain)
                    }
                }

                settingsSection(title: l10n.settingsDataSources) {
                    settingToggle(
                        l10n.pinRadarModule,
                        subtitle: l10n.pinRadarModuleHelp,
                        isOn: $store.radarPinned
                    )
                    divider
                    claudeRepairRow
                }

                settingsSection(title: l10n.settingsInterface) {
                    segmentedRow(l10n.languageLabel) {
                        ForEach(AppLanguage.allCases) { language in
                            segment(localizedLanguageName(language), selected: l10n.currentLanguage == language) {
                                l10n.currentLanguage = language
                            }
                        }
                    }
                }

                if let message = store.credentialRepairMessage {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.48))
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(Color.white.opacity(0.085), lineWidth: 0.75)
            )
        }
    }

    private func settingToggle(
        _ title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.90))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(InstrumentToggleStyle(onText: l10n.onLabel, offText: l10n.offLabel))
        }
        .frame(minHeight: subtitle == nil ? 42 : 54)
    }

    @ViewBuilder
    private func segmentedRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.90))
            HStack(spacing: 3) {
                content()
            }
            .padding(3)
            .background(Capsule().fill(Color.black.opacity(0.30)))
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.7))
        }
        .padding(.vertical, 10)
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? .white : .white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 34)
                .contentShape(Rectangle())
                .background(Capsule().fill(selected ? Color.white.opacity(0.14) : .clear))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var claudeRepairRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(l10n.claudeKeychainTitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.90))
                Text(l10n.claudeKeychainSubtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer(minLength: 8)
            Button(l10n.claudeRepairKeychain) {
                store.repairClaudeKeychainAccess()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 9)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)
    }

    private func localizedLanguageName(_ language: AppLanguage) -> String {
        switch (l10n.isChinese, language) {
        case (true, .system): return "跟随系统"
        case (true, .zhHans): return "简体中文"
        case (true, .en): return "English"
        case (false, .system): return "System"
        case (false, .zhHans): return "中文"
        case (false, .en): return "English"
        }
    }
}

private struct InstrumentToggleStyle: ToggleStyle {
    let onText: String
    let offText: String

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: 7) {
                Text(configuration.isOn ? onText : offText)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(configuration.isOn ? Color.green : Color.white.opacity(0.48))
                    .frame(width: 24, alignment: .trailing)

                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? Color.green.opacity(0.82) : Color.white.opacity(0.16))
                        .frame(width: 38, height: 21)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 17, height: 17)
                        .padding(2)
                        .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? onText : offText)
    }
}
