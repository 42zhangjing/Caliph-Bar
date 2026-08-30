import SwiftUI
import CaliphBarCore

struct BrandMark: View {
    let provider: ProviderID
    var size: CGFloat = 20
    var color: Color = .white

    var body: some View {
        Group {
            switch provider {
            case .claude:
                ClaudeBurst()
            case .codex:
                Image(systemName: "command")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.10)
            case .gemini:
                Image(systemName: "sparkle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.08)
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .accessibilityLabel(provider.displayName)
    }
}

private struct ClaudeBurst: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let inner = size.width * 0.12
            let outer = size.width * 0.46
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4
                var path = Path()
                path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: max(1.4, size.width * 0.09), lineCap: .round))
            }
        }
    }
}
