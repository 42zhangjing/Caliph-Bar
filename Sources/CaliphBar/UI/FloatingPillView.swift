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

    private var shouldShowSilhouetteContent: Bool {
        position.isHovered
    }

    private var edgeAlignment: Alignment {
        position.side == .right ? .trailing : .leading
    }

    private var surfaceWidth: CGFloat {
        switch store.handleStyle {
        case .classic:
            if isExpanded { return expandedWindowSize.width }
            return SideNotchLayout.silhouetteWidth(forHeight: SideNotchLayout.collapsedHeight)
                + SideNotchLayout.edgeBleed
        case .silhouette:
            let w = isExpanded
                ? SideNotchLayout.silhouetteExpandedWidth
                : SideNotchLayout.silhouetteCollapsedWidth
            return w + SideNotchLayout.edgeBleed
        }
    }

    private var surfaceHeight: CGFloat {
        switch store.handleStyle {
        case .classic:
            return isExpanded ? expandedWindowSize.height : SideNotchLayout.collapsedHeight
        case .silhouette:
            return isExpanded
                ? SideNotchLayout.silhouetteExpandedHeight
                : SideNotchLayout.silhouetteCollapsedHeight
        }
    }

    private var expandedWindowSize: CGSize {
        SideNotchLayout.windowSize(radarPinned: store.radarPinned, handleStyle: .classic)
    }

    private var expandedSilhouetteWidth: CGFloat {
        SideNotchLayout.silhouetteWidth(forHeight: expandedWindowSize.height)
    }

    private var contentEdgeOffset: CGFloat {
        position.side == .right ? -SideNotchLayout.edgeBleed : SideNotchLayout.edgeBleed
    }

    private var windowSize: CGSize {
        SideNotchLayout.windowSize(radarPinned: store.radarPinned, handleStyle: store.handleStyle)
    }

    var body: some View {
        ZStack(alignment: edgeAlignment) {
            pillSurface
                .frame(width: surfaceWidth, height: surfaceHeight)
                .contentShape(Rectangle())
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
            switch store.handleStyle {
            case .classic:
                classicSurface
            case .silhouette:
                silhouetteSurface
            }
        }
    }

    private var classicSurface: some View {
        ZStack(alignment: edgeAlignment) {
            EdgePillShape(side: position.side)
                .fill(Color.black)

            if isExpanded {
                expandedContent
                    .frame(width: expandedSilhouetteWidth, height: expandedWindowSize.height)
                    .offset(x: contentEdgeOffset)
                    .transition(
                        .move(edge: position.side == .right ? .trailing : .leading)
                            .combined(with: .opacity)
                    )
            }
        }
    }

    private var silhouetteSurface: some View {
        let currentHeight = surfaceHeight
        let currentWidth = surfaceWidth - SideNotchLayout.edgeBleed

        return ZStack(alignment: edgeAlignment) {
            SilhouetteShape(side: position.side)
                .fill(Color.black, style: FillStyle(eoFill: true))

            if shouldShowSilhouetteContent {
                SilhouetteOverlayContent(
                    store: store,
                    position: position,
                    silhouetteSize: CGSize(width: currentWidth, height: currentHeight)
                )
                .offset(x: contentEdgeOffset)
                .transition(.opacity)
            }
        }
    }

    private var expandedContent: some View {
        VStack(spacing: SideNotchLayout.itemSpacing) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                ProviderPillButton(
                    provider: provider,
                    snapshot: store.item(for: provider),
                    coreStyle: store.ringCoreStyle,
                    action: {
                        position.onProviderTapped?(provider)
                    }
                )
            }
            if store.radarPinned {
                RadarPillButton(coreStyle: store.ringCoreStyle) {
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

private struct SilhouetteOverlayContent: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var position: PillPositionModel
    let silhouetteSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(ProviderID.allCases, id: \.self) { provider in
                let norm = SideNotchLayout.silhouetteAnchor(for: provider)
                let pt = SideNotchLayout.silhouettePoint(
                    normalized: norm,
                    silhouetteSize: silhouetteSize,
                    side: position.side
                )
                SilhouetteProviderNode(
                    provider: provider,
                    snapshot: store.item(for: provider),
                    coreStyle: store.ringCoreStyle,
                    action: {
                        position.onProviderTapped?(provider)
                    }
                )
                .position(x: pt.x, y: pt.y)
            }

            if store.radarPinned {
                let norm = SideNotchLayout.radarAnchor
                let pt = SideNotchLayout.silhouettePoint(
                    normalized: norm,
                    silhouetteSize: silhouetteSize,
                    side: position.side
                )
                SilhouetteRadarNode(coreStyle: store.ringCoreStyle) {
                    position.onRadarTapped?()
                }
                .position(x: pt.x, y: pt.y)
            }
        }
        .frame(width: silhouetteSize.width, height: silhouetteSize.height)
    }
}

