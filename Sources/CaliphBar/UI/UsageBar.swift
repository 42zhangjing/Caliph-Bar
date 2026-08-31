import SwiftUI
import CaliphBarCore

struct UsageBar: View {
    let window: UsageWindow
    @ObservedObject private var l10n = L10n.shared

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
                    Text(l10n.resetsText(at: reset))
                        .font(.system(size: 10.5))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.45))
                        .help(reset.formatted(date: .abbreviated, time: .shortened))
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(StatusColor.color(for: window.remainingFraction))
                        .frame(width: max(4, geometry.size.width * CGFloat(min(1.0, max(0.0, window.remainingFraction)))))
                        .animation(.easeOut(duration: 0.24), value: window.remainingFraction)
                }
            }
            .frame(height: 5)

            let remainingPercent = Int((window.remainingFraction * 100).rounded())
            Text(l10n.remainingPercentText(remainingPercent))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(StatusColor.color(for: window.remainingFraction))
        }
    }
}
