import SwiftUI
import CaliphBarCore

enum EdgeSide: String, Codable, Equatable {
    case left
    case right
}

enum SideNotchLayout {
    static let visibleWidth: CGFloat = 62
    static let compactWindowSize = CGSize(width: visibleWidth + edgeBleed, height: 288)
    static let radarWindowSize = CGSize(width: visibleWidth + edgeBleed, height: 328)
    static let collapsedHeight: CGFloat = 76
    static let itemSize = CGSize(width: 48, height: 56)
    static let itemSpacing: CGFloat = 8
    static let ringSize: CGFloat = 39
    static let percentageFontSize: CGFloat = 10.5

    /// The canonical silhouette is stored in `Resources/Shapes/caliph-edge-tab.svg`.
    /// Width is always derived from height so no view state can stretch the curve.
    static let canonicalAspectRatio: CGFloat = 210 / 1138

    static func windowSize(radarPinned: Bool) -> CGSize {
        radarPinned ? radarWindowSize : compactWindowSize
    }

    static func silhouetteWidth(forHeight height: CGFloat) -> CGFloat {
        height * canonicalAspectRatio
    }

    /// Reserved outside the physical display edge so the closing edge never
    /// appears as a separate black bar. Shape/content geometry uses the visible
    /// 62-point region; the bleed is not allowed to clip the visible curves.
    static let edgeBleed: CGFloat = 6

    static func providerCenterYFromTop(
        index: Int,
        providerCount: Int,
        height: CGFloat = compactWindowSize.height
    ) -> CGFloat {
        let count = max(1, providerCount)
        let stackHeight = CGFloat(count) * itemSize.height
            + CGFloat(max(0, count - 1)) * itemSpacing
        let topInset = max(0, (height - stackHeight) / 2)
        return topInset + itemSize.height / 2
            + CGFloat(index) * (itemSize.height + itemSpacing)
    }
}

private struct CanonicalCubicSegment {
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint
}

/// Exact platform-native transcription of `Resources/Shapes/caliph-edge-tab.svg`.
/// Keep these coordinates in lockstep with the canonical asset; do not simplify
/// or regenerate them from a screenshot.
private enum CanonicalEdgeTab {
    static let width: CGFloat = 210
    static let height: CGFloat = 1138
    static let straightEdgeBottom = CGPoint(x: 0, y: 914)

    static let topSegments: [CanonicalCubicSegment] = [
        .init(control1: .init(x: 208.315, y: 4), control2: .init(x: 206.74, y: 8), end: .init(x: 205.306, y: 12)),
        .init(control1: .init(x: 203.871, y: 16), control2: .init(x: 202.755, y: 20), end: .init(x: 201.333, y: 24)),
        .init(control1: .init(x: 199.912, y: 28), control2: .init(x: 198.408, y: 32), end: .init(x: 196.73, y: 36)),
        .init(control1: .init(x: 195.052, y: 40), control2: .init(x: 193.268, y: 44), end: .init(x: 191.176, y: 48)),
        .init(control1: .init(x: 189.084, y: 52), control2: .init(x: 186.628, y: 56), end: .init(x: 183.964, y: 60)),
        .init(control1: .init(x: 181.299, y: 64), control2: .init(x: 178.345, y: 68), end: .init(x: 174.999, y: 72)),
        .init(control1: .init(x: 171.654, y: 76), control2: .init(x: 168.037, y: 80), end: .init(x: 163.597, y: 84)),
        .init(control1: .init(x: 159.157, y: 88), control2: .init(x: 154.112, y: 92), end: .init(x: 147.585, y: 96)),
        .init(control1: .init(x: 141.059, y: 100), control2: .init(x: 133.54, y: 104), end: .init(x: 122.389, y: 108)),
        .init(control1: .init(x: 111.237, y: 112), control2: .init(x: 83.679, y: 116), end: .init(x: 72.628, y: 120)),
        .init(control1: .init(x: 61.577, y: 124), control2: .init(x: 54.178, y: 128), end: .init(x: 47.771, y: 132)),
        .init(control1: .init(x: 41.365, y: 136), control2: .init(x: 36.384, y: 140), end: .init(x: 32.104, y: 144)),
        .init(control1: .init(x: 27.823, y: 148), control2: .init(x: 24.34, y: 152), end: .init(x: 21.224, y: 156)),
        .init(control1: .init(x: 18.108, y: 160), control2: .init(x: 15.299, y: 164), end: .init(x: 13.03, y: 168)),
        .init(control1: .init(x: 10.76, y: 172), control2: .init(x: 8.831, y: 176), end: .init(x: 7.206, y: 180)),
        .init(control1: .init(x: 5.58, y: 184), control2: .init(x: 3.982, y: 188), end: .init(x: 3.011, y: 192)),
        .init(control1: .init(x: 2.04, y: 196), control2: .init(x: 1.163, y: 200), end: .init(x: 0.778, y: 204)),
        .init(control1: .init(x: 0.394, y: 208), control2: .init(x: 0, y: 212), end: .init(x: 0, y: 216)),
        .init(control1: .init(x: 0, y: 220), control2: .init(x: 0, y: 224), end: .init(x: 0, y: 228)),
        .init(control1: .init(x: 0, y: 230), control2: .init(x: 0, y: 232), end: .init(x: 0, y: 234)),
    ]

