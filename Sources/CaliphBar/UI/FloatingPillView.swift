import SwiftUI
import CaliphBarCore

@MainActor
final class PillPositionModel: ObservableObject {
    @Published var side: EdgeSide
    @Published var isHovered: Bool = false

    var onProviderTapped: ((ProviderID) -> Void)?
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

    private var isExpanded: Bool {
        store.pillBehavior == .alwaysExpanded || position.isHovered
    }

    private var edgeAlignment: Alignment {
        position.side == .right ? .trailing : .leading
    }

    private var surfaceWidth: CGFloat {
        isExpanded ? SideNotchLayout.windowSize.width : 14
    }

    private var surfaceHeight: CGFloat {
        isExpanded ? SideNotchLayout.windowSize.height : 72
    }

    var body: some View {
        ZStack(alignment: edgeAlignment) {
            pillSurface
                .frame(width: surfaceWidth, height: surfaceHeight)
                .contentShape(EdgePillShape(side: position.side))
                .simultaneousGesture(dragGesture)
        }
        .frame(
            width: SideNotchLayout.windowSize.width,
            height: SideNotchLayout.windowSize.height,
            alignment: edgeAlignment
        )
        .animation(.interpolatingSpring(stiffness: 280, damping: 22), value: isExpanded)
    }

    private var pillSurface: some View {
        ZStack(alignment: edgeAlignment) {
            EdgePillShape(side: position.side)
                .fill(Color(red: 0.020, green: 0.021, blue: 0.026))
                .allowsHitTesting(false)

            if isExpanded {
                expandedContent
                    .transition(
                        .move(edge: position.side == .right ? .trailing : .leading)
                            .combined(with: .opacity)
                    )
            }
        }
    }

    private var expandedContent: some View {
        VStack(spacing: SideNotchLayout.itemSpacing) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                ProviderPillButton(
                    provider: provider,
                    snapshot: store.item(for: provider),
                    action: {
                        withAnimation(.easeOut(duration: 0.14)) {
                            selection.selected = provider
                        }
                        position.onProviderTapped?(provider)
                    }
                )
            }
        }
        .frame(width: SideNotchLayout.windowSize.width, height: SideNotchLayout.windowSize.height)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                position.onDragMoved?(value.translation)
            }
            .onEnded { value in
                position.onDragEnded?(value.translation)
            }
    }
}

private struct ProviderPillButton: View {
    let provider: ProviderID
    let snapshot: ProviderSnapshot?
    let action: () -> Void

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
                        .animation(.easeOut(duration: 0.18), value: remaining)
                }
            }
            .frame(width: SideNotchLayout.itemSize.width, height: SideNotchLayout.itemSize.height)
        }
        .buttonStyle(PillItemButtonStyle())
        .help(provider.displayName)
    }
}
