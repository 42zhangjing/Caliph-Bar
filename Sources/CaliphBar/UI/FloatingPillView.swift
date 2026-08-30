import SwiftUI
import CaliphBarCore

@MainActor
final class PillPositionModel: ObservableObject {
    @Published var side: EdgeSide
    init(side: EdgeSide) { self.side = side }
}

struct FloatingPillView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var selection: SelectionModel
    @ObservedObject var position: PillPositionModel

    var body: some View {
        VStack(spacing: 16) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                let item = store.item(for: provider)
                Button {
                    selection.selected = provider
                } label: {
                    VStack(spacing: 5) {
                        RingView(provider: provider, fraction: item?.headlineFraction, size: 42)
                            .opacity(selection.selected == provider ? 1 : 0.72)
                        Text(percentLabel(item?.headlineFraction))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(item?.headlineFraction.map(StatusColor.color(for:)) ?? .white.opacity(0.35))
                    }
                }
                .buttonStyle(.plain)
                .help(provider.displayName)
            }
        }
        .padding(.vertical, 16)
        .padding(position.side == .right ? .leading : .trailing, 9)
        .padding(position.side == .right ? .trailing : .leading, 16)
        .background(
            EdgePillShape(side: position.side)
                .fill(Color(red: 0.025, green: 0.026, blue: 0.03).opacity(0.97))
        )
        .overlay(
            EdgePillShape(side: position.side)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 18, x: position.side == .right ? -5 : 5, y: 5)
    }

    private func percentLabel(_ fraction: Double?) -> String {
        guard let fraction else { return "—" }
        if fraction >= 10 { return "999%+" }
        return "\(Int(fraction * 100))%"
    }
}
