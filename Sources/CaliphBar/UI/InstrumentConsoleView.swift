import SwiftUI
import AppKit
import CaliphBarCore

struct InstrumentConsoleView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var selection: SelectionModel
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var radar = CodexRadarStore.shared

    @State private var showSettings = false
    @Namespace private var tabNamespace

    private let width: CGFloat = 458
    private let contentHeight: CGFloat = 510
    private let background = Color(red: 0.042, green: 0.044, blue: 0.050)

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 18)
                .frame(height: 52)

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)

            ZStack(alignment: .top) {
                if showSettings {
                    SettingsView(store: store)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .offset(y: 3)))
                } else {
                    accountConsole
                        .padding(.horizontal, 18)
                        .padding(.top, 15)
                        .transition(.opacity.combined(with: .offset(y: 3)))
                }
            }
            .frame(height: contentHeight, alignment: .top)

            footer
                .padding(.horizontal, 18)
                .frame(height: 34)
        }
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 18).fill(background))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .fixedSize()
        .animation(.easeOut(duration: 0.17), value: showSettings)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(showSettings ? l10n.settingsTitle : l10n.appTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                if !showSettings {
                    Text(store.isRefreshing ? l10n.refreshInProgress : l10n.accountTruthTitle)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(store.isRefreshing ? Color.yellow.opacity(0.86) : Color.white.opacity(0.42))
                }
            }

            Spacer()

            if !showSettings {
                Button { store.refresh() } label: {
                    ZStack {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(store.isRefreshing ? 180 : 0))
                    }
                }
                .buttonStyle(ConsoleIconButtonStyle(active: store.isRefreshing))
                .disabled(store.isRefreshing)
                .help(l10n.refresh)
            }

            Button { showSettings.toggle() } label: {
                Image(systemName: showSettings ? "xmark" : "slider.horizontal.3")
            }
            .buttonStyle(ConsoleIconButtonStyle(active: showSettings))
            .help(l10n.settingsTitle)

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
            }
            .buttonStyle(ConsoleIconButtonStyle(active: false))
            .help(l10n.quit)
        }
        .foregroundStyle(.white.opacity(0.72))
    }

    private var accountConsole: some View {
        VStack(alignment: .leading, spacing: 15) {
            providerTabs

            HStack {
                sectionLabel(l10n.accountTruthTitle)
                Spacer()
                if store.refreshingProviders.contains(selection.selected) {
                    ProgressView().controlSize(.small).tint(.yellow)
                }
            }

            if let item = store.item(for: selection.selected) {
                providerHeader(item)

                if item.windows.isEmpty {
                    unavailableState(item)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(item.windows.prefix(4))) { window in
                            UsageBar(window: window)
                        }
                    }
                    .id(item.provider)
                    .transition(.opacity)
                }

                if let note = item.note, item.source != .live {
                    Text(note)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.44))
                        .lineLimit(2)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 160)
            }

            Spacer(minLength: 2)

            if selection.selected == .codex {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionLabel(l10n.publicIntelligenceTitle)
                        Spacer()
                        Text(radarSourceState)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(radarColor)
                    }
                    CodexRadarDetailStrip()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.16), value: selection.selected)
    }

    private var providerTabs: some View {
        HStack(spacing: 4) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { selection.selected = provider }
                } label: {
                    HStack(spacing: 7) {
                        BrandMark(provider: provider, size: 16)
                        Text(provider.displayName)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection.selected == provider ? .white : .white.opacity(0.44))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selection.selected == provider {
                            Capsule()
                                .fill(Color.white.opacity(0.13))
                                .matchedGeometryEffect(id: "instrument-tab", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.28)))
        .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 0.7))
    }

    private func providerHeader(_ item: ProviderSnapshot) -> some View {
        HStack(spacing: 10) {
            BrandMark(provider: item.provider, size: 27)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(item.provider.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    if let plan = item.planLabel {
                        Text(plan)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Text(item.sourceDetail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.36))
                    .lineLimit(1)
            }
            Spacer()
            sourceBadge(item.source)
        }
    }

    private func unavailableState(_ item: ProviderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedNote(for: item))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
            if store.refreshingProviders.contains(item.provider) {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    private func sourceBadge(_ source: UsageSourceKind) -> some View {
        let text: String
        switch source {
        case .live: text = l10n.statusLive
        case .estimated: text = l10n.statusEstimated
        case .stale: text = l10n.statusStale
        case .unavailable: text = l10n.statusOffline
        }
        let color: Color = source == .live ? .green : (source == .stale ? .yellow : .white)
        return HStack(spacing: 5) {
            Circle().fill(color.opacity(0.9)).frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color.opacity(0.82))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.42))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.isRefreshing ? Color.yellow : Color.green.opacity(0.72))
                .frame(width: 5, height: 5)
            Text(store.isRefreshing ? l10n.refreshInProgress : l10n.updatedAtText(date: store.lastUpdated))
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.38))
            Spacer()
            if !showSettings {
                Text(selection.selected.displayName)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.34))
            }
        }
    }

    private func localizedNote(for item: ProviderSnapshot) -> String {
        if item.provider == .gemini { return l10n.geminiUnimplemented }
        if item.provider == .claude && item.source == .unavailable { return l10n.claudeNotFoundHelp }
        return item.note ?? l10n.usageUnavailable
    }

    private var radarColor: Color {
        switch radar.signal {
        case .hot: return .red
        case .watch: return .yellow
        case .quiet: return .green
        case .stale, .offline: return .white.opacity(0.42)
        }
    }

    private var radarSourceState: String {
        switch radar.signal {
        case .hot: return "HOT"
        case .watch: return "WATCH"
        case .quiet: return "QUIET"
        case .stale: return "STALE"
        case .offline: return "OFFLINE"
        }
    }
}

private struct ConsoleIconButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 30, height: 30)
            .background(Circle().fill(active ? Color.white.opacity(0.10) : Color.white.opacity(configuration.isPressed ? 0.10 : 0.025)))
            .overlay(Circle().stroke(Color.white.opacity(active ? 0.12 : 0.04), lineWidth: 0.7))
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}
