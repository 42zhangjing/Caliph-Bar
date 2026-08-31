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

    /// Exact quota values use one quieter semantic across the menu bar,
    /// edge rail, hover panel, and full management panel.
    static func valueColor(for remainingFraction: Double) -> Color {
        if remainingFraction < 0.10 {
            return Color(red: 1.0, green: 0.271, blue: 0.227)
        } else if remainingFraction < 0.20 {
            return Color(red: 1.0, green: 0.624, blue: 0.039)
        } else {
            return .white.opacity(0.68)
        }
    }

    static func nsValueColor(for remainingFraction: Double) -> NSColor {
        if remainingFraction < 0.10 {
            return NSColor(calibratedRed: 1.0, green: 0.271, blue: 0.227, alpha: 1.0)
        } else if remainingFraction < 0.20 {
            return NSColor(calibratedRed: 1.0, green: 0.624, blue: 0.039, alpha: 1.0)
        } else {
            return NSColor.labelColor.withAlphaComponent(0.68)
        }
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
