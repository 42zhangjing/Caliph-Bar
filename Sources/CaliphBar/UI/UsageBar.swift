import SwiftUI
import CaliphBarCore

struct UsageBar: View {
    let window: UsageWindow
    @ObservedObject private var l10n = L10n.shared

    var localizedTitle: String {
        if window.id == "session" || window.title.localizedCaseInsensitiveContains("session") {
            return l10n.sessionUsage
        } else if window.id == "weekly" || window.title.localizedCaseInsensitiveContains("week") {
            return l10n.weeklyUsage
        }
        return window.title
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
                        .animation(.interpolatingSpring(stiffness: 140, damping: 18), value: window.remainingFraction)
                }
            }
            .frame(height: 5)

            let remainingPercent = Int((window.remainingFraction * 100).rounded())
            Text(l10n.remainingPercentText(remainingPercent))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StatusColor.color(for: window.remainingFraction))
        }
    }
}

