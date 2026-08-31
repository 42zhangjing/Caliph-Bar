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
    static let itemSize = CGSize(width: 48, height: 56)
    static let itemSpacing: CGFloat = 8
    static let ringSize: CGFloat = 39
    static let percentageFontSize: CGFloat = 10.5

    static func windowSize(radarPinned: Bool) -> CGSize {
        radarPinned ? radarWindowSize : compactWindowSize
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

/// One continuous edge-docked silhouette.
///
/// The free-facing edge uses two cubic Bezier segments at the top and two
/// mirrored segments at the bottom. The middle ~59% is intentionally straight,
/// which prevents the shape from reading as a capsule. The screen-facing edge
/// is pushed outside the display by `SideNotchLayout.edgeBleed`.
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
        let visibleMaxX = rect.maxX - SideNotchLayout.edgeBleed
        let visibleWidth = max(0, visibleMaxX - rect.minX)
        let transitionFraction: CGFloat = rect.height > 300 ? 0.12 : 0.18

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + visibleWidth * x,
                y: rect.minY + rect.height * y
            )
        }

        var path = Path()

        // Top transition: screen edge -> concave fillet -> shoulder -> vertical body.
        path.move(to: p(1.000, 0.000))
        path.addCurve(
            to: p(0.680, transitionFraction * 0.53),
            control1: p(1.000, transitionFraction * 0.27),
            control2: p(0.965, transitionFraction * 0.48)
        )
        path.addCurve(
            to: p(0.000, transitionFraction),
            // The first handle continues the shoulder tangent while the last
            // two handles share the vertical edge. This lets curvature decay
            // to zero before the path becomes a straight line.
            control1: p(0.000, transitionFraction * 0.65),
            control2: p(0.000, transitionFraction * 0.82)
        )

        // Long straight free edge.
        path.addLine(to: p(0.000, 1 - transitionFraction))

        // Bottom transition: exact vertical mirror of the top geometry.
        path.addCurve(
            to: p(0.680, 1 - transitionFraction * 0.53),
            control1: p(0.000, 1 - transitionFraction * 0.82),
            control2: p(0.000, 1 - transitionFraction * 0.65)
        )
        path.addCurve(
            to: p(1.000, 1.000),
            control1: p(0.965, 1 - transitionFraction * 0.48),
            control2: p(1.000, 1 - transitionFraction * 0.27)
        )

        // Fill the reserved off-screen strip without moving the visible curve endpoint.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
