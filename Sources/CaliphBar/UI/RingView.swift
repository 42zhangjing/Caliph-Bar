import SwiftUI
import CaliphBarCore

struct RingView: View {
    let provider: ProviderID
    let remainingFraction: Double?
    var size: CGFloat = 42

    @State private var displayedFraction: Double = 0.0
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.020, green: 0.021, blue: 0.026))
                .padding(5.5)

            Circle()
                .stroke(Color(red: 0.96, green: 0.93, blue: 0.88).opacity(0.24), lineWidth: 3.5)

            // Animated progress ring for remaining quota
            if remainingFraction != nil {
                Circle()
                    .trim(from: 0, to: min(1, max(0.015, displayedFraction)))
                    .stroke(
                        StatusColor.color(for: displayedFraction),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            BrandMark(
                provider: provider,
                size: size * 0.52,
                isMuted: false
            )
        }
        .frame(width: size, height: size)
        .onAppear {
            if let fraction = remainingFraction {
                withAnimation(.interpolatingSpring(stiffness: 140, damping: 18)) {
                    displayedFraction = fraction
                }
            }
            hasAppeared = true
        }
        .onChange(of: remainingFraction) { newFraction in
            guard let newFraction else {
                displayedFraction = 0.0
                return
            }
            withAnimation(.easeInOut(duration: 0.45)) {
                displayedFraction = newFraction
            }
        }
    }
}
