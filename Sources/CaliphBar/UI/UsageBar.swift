import SwiftUI
import CaliphBarCore

struct UsageBar: View {
    let window: UsageWindow
    @ObservedObject private var l10n = L10n.shared
    @State private var isHovered = false

    var localizedTitle: String {
        switch window.id {
        case "session": return l10n.sessionUsage
        case "weekly": return l10n.weeklyUsage
        case "codex-spark-session": return l10n.codexSparkSessionUsage
        case "codex-spark-weekly": return l10n.codexSparkWeeklyUsage
        default: return window.title
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizedTitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                if let reset = window.resetsAt {
                    Text(resetTimeString(for: reset))
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(isHovered ? .white.opacity(0.88) : .white.opacity(0.68))
                        .help(reset.formatted(date: .abbreviated, time: .shortened))
                        .animation(.easeOut(duration: 0.15), value: isHovered)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    if window.remainingFraction > 0.001 {
                        Capsule()
                            .fill(StatusColor.color(for: window.remainingFraction))
                            .frame(width: max(4, geometry.size.width * CGFloat(min(1.0, max(0.0, window.remainingFraction)))))
                            .animation(.easeOut(duration: 0.24), value: window.remainingFraction)
                    }
                }
            }
            .frame(height: 5)

            let remainingPercent = Int((window.remainingFraction * 100).rounded())
            Text(l10n.remainingPercentText(remainingPercent))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(StatusColor.valueColor(for: window.remainingFraction))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
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
