import SwiftUI
import AppKit

enum StatusColor {
    static func color(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.5: return Color(red: 0.18, green: 0.88, blue: 0.55)
        case ..<0.8: return Color(red: 0.98, green: 0.82, blue: 0.18)
        default: return Color(red: 1.0, green: 0.30, blue: 0.12)
        }
    }

    static func nsColor(for fraction: Double) -> NSColor {
        switch fraction {
        case ..<0.5: return .systemGreen
        case ..<0.8: return .systemYellow
        default: return .systemOrange
        }
    }
}
