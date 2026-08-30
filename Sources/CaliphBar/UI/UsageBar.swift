import SwiftUI
import CaliphBarCore

struct UsageBar: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                if let reset = window.resetsAt {
                    Text("Resets \(relative(reset))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.42))
                        .help(reset.formatted(date: .abbreviated, time: .shortened))
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(StatusColor.color(for: window.usedFraction))
                        .frame(width: max(4, geometry.size.width * min(1, window.usedFraction)))
                }
            }
            .frame(height: 5)

            Text("\(Int(window.usedFraction * 100))% used")
                .font(.system(size: 11))
                .foregroundStyle(window.usedFraction > 1 ? StatusColor.color(for: window.usedFraction) : .white.opacity(0.48))
        }
    }

    private func relative(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "now" }
        let totalMinutes = Int(interval / 60)
        if totalMinutes >= 24 * 60 { return "in \(totalMinutes / (24 * 60))d" }
        if totalMinutes >= 60 { return "in \(totalMinutes / 60)h \(totalMinutes % 60)m" }
        return "in \(max(1, totalMinutes))m"
    }
}
