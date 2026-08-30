import SwiftUI
import CaliphBarCore

struct RingView: View {
    let provider: ProviderID
    let remainingFraction: Double?
    var size: CGFloat = 42

    @State private var displayedFraction: Double = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.020, green: 0.021, blue: 0.026))
                .padding(5.5)

            Circle()
                .stroke(Color(red: 0.96, green: 0.93, blue: 0.88).opacity(0.24), lineWidth: 3.5)

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
            guard let fraction = remainingFraction else { return }
            withAnimation(.easeOut(duration: 0.52)) {
                displayedFraction = fraction
            }
        }
        .onChange(of: remainingFraction) { newFraction in
            guard let newFraction else {
                displayedFraction = 0.0
                return
            }
            withAnimation(.easeOut(duration: 0.24)) {
                displayedFraction = newFraction
            }
        }
    }
}
