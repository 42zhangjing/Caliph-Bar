import SwiftUI
import CaliphBarCore

@MainActor
final class PillPositionModel: ObservableObject {
    @Published var side: EdgeSide
    @Published var isHovered: Bool = false

    var onProviderTapped: ((ProviderID) -> Void)?
    var onProviderHovered: ((ProviderID) -> Void)?
    var onDragMoved: ((CGSize) -> Void)?
    var onDragEnded: ((CGSize) -> Void)?

    init(side: EdgeSide) { self.side = side }
}
struct PillItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.interpolatingSpring(stiffness: 380, damping: 24), value: configuration.isPressed)
    }
}

struct FloatingPillView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var selection: SelectionModel
    @ObservedObject var position: PillPositionModel

    var isExpanded: Bool {
        store.pillBehavior == .alwaysExpanded || position.isHovered
    }

    private var edgeAlignment: Alignment {
        position.side == .right ? .trailing : .leading
    }

    private var selectedIndex: Int? {
        ProviderID.allCases.firstIndex(of: selection.selected)
    }

    var body: some View {
        ZStack(alignment: edgeAlignment) {
            EdgePillShape(side: position.side)
                .fill(Color(red: 0.020, green: 0.021, blue: 0.026))
                .frame(
                    width: isExpanded ? SideNotchLayout.windowSize.width : 14,
                    height: isExpanded ? SideNotchLayout.windowSize.height : 72
                )
                .allowsHitTesting(false)

            if isExpanded {
                expandedContent
                    .transition(
                        .move(edge: position.side == .right ? .trailing : .leading)
                            .combined(with: .opacity)
                    )
            } else {
                miniNotchContent
                    .transition(.opacity)
            }
        }
        .frame(
            width: SideNotchLayout.windowSize.width,
            height: SideNotchLayout.windowSize.height,
            alignment: edgeAlignment
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    position.onDragMoved?(value.translation)
                }
                .onEnded { value in
                    position.onDragEnded?(value.translation)
                }
        )
        .animation(.interpolatingSpring(stiffness: 280, damping: 22), value: isExpanded)
    }

    private var expandedContent: some View {
        VStack(spacing: SideNotchLayout.itemSpacing) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                ProviderPillButton(
                    provider: provider,
                    snapshot: store.item(for: provider),
                    action: {
                        selection.selected = provider
                        position.onProviderTapped?(provider)
                    },
                    onHover: { isHovered in
                        if isHovered {
                            selection.selected = provider
                            position.onProviderHovered?(provider)
                        }
                    }
                )
            }
        }
        .frame(width: SideNotchLayout.windowSize.width, height: SideNotchLayout.windowSize.height)
    }

    private var miniNotchContent: some View {
        Color.clear
            .frame(width: SideNotchLayout.windowSize.width, height: SideNotchLayout.windowSize.height)
    }
}

private struct ProviderPillButton: View {
    let provider: ProviderID
    let snapshot: ProviderSnapshot?
    let action: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        let remaining = snapshot?.headlineRemainingFraction
        Button(action: action) {
            VStack(spacing: 3) {
                RingView(provider: provider, remainingFraction: remaining, size: 46)

                if let remaining {
                    let percent = Int((remaining * 100).rounded())
                    Text("\(percent)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(StatusColor.color(for: remaining))
                }
            }
            .frame(width: SideNotchLayout.itemSize.width, height: SideNotchLayout.itemSize.height)
        }
        .buttonStyle(PillItemButtonStyle())
        .onHover(perform: onHover)
        .help(provider.displayName)
    }
}
