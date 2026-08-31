import SwiftUI

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
        switch radar.signal {
        case .hot: return .red
        case .watch: return .yellow
        case .quiet: return .green.opacity(0.75)
        case .stale, .offline: return .white.opacity(0.24)
        }
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
        switch radar.signal {
        case .quiet: return l10n.isChinese ? "安静" : "QUIET"
        case .watch: return l10n.isChinese ? "关注" : "WATCH"
        case .hot: return l10n.isChinese ? "强信号" : "HOT"
        case .stale: return l10n.isChinese ? "旧情报" : "STALE"
        case .offline: return l10n.isChinese ? "离线" : "OFFLINE"
        }
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
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
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
        switch radar.signal {
        case .hot: return .red
        case .watch: return .yellow
        case .quiet: return .green.opacity(0.78)
        case .stale, .offline: return .white.opacity(0.28)
        }
    }

    private var signalLabel: String {
        switch radar.signal {
        case .quiet: return l10n.isChinese ? "安静" : "QUIET"
        case .watch: return l10n.isChinese ? "关注" : "WATCH"
        case .hot: return l10n.isChinese ? "强信号" : "HOT"
        case .stale: return l10n.isChinese ? "旧情报" : "STALE"
        case .offline: return l10n.isChinese ? "离线" : "OFFLINE"
        }
    }

    private var detailText: String {
        guard let snapshot = radar.snapshot else {
            return l10n.isChinese ? "等待公共情报" : "Waiting for public intelligence"
        }
        if snapshot.windowOpen == true {
            return l10n.isChinese ? "检测到额外重置窗口" : "Reset window detected"
        }
        if let summary = snapshot.summary, !summary.isEmpty {
            return summary
        }
        if let status = snapshot.status, !status.isEmpty {
            return status
        }
        return l10n.isChinese ? "暂无明确重置信号" : "No clear reset signal"
    }
}
