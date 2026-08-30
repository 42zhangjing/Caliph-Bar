import SwiftUI
import CaliphBarCore

enum EdgeSide: String, Codable {
    case left
    case right
}

enum SideNotchLayout {
    static let windowSize = CGSize(width: 74, height: 344)
    static let itemSize = CGSize(width: 56, height: 66)
    static let itemSpacing: CGFloat = 13

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

/// A single, continuous organic edge-docked silhouette shape.
///
/// Features:
/// - Screen-docked side departs seamlessly from the display boundary.
/// - Top & bottom transitions are smooth S-curves with concave fillets at the screen edge
///   and convex shoulders wrapping the body, with tangent continuity (G1/G2).
/// - Middle body is a long vertical straight line occupying ~64% of total height.
/// - Symmetrical horizontal mirroring between `.left` and `.right` dock sides.
struct EdgePillShape: Shape {
    let side: EdgeSide
    var transitionRatio: CGFloat = 0.178
    var controlWeight1: CGFloat = 0.68
    var controlWeight2: CGFloat = 0.68

    func path(in rect: CGRect) -> Path {
        let transitionHeight = rect.height * transitionRatio
        let topStraightY = rect.minY + transitionHeight
        let bottomStraightY = rect.maxY - transitionHeight

        var path = Path()

        // 1. Start at screen edge (top right corner for .right dock)
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))

        // 2. Top S-curve transition:
        //    Leaves screen edge (rect.maxX) with vertical tangent downwards,
        //    curves leftward through concave fillet and inflection point,
        //    then rounds through convex shoulder to meet rect.minX with vertical tangent.
        path.addCurve(
            to: CGPoint(x: rect.minX, y: topStraightY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + transitionHeight * controlWeight1),
            control2: CGPoint(x: rect.minX, y: topStraightY - transitionHeight * (1.0 - controlWeight2))
        )

        // 3. Middle straight body segment
        path.addLine(to: CGPoint(x: rect.minX, y: bottomStraightY))

        // 4. Bottom S-curve transition:
        //    Leaves rect.minX vertically downwards, curves rightward through convex shoulder,
        //    crosses inflection point into concave fillet, and meets rect.maxX with vertical tangent.
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: bottomStraightY + transitionHeight * (1.0 - controlWeight2)),
            control2: CGPoint(x: rect.maxX, y: rect.maxY - transitionHeight * controlWeight1)
        )

        // 5. Straight vertical edge hugging the display boundary
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()

        // Horizontal mirror for .left dock side
        if side == .left {
            let transform = CGAffineTransform(translationX: rect.minX + rect.maxX, y: 0)
                .scaledBy(x: -1, y: 1)
            return path.applying(transform)
        }

        return path
    }
}
