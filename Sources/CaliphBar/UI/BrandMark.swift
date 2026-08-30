import SwiftUI
import AppKit
import CaliphBarCore

struct BrandMark: View {
    let provider: ProviderID
    var size: CGFloat = 28
    var isMuted: Bool = false

    var body: some View {
        if let image = loadSVGIcon(for: provider) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .opacity(isMuted ? 0.70 : 1.0)
                .accessibilityLabel(provider.displayName)
        } else {
            fallbackIcon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .opacity(isMuted ? 0.70 : 1.0)
                .accessibilityLabel(provider.displayName)
        }
    }

    private var fallbackIcon: Image {
        switch provider {
        case .claude: return Image(systemName: "sun.min.fill")
        case .codex: return Image(systemName: "terminal.fill")
        case .gemini: return Image(systemName: "sparkles")
        }
    }

    private func loadSVGIcon(for provider: ProviderID) -> NSImage? {
        let name = provider.rawValue.lowercased()
        let paths = [
            Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Icons")?.path,
            Bundle.main.url(forResource: name, withExtension: "svg")?.path,
            "Resources/Icons/\(name).svg"
        ].compactMap { $0 }

        for path in paths where FileManager.default.fileExists(atPath: path) {
            if let image = NSImage(contentsOfFile: path) {
                image.isTemplate = false // Preserve authentic multi-color gradients & brand colors
                return image
            }
        }
        return nil
    }
}