    static let bottomSegments: [CanonicalCubicSegment] = [
        .init(control1: .init(x: 0, y: 918), control2: .init(x: 0, y: 922), end: .init(x: 0, y: 926)),
        .init(control1: .init(x: 0, y: 930), control2: .init(x: 0.169, y: 934), end: .init(x: 0.403, y: 938)),
        .init(control1: .init(x: 0.637, y: 942), control2: .init(x: 1.987, y: 946), end: .init(x: 3.132, y: 950)),
        .init(control1: .init(x: 4.278, y: 954), control2: .init(x: 5.916, y: 958), end: .init(x: 7.768, y: 962)),
        .init(control1: .init(x: 9.621, y: 966), control2: .init(x: 12.051, y: 970), end: .init(x: 14.703, y: 974)),
        .init(control1: .init(x: 17.356, y: 978), control2: .init(x: 20.455, y: 982), end: .init(x: 24.039, y: 986)),
        .init(control1: .init(x: 27.623, y: 990), control2: .init(x: 31.686, y: 994), end: .init(x: 36.715, y: 998)),
        .init(control1: .init(x: 41.744, y: 1002), control2: .init(x: 46.984, y: 1006), end: .init(x: 55.343, y: 1010)),
        .init(control1: .init(x: 63.702, y: 1014), control2: .init(x: 80.01, y: 1018), end: .init(x: 93.696, y: 1022)),
        .init(control1: .init(x: 107.382, y: 1026), control2: .init(x: 128.76, y: 1030), end: .init(x: 137.869, y: 1034)),
        .init(control1: .init(x: 146.979, y: 1038), control2: .init(x: 152.339, y: 1042), end: .init(x: 157.653, y: 1046)),
        .init(control1: .init(x: 162.966, y: 1050), control2: .init(x: 167.056, y: 1054), end: .init(x: 171, y: 1058)),
        .init(control1: .init(x: 174.944, y: 1062), control2: .init(x: 178.591, y: 1066), end: .init(x: 181.626, y: 1070)),
        .init(control1: .init(x: 184.661, y: 1074), control2: .init(x: 187.275, y: 1078), end: .init(x: 189.591, y: 1082)),
        .init(control1: .init(x: 191.906, y: 1086), control2: .init(x: 193.925, y: 1090), end: .init(x: 195.748, y: 1094)),
        .init(control1: .init(x: 197.57, y: 1098), control2: .init(x: 199.213, y: 1102), end: .init(x: 200.664, y: 1106)),
        .init(control1: .init(x: 202.116, y: 1110), control2: .init(x: 203.443, y: 1114), end: .init(x: 204.572, y: 1118)),
        .init(control1: .init(x: 205.702, y: 1122), control2: .init(x: 206.46, y: 1126), end: .init(x: 207.564, y: 1130)),
        .init(control1: .init(x: 208.3, y: 1132.667), control2: .init(x: 209.129, y: 1135.333), end: .init(x: 210, y: 1138)),
    ]
}

/// One continuous, edge-docked silhouette. The on-screen curve is the exact
/// canonical SVG at a uniform scale. Only the closing edge is extended into the
/// six-point off-screen strip so AppKit antialiasing cannot reveal a seam.
struct EdgePillShape: Shape {
    let side: EdgeSide

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let rightDocked = rightDockedPath(in: rect)
        guard side == .left else { return rightDocked }

        let mirror = CGAffineTransform(
            a: -1,
            b: 0,
            c: 0,
            d: 1,
            tx: rect.minX + rect.maxX,
            ty: 0
        )
        return rightDocked.applying(mirror)
    }

    private func rightDockedPath(in rect: CGRect) -> Path {
        let scale = rect.height / CanonicalEdgeTab.height
        let visibleMaxX = rect.maxX - SideNotchLayout.edgeBleed
        let visibleMinX = visibleMaxX - CanonicalEdgeTab.width * scale

        func point(_ canonical: CGPoint) -> CGPoint {
            CGPoint(
                x: visibleMinX + canonical.x * scale,
                y: rect.minY + canonical.y * scale
            )
        }

        var path = Path()
        path.move(to: point(.init(x: CanonicalEdgeTab.width, y: 0)))
        for segment in CanonicalEdgeTab.topSegments {
            path.addCurve(
                to: point(segment.end),
                control1: point(segment.control1),
                control2: point(segment.control2)
            )
        }

        path.addLine(to: point(CanonicalEdgeTab.straightEdgeBottom))

        for segment in CanonicalEdgeTab.bottomSegments {
            path.addCurve(
                to: point(segment.end),
                control1: point(segment.control1),
                control2: point(segment.control2)
            )
        }

        // Fill the reserved off-screen strip without moving the visible curve endpoint.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
