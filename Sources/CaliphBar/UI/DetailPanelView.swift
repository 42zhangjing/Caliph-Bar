import SwiftUI
import AppKit
import CaliphBarCore

enum SideDetailPanelLayout {
    static let cardWidth: CGFloat = 286
    // Fixed across every provider. The extra height allows Codex to expose up to four
    // account-truth quota lanes without making the panel resize while hovering providers.
    static let cardHeight: CGFloat = 204
    static let pointerLength: CGFloat = 34
    static let shadowPadding: CGFloat = 16

    static var contentSize: CGSize {
        CGSize(
            width: cardWidth + pointerLength + shadowPadding * 2,
            height: cardHeight + shadowPadding * 2
        )
    }
}

private struct IntegratedPointerPanelShape: Shape {
    let side: EdgeSide
    let pointerLength: CGFloat

    func path(in rect: CGRect) -> Path {
        let rightPath = pathPointingRight(in: rect)
        guard side == .left else { return rightPath }
        return rightPath.applying(
            CGAffineTransform(translationX: rect.width, y: 0)
                .scaledBy(x: -1, y: 1)
        )
    }

    private func pathPointingRight(in rect: CGRect) -> Path {
        let radius = min(16, rect.height / 2)
        let bodyMaxX = rect.maxX - pointerLength
        let midY = rect.midY
        let transitionHalfHeight = min(34, rect.height * 0.30)
        let pointerBaseHalfHeight = min(13, rect.height * 0.16)
        let shoulderReach = min(8, pointerLength * 0.24)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: bodyMaxX - radius, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: bodyMaxX, y: rect.minY + radius),
            control1: CGPoint(x: bodyMaxX - radius * 0.42, y: rect.minY),
            control2: CGPoint(x: bodyMaxX, y: rect.minY + radius * 0.42)
        )
        path.addLine(to: CGPoint(x: bodyMaxX, y: midY - transitionHalfHeight))
        path.addCurve(
            to: CGPoint(x: bodyMaxX + shoulderReach, y: midY - pointerBaseHalfHeight),
            control1: CGPoint(x: bodyMaxX, y: midY - transitionHalfHeight * 0.68),
            control2: CGPoint(x: bodyMaxX + shoulderReach * 0.45, y: midY - pointerBaseHalfHeight * 1.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: midY),
            control1: CGPoint(x: bodyMaxX + shoulderReach * 0.78, y: midY - pointerBaseHalfHeight * 0.92),
            control2: CGPoint(x: rect.maxX - pointerLength * 0.34, y: midY - 5)
        )
        path.addCurve(
            to: CGPoint(x: bodyMaxX + shoulderReach, y: midY + pointerBaseHalfHeight),
            control1: CGPoint(x: rect.maxX - pointerLength * 0.34, y: midY + 5),
            control2: CGPoint(x: bodyMaxX + shoulderReach * 0.78, y: midY + pointerBaseHalfHeight * 0.92)
        )
        path.addCurve(
            to: CGPoint(x: bodyMaxX, y: midY + transitionHalfHeight),
            control1: CGPoint(x: bodyMaxX + shoulderReach * 0.45, y: midY + pointerBaseHalfHeight * 1.08),
            control2: CGPoint(x: bodyMaxX, y: midY + transitionHalfHeight * 0.68)
        )
        path.addLine(to: CGPoint(x: bodyMaxX, y: rect.maxY - radius))
        path.addCurve(
            to: CGPoint(x: bodyMaxX - radius, y: rect.maxY),
            control1: CGPoint(x: bodyMaxX, y: rect.maxY - radius * 0.42),
            control2: CGPoint(x: bodyMaxX - radius * 0.42, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control1: CGPoint(x: rect.minX + radius * 0.42, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - radius * 0.42)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + radius * 0.42),
            control2: CGPoint(x: rect.minX + radius * 0.42, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct SideDetailPanelView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var selection: SelectionModel
    let side: EdgeSide

    @ObservedObject private var l10n = L10n.shared
    private let backgroundColor = Color(red: 0.025, green: 0.026, blue: 0.030)

    var body: some View {
        HStack(spacing: 0) {
            if side == .left {
                Color.clear.frame(width: SideDetailPanelLayout.pointerLength)
            }

            ZStack(alignment: .topLeading) {
                if let item = store.item(for: selection.selected) {
                    providerContent(item)
                        .id(item.provider)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 3)),
                                removal: .opacity.combined(with: .offset(y: -2))
                            )
                        )
                }
            }
            .frame(
                width: SideDetailPanelLayout.cardWidth,
                height: SideDetailPanelLayout.cardHeight,
                alignment: .topLeading
            )

            if side == .right {
                Color.clear.frame(width: SideDetailPanelLayout.pointerLength)
            }
        }
        .frame(
            width: SideDetailPanelLayout.cardWidth + SideDetailPanelLayout.pointerLength,
            height: SideDetailPanelLayout.cardHeight
        )
        .background(
            IntegratedPointerPanelShape(side: side, pointerLength: SideDetailPanelLayout.pointerLength)
                .fill(backgroundColor)
        )
        .overlay(
            IntegratedPointerPanelShape(side: side, pointerLength: SideDetailPanelLayout.pointerLength)
                .stroke(Color.white.opacity(0.065), lineWidth: 0.75)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
        .padding(SideDetailPanelLayout.shadowPadding)
        .animation(.easeOut(duration: 0.16), value: selection.selected)
    }

    private func providerContent(_ item: ProviderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                BrandMark(provider: item.provider, size: 19)

                Text(l10n.providerUsageTitle(item.provider.displayName))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                if let plan = item.planLabel {
                    Text(plan)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                }

                Spacer(minLength: 10)
                sourceIndicator(item.source)
            }

            if item.windows.isEmpty {
                Text(localizedNote(for: item))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 7) {
                    ForEach(Array(item.windows.prefix(4))) { window in
                        CompactUsageBar(window: window)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(
            width: SideDetailPanelLayout.cardWidth,
            height: SideDetailPanelLayout.cardHeight,
            alignment: .topLeading
        )
    }

    private func sourceIndicator(_ source: UsageSourceKind) -> some View {
        let label: String
        switch source {
        case .live: label = l10n.statusLive
        case .estimated: label = l10n.statusEstimated
        case .stale: label = l10n.statusStale
        case .unavailable: label = l10n.statusOffline
        }

        return HStack(spacing: 4) {
            Circle()
                .fill(source == .live ? Color.green : Color.white.opacity(0.28))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
        }
    }

    private func localizedNote(for item: ProviderSnapshot) -> String {
        if item.provider == .gemini { return l10n.geminiUnimplemented }
        if item.provider == .claude && item.source == .unavailable {
            return l10n.claudeNotFoundHelp
        }
        return item.note ?? l10n.usageUnavailable
    }
}

