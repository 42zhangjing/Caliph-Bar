import SwiftUI

enum EdgeSide: String, Codable {
    case left
    case right
}

struct EdgePillShape: Shape {
    let side: EdgeSide

    func path(in rect: CGRect) -> Path {
        switch side {
        case .right:
            return rightPath(in: rect)
        case .left:
            return rightPath(in: rect).applying(CGAffineTransform(translationX: rect.width, y: 0).scaledBy(x: -1, y: 1))
        }
    }

    private func rightPath(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r: CGFloat = 24
        let waist: CGFloat = 13
        let shoulder: CGFloat = 34

        var p = Path()
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: shoulder * 0.55))
        p.addCurve(
            to: CGPoint(x: w - waist, y: shoulder),
            control1: CGPoint(x: w, y: shoulder * 0.72),
            control2: CGPoint(x: w - waist, y: shoulder * 0.72)
        )
        p.addLine(to: CGPoint(x: w - waist, y: h - shoulder))
        p.addCurve(
            to: CGPoint(x: w, y: h - shoulder * 0.55),
            control1: CGPoint(x: w - waist, y: h - shoulder * 0.72),
            control2: CGPoint(x: w, y: h - shoulder * 0.72)
        )
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: r, y: h))
        p.addCurve(to: CGPoint(x: 0, y: h - r), control1: CGPoint(x: r * 0.45, y: h), control2: CGPoint(x: 0, y: h - r * 0.45))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addCurve(to: CGPoint(x: r, y: 0), control1: CGPoint(x: 0, y: r * 0.45), control2: CGPoint(x: r * 0.45, y: 0))
        p.closeSubpath()
        return p
    }
}
