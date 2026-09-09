import SwiftUI
import AppKit
import CaliphBarCore

enum SideDetailPanelLayout {
    static let cardWidth: CGFloat = 286
    // Fixed across every provider. The extra height allows Codex to expose up to four
    // account-truth quota lanes without making the panel resize while hovering providers.
    // Four Antigravity lanes need a real bottom safety area; the edge rail itself stays compact.
    static let cardHeight: CGFloat = 228
    static let pointerLength: CGFloat = 28
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
    var pointerOffsetY: CGFloat = 0

    var animatableData: CGFloat {
        get { pointerOffsetY }
        set { pointerOffsetY = newValue }
    }

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
        let midY = min(max(rect.midY + pointerOffsetY, rect.minY + radius + 14), rect.maxY - radius - 14)
        let transitionHalfHeight = min(28, rect.height * 0.24)
        let pointerBaseHalfHeight = min(10, rect.height * 0.12)
        let shoulderReach = min(6, pointerLength * 0.22)

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
            control2: CGPoint(x: rect.maxX - pointerLength * 0.34, y: midY - 3.5)
        )
        path.addCurve(
            to: CGPoint(x: bodyMaxX + shoulderReach, y: midY + pointerBaseHalfHeight),
            control1: CGPoint(x: rect.maxX - pointerLength * 0.34, y: midY + 3.5),
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

    private var previewProvider: ProviderID {
        selection.sidePreview ?? selection.selected
    }

    var body: some View {
        HStack(spacing: 0) {
            if side == .left {
                Color.clear.frame(width: SideDetailPanelLayout.pointerLength)
            }

            ZStack(alignment: .topLeading) {
                if let item = store.item(for: previewProvider) {
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
            IntegratedPointerPanelShape(
                side: side,
                pointerLength: SideDetailPanelLayout.pointerLength,
                pointerOffsetY: selection.sidePointerOffset
            )
            .fill(backgroundColor)
        )
        .overlay(
            IntegratedPointerPanelShape(
                side: side,
                pointerLength: SideDetailPanelLayout.pointerLength,
                pointerOffsetY: selection.sidePointerOffset
            )
            .stroke(Color.white.opacity(0.065), lineWidth: 0.75)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
        .padding(SideDetailPanelLayout.shadowPadding)
        .animation(.easeOut(duration: 0.16), value: previewProvider)
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

                Spacer(minLength: 8)
                if item.provider == .codex {
                    CodexRadarBadge()
                }
                sourceIndicator(item.source)

                Button {
                    NSWorkspace.shared.open(providerConsoleURL(for: item.provider))
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(l10n.isChinese ? "在浏览器中打开官方用量后台" : "Open official usage console in browser")
            }

            if item.windows.isEmpty {
                Text(localizedNote(for: item))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(item.windows.prefix(4))) { window in
                        CompactUsageBar(window: window)
                    }
                }
            }

            if item.provider == .codex && item.windows.count <= 2 {
                CodexMiniRadarInlineBlock()
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
            return item.note ?? l10n.claudeNotFoundHelp
        }
        return item.note ?? l10n.usageUnavailable
    }

    private func providerConsoleURL(for provider: ProviderID) -> URL {
        switch provider {
        case .claude:
            return URL(string: "https://console.anthropic.com/settings/usage")!
        case .codex:
            return URL(string: "https://chatgpt.com/#settings/Account")!
        case .gemini:
            return URL(string: "https://aistudio.google.com/")!
        }
    }
}

private struct CodexMiniRadarInlineBlock: View {
    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
                .padding(.vertical, 2)

            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CodexRadarPresentation.brandColor)
                Text("RESET RADAR")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                if let closesAt = radar.snapshot?.announcement?.closesAt, closesAt > Date() {
                    Text(l10n.isChinese ? "预计 \(formattedTime(closesAt))" : "Target \(formattedTime(closesAt))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                } else if radar.snapshot?.windowOpen == true, let ann = radar.snapshot?.announcement {
                    let isComplete = { () -> Bool in
                        let text = [ann.headline, ann.lead, ann.detail].compactMap { $0 }.joined(separator: " ").lowercased()
                        return ["已完成", "站长确认", "completed", "done"].contains(where: { text.contains($0) })
                    }()
                    if isComplete {
                        Text(l10n.isChinese ? "已完成" : "Done")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.25, green: 0.86, blue: 0.66))
                    } else {
                        Text(l10n.isChinese ? "等待确认" : "Pending")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                    }
                } else if let prob = radar.snapshot?.probability24h {
                    Text("24H \(Int((prob * 100).rounded()))%")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.68))
                }
                if let ann = radar.snapshot?.announcement, {
                    let text = [ann.headline, ann.lead, ann.detail].compactMap { $0 }.joined(separator: " ").lowercased()
                    return ["已完成", "站长确认", "completed", "done"].contains(where: { text.contains($0) })
                }() {
                    Text(l10n.isChinese ? "已完成" : "Done")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.86, blue: 0.66))
                } else {
                    Text(CodexRadarPresentation.statusLabel(for: radar.signal, isChinese: l10n.isChinese, compact: true))
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(CodexRadarPresentation.statusColor(for: radar.signal))
                }
            }

            if let ann = radar.snapshot?.announcement {
                Text("\(ann.headline)：\(ann.lead ?? ann.detail ?? "")")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if radar.snapshot?.windowOpen == true, let message = radar.snapshot?.message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let summary = radar.snapshot?.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct CompactUsageBar: View {
    let window: UsageWindow
    @ObservedObject private var l10n = L10n.shared
    @State private var isHovered = false

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
                    Text(resetTimeString(for: reset))
                        .font(.system(size: 9, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(isHovered ? .white.opacity(0.88) : .white.opacity(0.68))
                        .help(reset.formatted(date: .abbreviated, time: .shortened))
                        .animation(.easeOut(duration: 0.15), value: isHovered)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16))
                        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    if window.remainingFraction > 0.001 {
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
            }
            .frame(height: 4)

            Text(l10n.remainingPercentText(Int((window.remainingFraction * 100).rounded())))
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(StatusColor.valueColor(for: window.remainingFraction))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(isHovered ? 0.035 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }

    private func resetTimeString(for reset: Date) -> String {
        if isHovered {
            return reset.formatted(date: .abbreviated, time: .shortened)
        }
        return l10n.resetsText(at: reset)
    }
}

struct SideRadarPanelView: View {
    let side: EdgeSide
    @ObservedObject var selection: SelectionModel
    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(spacing: 0) {
            if side == .left { Color.clear.frame(width: SideDetailPanelLayout.pointerLength) }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CodexRadarPresentation.brandColor)
                    Text("RESET RADAR")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(signalLabel)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(signalColor)
                }

                Text(l10n.publicIntelligenceTitle)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.40))

                HStack(spacing: 10) {
                    if let closesAt = radar.snapshot?.announcement?.closesAt, closesAt > Date() {
                        countdownCell(target: closesAt)
                        targetTimeCell(target: closesAt)
                    } else if let announcement = radar.snapshot?.announcement, radar.snapshot?.windowOpen == true {
                        if isCompletionAnnouncement(announcement) {
                            confirmedCompleteCell(headline: announcement.headline)
                        } else {
                            let text = announcement.expiredText ?? (l10n.isChinese ? "等待官方确认重置完成" : "Pending Official Confirmation")
                            pendingConfirmationCell(text: text)
                        }
                        scopeCell
                    } else if radar.snapshot?.windowOpen == true {
                        activeWindowCell
                        scopeCell
                    } else {
                        probabilityCell("24H", value: radar.snapshot?.probability24h)
                        probabilityCell("48H", value: radar.snapshot?.probability48h)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let headline = headlineText {
                        Text(headline)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                    }

                    Text(detailText)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(headlineText != nil ? 3 : 4)
                        .fixedSize(horizontal: false, vertical: true)

                    if let sub = subDetailText, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 8.5))
                            .foregroundStyle(Color.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Text(l10n.isChinese ? "数据来自 Codex 雷达 · 不影响账户额度" : "Codex Radar · separate from account quota")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.32))
                    Spacer(minLength: 4)
                    Link(l10n.isChinese ? "查看完整" : "View full", destination: sourceURL)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .padding(14)
            .frame(width: SideDetailPanelLayout.cardWidth, height: SideDetailPanelLayout.cardHeight, alignment: .topLeading)

            if side == .right { Color.clear.frame(width: SideDetailPanelLayout.pointerLength) }
        }
        .frame(width: SideDetailPanelLayout.cardWidth + SideDetailPanelLayout.pointerLength, height: SideDetailPanelLayout.cardHeight)
        .background(
            IntegratedPointerPanelShape(
                side: side,
                pointerLength: SideDetailPanelLayout.pointerLength,
                pointerOffsetY: selection.sidePointerOffset
            )
            .fill(Color(red: 0.025, green: 0.026, blue: 0.030))
        )
        .overlay(
            IntegratedPointerPanelShape(
                side: side,
                pointerLength: SideDetailPanelLayout.pointerLength,
                pointerOffsetY: selection.sidePointerOffset
            )
            .stroke(Color.white.opacity(0.065), lineWidth: 0.75)
        )
        .padding(SideDetailPanelLayout.shadowPadding)
        .onAppear {
            radar.refreshIfNeeded()
        }
    }

    /// Returns true if the announcement headline/lead/detail explicitly indicates reset is complete
    private func isCompletionAnnouncement(_ ann: CodexRadarAnnouncement) -> Bool {
        let text = [ann.headline, ann.lead, ann.detail]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        let completionKeywords = ["已完成", "完成确认", "站长确认", "reset complete", "completed", "confirmed complete", "done"]
        return completionKeywords.contains(where: text.contains)
    }

    private func confirmedCompleteCell(headline: String) -> some View {
        let green = Color(red: 0.25, green: 0.86, blue: 0.66)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(l10n.isChinese ? "重置状态" : "STATUS")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(green)
                Spacer()
                Text(l10n.isChinese ? "已完成" : "DONE")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundStyle(green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(green.opacity(0.14)))
            }
            Text(headline)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(green.opacity(0.10)))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(green.opacity(0.25), lineWidth: 0.75)
        )
    }

    private func pendingConfirmationCell(text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(l10n.isChinese ? "重置状态" : "STATUS")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                Spacer()
                Text(l10n.isChinese ? "进行中" : "OPEN")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.red.opacity(0.9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.red.opacity(0.14)))
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.10)))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.25), lineWidth: 0.75)
        )
    }

    private func countdownCell(target: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = max(0, target.timeIntervalSince(context.date))
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            let seconds = Int(remaining) % 60
            let formatted = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

            VStack(alignment: .leading, spacing: 3) {
                Text(l10n.isChinese ? "距离预计重置" : "RESET IN")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                Text(formatted)
                    .font(.system(size: 19, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.28), lineWidth: 0.75)
            )
        }
    }

    private func targetTimeCell(target: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: target)

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(l10n.isChinese ? "预计节点" : "TARGET TIME")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
                Spacer()
                Text(l10n.isChinese ? "已公告" : "ANNOUNCED")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.14))
                    )
            }
            Text(timeString)
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
    }

    private var activeWindowCell: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(l10n.isChinese ? "重置窗口" : "RESET WINDOW")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
                Spacer()
                Text(l10n.isChinese ? "进行中" : "OPEN")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.red.opacity(0.9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.red.opacity(0.14)))
            }
            Text(l10n.isChinese ? "已开启" : "ACTIVE")
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.red.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.red.opacity(0.08)))
    }

    private var scopeCell: some View {
        let scope = radar.snapshot?.windowScope ?? (l10n.isChinese ? "所有付费计划" : "Paid Plans")
        return VStack(alignment: .leading, spacing: 3) {
            Text(l10n.isChinese ? "受惠计划" : "SCOPE")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
            Text(scope)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
    }

    private func probabilityCell(_ label: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
            Text(value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
    }

    private var isCompletedState: Bool {
        if let ann = radar.snapshot?.announcement {
            return isCompletionAnnouncement(ann)
        }
        return false
    }

    private var signalColor: Color {
        if isCompletedState {
            return Color(red: 0.25, green: 0.86, blue: 0.66)
        }
        return CodexRadarPresentation.statusColor(for: radar.signal)
    }

    private var signalLabel: String {
        if isCompletedState {
            return l10n.isChinese ? "已完成" : "DONE"
        }
        return CodexRadarPresentation.statusLabel(
            for: radar.signal,
            isChinese: l10n.isChinese,
            compact: true
        )
    }

    private var headlineText: String? {
        if let announcement = radar.snapshot?.announcement {
            if let lead = announcement.lead, !lead.isEmpty {
                return "\(announcement.headline) · \(lead)"
            }
            return announcement.headline
        }
        if radar.snapshot?.windowOpen == true {
            return radar.snapshot?.windowTitle ?? (l10n.isChinese ? "Codex 用量限制重置" : "Codex Quota Reset")
        }
        return nil
    }

    private var detailText: String {
        if let announcement = radar.snapshot?.announcement, let detail = announcement.detail, !detail.isEmpty {
            return detail
        }
        if radar.snapshot?.windowOpen == true, let message = radar.snapshot?.message, !message.isEmpty {
            return message
        }
        if radar.signal == .stale {
            return CodexRadarPresentation.conciseDetail(for: .stale, isChinese: l10n.isChinese)
        }
        if let summary = radar.snapshot?.summary, !summary.isEmpty {
            return summary
        }
        return CodexRadarPresentation.conciseDetail(for: radar.signal, isChinese: l10n.isChinese)
    }

    private var subDetailText: String? {
        if radar.snapshot?.announcement != nil {
            var parts: [String] = []
            if let msg = radar.snapshot?.message, !msg.isEmpty { parts.append(msg) }
            if let scope = radar.snapshot?.windowScope, !scope.isEmpty { parts.append(scope) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        if radar.snapshot?.windowOpen == true {
            return radar.snapshot?.windowScope
        }
        return nil
    }

    private var sourceURL: URL {
        // "查看完整" always opens the Codex Radar homepage, not a third-party source post
        URL(string: "https://codexradar.com/")!
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
    // One stable footprint across providers/settings, including four Codex quota lanes
    // plus the independent Reset Radar strip.
    private let contentHeight: CGFloat = 430

    var body: some View {
        InstrumentConsoleView(store: store, selection: selection)
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

            if item.provider == .codex {
                CodexRadarDetailStrip()
                    .padding(.top, 1)
            }
        }
    }

    private var providerTabs: some View {
        HStack(spacing: 4) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selection.selectFromMenu(provider)
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