private struct CompactUsageBar: View {
    let window: UsageWindow
    @ObservedObject private var l10n = L10n.shared

    private var localizedTitle: String {
        switch window.id {
        case "session": return l10n.sessionUsage
        case "weekly": return l10n.weeklyUsage
        case "codex-spark-session": return l10n.codexSparkSessionUsage
        case "codex-spark-weekly": return l10n.codexSparkWeeklyUsage
        default: return window.title
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3.5) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizedTitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))

                Spacer()

                if let reset = window.resetsAt {
                    Text(l10n.resetsText(at: reset))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.34))
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.11))
                    Capsule()
                        .fill(StatusColor.color(for: window.remainingFraction))
                        .frame(
                            width: max(
                                4,
                                geometry.size.width * CGFloat(min(1, max(0, window.remainingFraction)))
                            )
                        )
                        .animation(.easeOut(duration: 0.22), value: window.remainingFraction)
                }
            }
            .frame(height: 4)

            Text(l10n.remainingPercentText(Int((window.remainingFraction * 100).rounded())))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(StatusColor.color(for: window.remainingFraction))
        }
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .frame(width: 26, height: 26)
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.001))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

struct DetailPanelView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var selection: SelectionModel

    @ObservedObject private var l10n = L10n.shared
    @State private var showSettings = false
    @Namespace private var tabNamespace

    private let backgroundColor = Color(red: 0.045, green: 0.046, blue: 0.052)
    private let cardWidth: CGFloat = 342
    // Keep one footprint across providers/settings while leaving room for four Codex lanes.
    private let contentHeight: CGFloat = 326

    var body: some View {
        cardContent
            .frame(width: cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.075), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
            .fixedSize()
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ZStack(alignment: .top) {
                if showSettings {
                    SettingsView(store: store)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    providerCard
                        .transition(.opacity.combined(with: .scale(scale: 0.995)))
                }
            }
            .frame(height: contentHeight, alignment: .top)
            .padding(.horizontal, 14)

            footer
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .animation(.easeOut(duration: 0.16), value: showSettings)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(showSettings ? l10n.settingsTitle : l10n.appTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            if !showSettings {
                Button {
                    store.refresh()
                } label: {
                    Image(systemName: store.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .buttonStyle(HeaderIconButtonStyle())
                .disabled(store.isRefreshing)
                .help(l10n.refresh)
            }

            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: showSettings ? "xmark" : "gearshape")
            }
            .buttonStyle(HeaderIconButtonStyle())
            .help(l10n.settingsTitle)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(HeaderIconButtonStyle())
            .help(l10n.quit)
        }
        .foregroundStyle(.white.opacity(0.72))
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            providerTabs

            ZStack(alignment: .topLeading) {
                if let item = store.item(for: selection.selected) {
                    providerContent(item)
                        .id(item.provider)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 4)),
                                removal: .opacity.combined(with: .offset(y: -2))
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(height: contentHeight, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.46)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.065), lineWidth: 0.8))
        .animation(.easeOut(duration: 0.16), value: selection.selected)
    }

    private func providerContent(_ item: ProviderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                BrandMark(provider: item.provider, size: 24)
                Text(item.provider.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                if let plan = item.planLabel {
                    Text(plan)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                sourceBadge(item.source)
            }

            if item.windows.isEmpty {
                Text(localizedNote(for: item))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(item.windows.prefix(4)) { window in
                    UsageBar(window: window)
                }
                if let note = item.note {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.36))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var providerTabs: some View {
        HStack(spacing: 4) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selection.selected = provider
                    }
                } label: {
                    HStack(spacing: 6) {
                        BrandMark(provider: provider, size: 15)
                        Text(provider.displayName)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection.selected == provider ? .white : .white.opacity(0.40))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        if selection.selected == provider {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .matchedGeometryEffect(id: "tabHighlight", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.035)))
    }

    private func sourceBadge(_ source: UsageSourceKind) -> some View {
        let text: String
        switch source {
        case .live: text = l10n.statusLive
        case .estimated: text = l10n.statusEstimated
        case .stale: text = l10n.statusStale
        case .unavailable: text = l10n.statusOffline
        }
        return Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(source == .live ? Color.green.opacity(0.9) : Color.white.opacity(0.48))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.07)))
    }

    private func localizedNote(for item: ProviderSnapshot) -> String {
        if item.provider == .gemini {
            return l10n.geminiUnimplemented
        } else if item.provider == .claude && item.source == .unavailable {
            return l10n.claudeNotFoundHelp
        }
        return item.note ?? l10n.usageUnavailable
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(store.isRefreshing ? Color.yellow : Color.white.opacity(0.25))
                .frame(width: 5, height: 5)

            Text(l10n.updatedAtText(date: store.lastUpdated))
        }
        .font(.system(size: 9.5))
        .foregroundStyle(.white.opacity(0.30))
    }
}
