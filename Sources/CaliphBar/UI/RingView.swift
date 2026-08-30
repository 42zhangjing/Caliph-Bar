import SwiftUI
import CaliphBarCore

struct RingView: View {
    let provider: ProviderID
    let fraction: Double?
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 3.5)
            if let fraction {
                Circle()
                    .trim(from: 0, to: min(1, max(0.015, fraction)))
                    .stroke(
                        StatusColor.color(for: fraction),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            BrandMark(provider: provider, size: size * 0.45, color: fraction == nil ? .white.opacity(0.32) : .white)
        }
        .frame(width: size, height: size)
    }
}
