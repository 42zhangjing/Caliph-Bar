import SwiftUI

enum RingCoreStyle: String, CaseIterable, Identifiable {
    case dark
    case porcelain

    var id: String { rawValue }

    var inset: CGFloat {
        self == .porcelain ? 3.05 : 2.25
    }

    var fillStyle: AnyShapeStyle {
        switch self {
        case .dark:
            return AnyShapeStyle(
                Color(red: 0.035, green: 0.039, blue: 0.047).opacity(0.96)
            )
        case .porcelain:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.925, green: 0.918, blue: 0.898),
                        Color(red: 0.878, green: 0.867, blue: 0.839),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    var separatorColor: Color {
        self == .porcelain ? .black.opacity(0.12) : .clear
    }

    var radarBrandColor: Color {
        self == .porcelain
            ? Color(red: 0.02, green: 0.52, blue: 0.43)
            : CodexRadarPresentation.brandColor
    }
}
