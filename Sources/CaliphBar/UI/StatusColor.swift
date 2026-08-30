import SwiftUI
import AppKit

enum StatusColor {
    /// Color based on remaining fraction (0.0 ... 1.0)
    /// High remaining is green, medium is yellow, low remaining is red.
    static func color(for remainingFraction: Double) -> Color {
        if remainingFraction < 0.20 {
            return Color(red: 1.0, green: 0.30, blue: 0.12) // Red / Alert
        } else if remainingFraction < 0.50 {
            return Color(red: 0.98, green: 0.82, blue: 0.18) // Yellow / Caution
        } else {
            return Color(red: 0.18, green: 0.88, blue: 0.55) // Green / Healthy
        }
    }

    static func nsColor(for remainingFraction: Double) -> NSColor {
        if remainingFraction < 0.20 {
            return .systemRed
        } else if remainingFraction < 0.50 {
            return .systemYellow
        } else {
            return .systemGreen
        }
    }
}

