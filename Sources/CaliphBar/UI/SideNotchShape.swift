import SwiftUI
import CaliphBarCore

enum EdgeSide: String, Codable, Equatable {
    case left
    case right
}

enum SideNotchLayout {
    static let windowSize = CGSize(width: 74, height: 344)
    static let itemSize = CGSize(width: 56, height: 66)
    static let itemSpacing: CGFloat = 13

    /// Extends the panel slightly beyond the physical display edge so the
    /// closing edge of the shape is never visible as a separate black bar.
    static let edgeBleed: CGFloat = 6

    static func providerCenterYFromTop(
        index: Int,
        providerCount: Int,
        height: CGFloat = windowSize.height
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
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x,
                y: rect.minY + rect.height * y
            )
        }

        var path = Path()

        // Top transition: screen edge -> concave fillet -> shoulder -> vertical body.
        path.move(to: p(1.000, 0.000))
        path.addCurve(
            to: p(0.680, 0.108),
            control1: p(1.000, 0.056),
            control2: p(0.965, 0.098)
        )
        path.addCurve(
            to: p(0.000, 0.205),
            control1: p(0.400, 0.124),
            control2: p(0.000, 0.146)
        )

        // Long straight free edge.
        path.addLine(to: p(0.000, 0.795))

        // Bottom transition: exact vertical mirror of the top geometry.
        path.addCurve(
            to: p(0.680, 0.892),
            control1: p(0.000, 0.854),
            control2: p(0.400, 0.876)
        )
        path.addCurve(
            to: p(1.000, 1.000),
            control1: p(0.965, 0.902),
            control2: p(1.000, 0.944)
        )

        // The closing screen-facing edge is intentionally hidden off-screen.
        path.closeSubpath()
        return path
    }
}
