import SwiftUI

enum CodexRadarPresentation {
    static let brandColor = Color(red: 0.25, green: 0.86, blue: 0.66)

    static func statusColor(for signal: CodexRadarSignal) -> Color {
        switch signal {
        case .hot: return .red
        case .watch: return .yellow
        case .quiet: return .white.opacity(0.52)
        case .stale, .offline: return .white.opacity(0.34)
        }
    }

    static func statusLabel(
        for signal: CodexRadarSignal,
        isChinese: Bool,
        compact: Bool = false
    ) -> String {
        switch signal {
        case .hot:
            return isChinese ? (compact ? "强信号" : "强重置信号") : (compact ? "STRONG" : "STRONG SIGNAL")
        case .watch:
            return isChinese ? (compact ? "关注" : "值得关注") : "WATCH"
        case .quiet:
            return isChinese ? (compact ? "暂无待生效" : "暂无待生效重置") : (compact ? "NO PENDING" : "NO PENDING RESET")
        case .stale:
            return isChinese
                ? (compact ? "核验延迟/旧数据" : "核验延迟或数据陈旧")
                : (compact ? "DELAYED/OLD" : "VERIFICATION DELAYED / OLD DATA")
        case .offline:
            return isChinese ? (compact ? "离线" : "情报离线") : "OFFLINE"
        }
    }

    static func conciseDetail(for signal: CodexRadarSignal, isChinese: Bool) -> String {
        switch signal {
        case .hot:
            return isChinese
                ? "检测到较强的额外重置信号，请结合本机额度变化判断。"
                : "A strong extra-reset signal was detected; compare it with your local quota."
        case .watch:
            return isChinese
                ? "已宣布额度重置，等待确认生效。"
                : "A quota reset was announced; awaiting confirmation."
        case .quiet:
            return isChinese
                ? "当前没有等待生效的额度重置。"
                : "There is no pending quota reset right now."
        case .stale:
            return isChinese
                ? "AIHOT 核验延迟或数据超过 2 小时未更新。"
                : "AIHOT verification is delayed or the data is over two hours old."
        case .offline:
            return isChinese
                ? "暂时无法读取公共重置情报。"
                : "Public reset intelligence is temporarily unavailable."
        }
    }
}

struct CodexRadarBadge: View {
    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(spacing: 4) {
            Text("Radar")
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
            Circle()
                .fill(signalColor)
                .frame(width: 5, height: 5)
        }
        .help(helpText)
    }

    private var signalColor: Color {
        CodexRadarPresentation.statusColor(for: radar.signal)
    }

    private var helpText: String {
        let state = signalLabel
        if let probability = radar.snapshot?.probability24h {
            let percent = Int((probability * 100).rounded())
            return l10n.isChinese ? "Codex Radar · \(state) · 24h \(percent)%" : "Codex Radar · \(state) · 24h \(percent)%"
        }
        return "Codex Radar · \(state)"
    }

    private var signalLabel: String {
        CodexRadarPresentation.statusLabel(for: radar.signal, isChinese: l10n.isChinese, compact: true)
    }
}

struct CodexRadarDetailStrip: View {
    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    private var sourceURL: URL {
        URL(string: "https://aihot.news/codex-reset")!
    }

    var body: some View {
        Link(destination: sourceURL) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(signalColor.opacity(0.15))
                        .frame(width: 27, height: 27)
                    Circle()
                        .fill(signalColor)
                        .frame(width: 6, height: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("RESET RADAR · AIHOT")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))

                        Text(signalLabel)
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(signalColor)
                    }

                    Text(detailText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if let confirmation = freshConfirmation {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(l10n.isChinese ? "本机确认" : "LOCAL")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.green.opacity(0.9))
                        Text(confirmationText(confirmation))
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                } else if let target = radar.snapshot?.event?.target, radar.signal == .watch || radar.signal == .hot {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(l10n.isChinese ? "AIHOT 预计" : "AIHOT EST.")
                            .font(.system(size: 8, weight: .bold))
                        Text(target.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.64))
                } else if let closesAt = radar.snapshot?.announcement?.closesAt, closesAt > Date() {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(l10n.isChinese ? "预计" : "TARGET")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.85))
                        Text(formattedTargetTime(closesAt))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                    }
                } else if radar.snapshot?.windowOpen == true, radar.snapshot?.announcement != nil {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(l10n.isChinese ? "状态" : "STATE")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.85))
                        Text(l10n.isChinese ? "等待确认" : "WAITING")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                    }
                } else if let probability = radar.snapshot?.probability24h {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("24H")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.28))
                        Text("\(Int((probability * 100).rounded()))%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.22))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.055), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .help(l10n.isChinese ? "公共情报，与账户真实额度分离。数据来源：AIHOT。" : "Public intelligence, separate from account truth. Data from AIHOT.")
    }

    private var freshConfirmation: CodexLocalResetConfirmation? {
        // "Local confirmed" is a correlation label, not merely a local quota jump.
        // Only surface it while the independent public Radar is actively WATCH/HOT.
        guard radar.signal == .watch || radar.signal == .hot,
              let confirmation = radar.localConfirmation,
              Date().timeIntervalSince(confirmation.observedAt) < 6 * 60 * 60
        else { return nil }
        return confirmation
    }

    private var signalColor: Color {
        CodexRadarPresentation.statusColor(for: radar.signal)
    }

    private var signalLabel: String {
        CodexRadarPresentation.statusLabel(for: radar.signal, isChinese: l10n.isChinese, compact: true)
    }

    private var detailText: String {
        if radar.signal == .stale || radar.signal == .offline {
            return CodexRadarPresentation.conciseDetail(for: radar.signal, isChinese: l10n.isChinese)
        }
        if let event = radar.snapshot?.event {
            return event.headline(isChinese: l10n.isChinese) + " · " + event.detail(isChinese: l10n.isChinese)
        }
        if let announcement = radar.snapshot?.announcement {
            if let lead = announcement.lead, !lead.isEmpty {
                return "\(announcement.headline) (\(lead))"
            }
            return announcement.headline
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

    private func confirmationText(_ c: CodexLocalResetConfirmation) -> String {
        let before = Int((c.beforeRemaining * 100).rounded())
        let after = Int((c.afterRemaining * 100).rounded())
        return "\(before)→\(after)%"
    }

    private func formattedTargetTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