private struct SilhouetteProviderNode: View {
    let provider: ProviderID
    let snapshot: ProviderSnapshot?
    let coreStyle: RingCoreStyle
    let action: () -> Void

    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let remaining = snapshot?.headlineRemainingFraction
        Button(action: action) {
            VStack(spacing: 1) {
                RingView(
                    provider: provider,
                    remainingFraction: remaining,
                    size: SideNotchLayout.silhouetteRingSize,
                    coreStyle: coreStyle
                )

                Text(percentageLabel(for: remaining))
                    .font(.system(size: SideNotchLayout.silhouettePercentageFontSize, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(
                        remaining.map(StatusColor.valueColor(for:)) ?? .white.opacity(0.28)
                    )
                    .frame(height: 10)
            }
            .frame(width: 32, height: 34)
        }
        .buttonStyle(PillItemButtonStyle())
        .help(provider == .codex ? "\(provider.displayName) · \(radarHelp)" : provider.displayName)
    }

    private func percentageLabel(for remaining: Double?) -> String {
        guard let remaining else { return "—" }
        return StatusColor.percentageText(for: remaining)
    }

    private var radarHelp: String {
        let signal = "Radar " + CodexRadarPresentation.statusLabel(
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

private struct SilhouetteRadarNode: View {
    let coreStyle: RingCoreStyle
    let action: () -> Void
    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                ZStack {
                    Circle()
                        .fill(coreStyle.fillStyle)
                        .padding(coreStyle.inset * 0.7)
                    if coreStyle == .porcelain {
                        Circle()
                            .stroke(coreStyle.separatorColor, lineWidth: 0.5)
                            .padding(coreStyle.inset * 0.7)
                    }
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1.5)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(coreStyle.radarBrandColor)
                }
                .frame(width: SideNotchLayout.silhouetteRingSize, height: SideNotchLayout.silhouetteRingSize)

                Text(probabilityLabel)
                    .font(.system(size: SideNotchLayout.silhouettePercentageFontSize, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(probabilityColor)
                    .frame(height: 10)
            }
            .frame(width: 32, height: 34)
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

    private var probabilityColor: Color {
        .white.opacity(0.78)
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

private struct RadarPillButton: View {
    let coreStyle: RingCoreStyle
    let action: () -> Void
    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
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
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(coreStyle.radarBrandColor)
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
    let coreStyle: RingCoreStyle
    let action: () -> Void

    @ObservedObject private var radar = CodexRadarStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let remaining = snapshot?.headlineRemainingFraction
        Button(action: action) {
            VStack(spacing: 4) {
                RingView(
                    provider: provider,
                    remainingFraction: remaining,
                    size: SideNotchLayout.ringSize,
                    coreStyle: coreStyle
                )

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
        return StatusColor.percentageText(for: remaining)
    }

    private var radarHelp: String {
        let signal = "Radar " + CodexRadarPresentation.statusLabel(
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
