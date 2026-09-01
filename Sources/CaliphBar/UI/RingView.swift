import SwiftUI
import CaliphBarCore

struct RingView: View {
    let provider: ProviderID
    let remainingFraction: Double?
    var size: CGFloat = 42
    var coreStyle: RingCoreStyle = .dark

    @State private var displayedFraction: Double = 0.0

    private var markSize: CGFloat {
        let opticalSize: CGFloat
        switch provider {
        case .claude:
            opticalSize = 19
        case .codex:
            opticalSize = 18
        case .gemini:
            opticalSize = 16.5
        }
        return opticalSize * size / SideNotchLayout.ringSize
    }

    private var markSaturation: Double {
        if coreStyle == .porcelain {
            switch provider {
            case .claude: return 0.94
            case .codex: return 0.88
            case .gemini: return 0.90
            }
        }
        switch provider {
        case .claude: return 0.86
        case .codex: return 0.84
        case .gemini: return 0.88
        }
    }

    private var markBrightness: Double {
        if coreStyle == .porcelain {
            switch provider {
            case .claude: return -0.10
            case .codex: return -0.14
            case .gemini: return -0.08
            }
        }
        switch provider {
        case .claude: return 0.04
        case .codex: return -0.03
        case .gemini: return 0.05
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(coreStyle.fillStyle)
                .padding(coreStyle.inset)

            if coreStyle == .porcelain {
                Circle()
                    .stroke(coreStyle.separatorColor, lineWidth: 0.65)
                    .padding(coreStyle.inset)
            }

            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 2.25)

            if remainingFraction != nil {
                Circle()
                    .trim(from: 0, to: min(1, max(0, displayedFraction)))
                    .stroke(
                        StatusColor.color(for: displayedFraction),
                        style: StrokeStyle(lineWidth: 2.25, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            BrandMark(
                provider: provider,
                size: markSize,
                isMuted: false,
                saturation: markSaturation,
                brightness: markBrightness
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
