import SwiftUI
import CaliphBarCore

@MainActor
final class PillPositionModel: ObservableObject {
    @Published var side: EdgeSide
    @Published var isHovered: Bool = false

    var onProviderTapped: ((ProviderID) -> Void)?
    var onRadarTapped: (() -> Void)?
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
    @ObservedObject var position: PillPositionModel

    private var isExpanded: Bool {
        store.pillBehavior == .alwaysExpanded || position.isHovered
    }

    private var edgeAlignment: Alignment {
        position.side == .right ? .trailing : .leading
    }

    private var surfaceWidth: CGFloat {
        if isExpanded { return windowSize.width }
        return SideNotchLayout.silhouetteWidth(forHeight: SideNotchLayout.collapsedHeight)
            + SideNotchLayout.edgeBleed
    }

    private var surfaceHeight: CGFloat {
        isExpanded ? windowSize.height : SideNotchLayout.collapsedHeight
    }

    private var expandedSilhouetteWidth: CGFloat {
        SideNotchLayout.silhouetteWidth(forHeight: windowSize.height)
    }

    private var contentEdgeOffset: CGFloat {
        position.side == .right ? -SideNotchLayout.edgeBleed : SideNotchLayout.edgeBleed
    }

    private var windowSize: CGSize {
        SideNotchLayout.windowSize(radarPinned: store.radarPinned)
    }

    var body: some View {
        ZStack(alignment: edgeAlignment) {
            pillSurface
                .frame(width: surfaceWidth, height: surfaceHeight)
                .contentShape(EdgePillShape(side: position.side))
                .simultaneousGesture(dragGesture)
        }
        .frame(
            width: windowSize.width,
            height: windowSize.height,
            alignment: edgeAlignment
        )
        .animation(.interpolatingSpring(stiffness: 280, damping: 22), value: isExpanded)
    }

    private var pillSurface: some View {
        ZStack(alignment: edgeAlignment) {
            EdgePillShape(side: position.side)
                .fill(Color.black)
                .allowsHitTesting(false)

            if isExpanded {
                expandedContent
                    .frame(width: expandedSilhouetteWidth, height: windowSize.height)
                    .offset(x: contentEdgeOffset)
                    .transition(
                        .move(edge: position.side == .right ? .trailing : .leading)
                            .combined(with: .opacity)
                    )
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 2, height: 24)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: position.side == .right ? .leading : .trailing
                    )
                    .padding(position.side == .right ? .leading : .trailing, 4)
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
                        position.onProviderTapped?(provider)
                    }
                )
            }
            if store.radarPinned {
                RadarPillButton {
                    position.onRadarTapped?()
                }
            }
        }
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

private struct RadarPillButton: View {
    let action: () -> Void
    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.035, green: 0.039, blue: 0.047).opacity(0.96))
                        .padding(2.25)
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 2.25)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(CodexRadarPresentation.brandColor)
                }
                .frame(width: SideNotchLayout.ringSize, height: SideNotchLayout.ringSize)

                Text(probabilityLabel)
                    .font(.system(size: SideNotchLayout.percentageFontSize, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(height: 12)
            }
            .frame(width: SideNotchLayout.itemSize.width, height: SideNotchLayout.itemSize.height)
        }
        .buttonStyle(PillItemButtonStyle())
        .accessibilityLabel("Reset Radar")
        .accessibilityValue(accessibilityValue)
        .help(l10n.isChinese ? "Codex Reset Radar 公共情报" : "Codex Reset Radar public intelligence")
    }

    private var probabilityLabel: String {
        guard let value = radar.snapshot?.probability24h else { return "RADAR" }
        return "\(Int((value * 100).rounded()))%"
    }

    private var accessibilityValue: String {
        let state = CodexRadarPresentation.statusLabel(
            for: radar.signal,
            isChinese: l10n.isChinese
        )
        guard radar.snapshot?.probability24h != nil else { return state }
        return "\(state), 24H \(probabilityLabel)"
    }

}

private struct ProviderPillButton: View {
    let provider: ProviderID
    let snapshot: ProviderSnapshot?
    let action: () -> Void

    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let remaining = snapshot?.headlineRemainingFraction
        Button(action: action) {
            VStack(spacing: 4) {
                RingView(provider: provider, remainingFraction: remaining, size: SideNotchLayout.ringSize)

                Text(percentageLabel(for: remaining))
                    .font(.system(size: SideNotchLayout.percentageFontSize, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(
                        remaining.map(StatusColor.valueColor(for:)) ?? .white.opacity(0.28)
                    )
                    .frame(height: 12)
                    .animation(.easeOut(duration: 0.18), value: remaining)
            }
            .frame(width: SideNotchLayout.itemSize.width, height: SideNotchLayout.itemSize.height)
        }
        .buttonStyle(PillItemButtonStyle())
        .help(provider == .codex ? "\(provider.displayName) · \(radarHelp)" : provider.displayName)
    }

    private func percentageLabel(for remaining: Double?) -> String {
        guard let remaining else { return "—" }
        return "\(Int((remaining * 100).rounded()))%"
    }

    private var radarHelp: String {
        let signal: String
        signal = "Radar " + CodexRadarPresentation.statusLabel(
            for: radar.signal,
            isChinese: l10n.isChinese,
            compact: true
        )
        if let probability = radar.snapshot?.probability24h {
            return "\(signal) · 24h \(Int((probability * 100).rounded()))%"
        }
        return signal
    }
}
