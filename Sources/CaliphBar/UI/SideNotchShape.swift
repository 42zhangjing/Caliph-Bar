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
    static let itemSpacing: CGFloat = 4
    static let ringSize: CGFloat = 36
    static let percentageFontSize: CGFloat = 10

    /// The canonical silhouette is stored in `Resources/Shapes/caliph-edge-tab.svg`.
    /// Width is always derived from height so no view state can stretch the curve.
    static let canonicalAspectRatio: CGFloat = 210 / 1138

    static let silhouetteCollapsedHeight: CGFloat = collapsedHeight * 2
    static let silhouetteExpandedHeight: CGFloat = 360
    static let silhouetteAspectRatio: CGFloat = 600.0 / 1864.0
    static let silhouetteCollapsedWidth: CGFloat = silhouetteCollapsedHeight * silhouetteAspectRatio
    static let silhouetteExpandedWidth: CGFloat = silhouetteExpandedHeight * silhouetteAspectRatio
    static let silhouetteRingSize: CGFloat = 22
    static let silhouettePercentageFontSize: CGFloat = 8

    /// Normalized anchors on the silhouette bounding box (top-left is (0,0), bottom-right is (1,1))
    static let claudeAnchor = CGPoint(x: 0.600, y: 0.118)      // Head
    static let codexAnchor = CGPoint(x: 0.380, y: 0.278)       // Chest
    static let antigravityAnchor = CGPoint(x: 0.550, y: 0.442) // Hip
    static let radarAnchor = CGPoint(x: 0.851, y: 0.668)       // Base

    static func silhouetteAnchor(for provider: ProviderID) -> CGPoint {
        switch provider {
        case .claude: return claudeAnchor
        case .codex: return codexAnchor
        case .gemini: return antigravityAnchor
        }
    }

    static func silhouettePoint(
        normalized: CGPoint,
        silhouetteSize: CGSize,
        side: EdgeSide
    ) -> CGPoint {
        let x = side == .left ? (1.0 - normalized.x) * silhouetteSize.width : normalized.x * silhouetteSize.width
        let y = normalized.y * silhouetteSize.height
        return CGPoint(x: x, y: y)
    }

    static func windowSize(radarPinned: Bool, handleStyle: UsageStore.HandleStyle = .classic) -> CGSize {
        let base = radarPinned ? radarWindowSize : compactWindowSize
        guard handleStyle == .silhouette else { return base }
        return CGSize(
            width: max(base.width, silhouetteExpandedWidth + edgeBleed),
            height: max(base.height, silhouetteExpandedHeight)
        )
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
    static let straightEdgeBottom = CGPoint(x: 0, y: 904)

    static let topSegments: [CanonicalCubicSegment] = [
        .init(control1: .init(x: 210, y: 6), control2: .init(x: 209.7, y: 12), end: .init(x: 208.4, y: 18)),
        .init(control1: .init(x: 207.1, y: 24), control2: .init(x: 205.2, y: 30), end: .init(x: 202.9, y: 36)),
        .init(control1: .init(x: 200.6, y: 42), control2: .init(x: 198, y: 48), end: .init(x: 194.8, y: 54)),
        .init(control1: .init(x: 191.6, y: 60), control2: .init(x: 188.1, y: 66), end: .init(x: 184.1, y: 72)),
        .init(control1: .init(x: 180.1, y: 78), control2: .init(x: 175.8, y: 84), end: .init(x: 170.9, y: 90)),
        .init(control1: .init(x: 166, y: 96), control2: .init(x: 160.1, y: 102), end: .init(x: 152.5, y: 108)),
        .init(control1: .init(x: 144.9, y: 114), control2: .init(x: 135.4, y: 120), end: .init(x: 122.4, y: 126)),
        .init(control1: .init(x: 109.4, y: 132), control2: .init(x: 81.5, y: 138), end: .init(x: 68.4, y: 144)),
        .init(control1: .init(x: 55.3, y: 150), control2: .init(x: 47.8, y: 156), end: .init(x: 40.8, y: 162)),
        .init(control1: .init(x: 33.8, y: 168), control2: .init(x: 28.2, y: 174), end: .init(x: 23.1, y: 180)),
        .init(control1: .init(x: 18, y: 186), control2: .init(x: 13.9, y: 192), end: .init(x: 10.6, y: 198)),
        .init(control1: .init(x: 7.3, y: 204), control2: .init(x: 5.1, y: 210), end: .init(x: 3.6, y: 216)),
        .init(control1: .init(x: 2.1, y: 222), control2: .init(x: 1.2, y: 228), end: .init(x: 0.6, y: 234)),
    ]

    static let bottomSegments: [CanonicalCubicSegment] = [
        .init(control1: .init(x: 1.2, y: 910), control2: .init(x: 2.1, y: 916), end: .init(x: 3.6, y: 922)),
        .init(control1: .init(x: 5.1, y: 928), control2: .init(x: 7.3, y: 934), end: .init(x: 10.6, y: 940)),
        .init(control1: .init(x: 13.9, y: 946), control2: .init(x: 18, y: 952), end: .init(x: 23.1, y: 958)),
        .init(control1: .init(x: 28.2, y: 964), control2: .init(x: 33.8, y: 970), end: .init(x: 40.8, y: 976)),
        .init(control1: .init(x: 47.8, y: 982), control2: .init(x: 55.3, y: 988), end: .init(x: 68.4, y: 994)),
        .init(control1: .init(x: 81.5, y: 1000), control2: .init(x: 109.4, y: 1006), end: .init(x: 122.4, y: 1012)),
        .init(control1: .init(x: 135.4, y: 1018), control2: .init(x: 144.9, y: 1024), end: .init(x: 152.5, y: 1030)),
        .init(control1: .init(x: 160.1, y: 1036), control2: .init(x: 166, y: 1042), end: .init(x: 170.9, y: 1048)),
        .init(control1: .init(x: 175.8, y: 1054), control2: .init(x: 180.1, y: 1060), end: .init(x: 184.1, y: 1066)),
        .init(control1: .init(x: 188.1, y: 1072), control2: .init(x: 191.6, y: 1078), end: .init(x: 194.8, y: 1084)),
        .init(control1: .init(x: 198, y: 1090), control2: .init(x: 200.6, y: 1096), end: .init(x: 202.9, y: 1102)),
        .init(control1: .init(x: 205.2, y: 1108), control2: .init(x: 207.1, y: 1114), end: .init(x: 208.4, y: 1120)),
        .init(control1: .init(x: 209.7, y: 1126), control2: .init(x: 210, y: 1132), end: .init(x: 210, y: 1138)),
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
