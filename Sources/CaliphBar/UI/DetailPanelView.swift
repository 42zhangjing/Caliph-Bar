import SwiftUI
import AppKit
import CaliphBarCore

struct TrianglePointer: Shape {
    var isPointingRight: Bool = true

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if isPointingRight {
            // Triangle pointing right
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        } else {
            // Triangle pointing left
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
        }
        return p
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
    private let cardWidth: CGFloat = 286
    private let pointerLength: CGFloat = 34

    var body: some View {
        HStack(spacing: 0) {
            if side == .left { Color.clear.frame(width: pointerLength) }
            cardContent
                .frame(width: cardWidth)
            if side == .right { Color.clear.frame(width: pointerLength) }
        }
        .fixedSize()
        .background(
            IntegratedPointerPanelShape(side: side, pointerLength: pointerLength)
                .fill(backgroundColor)
        )
        .overlay(
            IntegratedPointerPanelShape(side: side, pointerLength: pointerLength)
                .stroke(Color.white.opacity(0.075), lineWidth: 0.75)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.42), radius: 18, x: side == .right ? -4 : 4, y: 7)
        .padding(28)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let item = store.item(for: selection.selected) {
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
                    VStack(spacing: 10) {
                        ForEach(Array(item.windows.prefix(3))) { window in
                            CompactUsageBar(window: window)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
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
        if window.id == "session" || window.title.localizedCaseInsensitiveContains("session") {
            return l10n.sessionUsage
        }
        if window.id == "weekly" || window.title.localizedCaseInsensitiveContains("week") {
            return l10n.weeklyUsage
        }
        return window.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
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
                        .animation(.easeInOut(duration: 0.38), value: window.remainingFraction)
                }
            }
            .frame(height: 4.5)

            Text(l10n.remainingPercentText(Int((window.remainingFraction * 100).rounded())))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(StatusColor.color(for: window.remainingFraction))
        }
    }
}

struct DetailPanelView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var selection: SelectionModel
    var side: EdgeSide = .right

    @ObservedObject private var l10n = L10n.shared
    @State private var showSettings = false
    @Namespace private var tabNamespace

    private let backgroundColor = Color(red: 0.045, green: 0.046, blue: 0.052)

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if side == .left {
                TrianglePointer(isPointingRight: false)
                    .fill(backgroundColor)
                    .frame(width: 14, height: 22)
            }

            cardContent
                .frame(width: 342)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.50), radius: 20, x: side == .right ? -4 : 4, y: 6)

            if side == .right {
                TrianglePointer(isPointingRight: true)
                    .fill(backgroundColor)
                    .frame(width: 14, height: 22)
            }
        }
        .fixedSize()
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if showSettings {
                SettingsView(store: store)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                providerCard
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }

            footer
                .padding(.bottom, 11)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(l10n.appTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                store.refresh()
            } label: {
                Image(systemName: store.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)
            .help(l10n.refresh)

            Button {
                withAnimation(.interpolatingSpring(stiffness: 320, damping: 26)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: showSettings ? "xmark" : "gearshape")
            }
            .buttonStyle(.plain)
            .help(l10n.settingsTitle)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help(l10n.quit)
        }
        .foregroundStyle(.white.opacity(0.72))
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            providerTabs

            if let item = store.item(for: selection.selected) {
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
                        ForEach(item.windows) { window in
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
                .id(selection.selected)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 4)),
                    removal: .opacity
                ))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.50)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07)))
    }

    private var providerTabs: some View {
        HStack(spacing: 6) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                Button {
                    withAnimation(.interpolatingSpring(stiffness: 350, damping: 28)) {
                        selection.selected = provider
                    }
                } label: {
                    HStack(spacing: 6) {
                        BrandMark(provider: provider, size: 15)
                        Text(provider.displayName)
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(selection.selected == provider ? .white : .white.opacity(0.38))
                    .padding(.horizontal, 9)
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
            }
        }
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
