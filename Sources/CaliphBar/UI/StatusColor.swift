import SwiftUI
import AppKit

enum StatusColor {
    private struct Swatch {
        let red: Double
        let green: Double
        let blue: Double

        var color: Color {
            Color(red: red, green: green, blue: blue)
        }

        var nsColor: NSColor {
            NSColor(
                calibratedRed: CGFloat(red),
                green: CGFloat(green),
                blue: CGFloat(blue),
                alpha: 1
            )
        }
    }

    private static let alert = Swatch(red: 0.78, green: 0.41, blue: 0.35)
    private static let caution = Swatch(red: 0.78, green: 0.63, blue: 0.36)
    private static let healthy = Swatch(red: 0.39, green: 0.72, blue: 0.62)

    /// Color based on remaining fraction (0.0 ... 1.0)
    /// Muted instrument colors keep quota state legible without competing with
    /// the provider brand marks on black surfaces.
    static func color(for remainingFraction: Double) -> Color {
        swatch(for: remainingFraction).color
    }

    static func nsColor(for remainingFraction: Double) -> NSColor {
        swatch(for: remainingFraction).nsColor
    }

    private static func swatch(for remainingFraction: Double) -> Swatch {
        if remainingFraction < 0.20 {
            return alert
        } else if remainingFraction < 0.50 {
            return caution
        } else {
            return healthy
        }
    }
}
