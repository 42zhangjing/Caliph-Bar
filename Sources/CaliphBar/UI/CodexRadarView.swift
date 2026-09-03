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
            return isChinese ? (compact ? "暂无信号" : "暂无重置信号") : (compact ? "NO SIGNAL" : "NO RESET SIGNAL")
        case .stale:
            return isChinese
                ? (compact ? "超2小时未更新" : "数据超2小时未更新")
                : (compact ? ">2H OLD" : "DATA >2H OLD")
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
                ? "额外重置信号正在升温，建议继续观察。"
                : "The extra-reset signal is rising; keep watching for confirmation."
        case .quiet:
            return isChinese
                ? "当前没有明确的额外重置信号。"
                : "There is no clear extra-reset signal right now."
        case .stale:
            return isChinese
                ? "以上概率数据超过 2 小时未更新，正在等待 Radar 刷新。"
                : "The probabilities above are over two hours old and awaiting a Radar refresh."
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

    private let sourceURL = URL(string: "https://codexradar.com/")!

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
                        Text("RESET RADAR")
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
                        Text("\(Int((confirmation.beforeRemaining * 100).rounded()))→\(Int((confirmation.afterRemaining * 100).rounded()))%")
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.52))
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
        .help(l10n.isChinese ? "公共情报，与账户真实额度分离。数据来自 Codex 雷达。" : "Public intelligence, separate from account truth. Data from Codex Radar.")
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
        if let summary = radar.snapshot?.summary, !summary.isEmpty {
            return summary
        }
        return CodexRadarPresentation.conciseDetail(for: radar.signal, isChinese: l10n.isChinese)
    }
}
