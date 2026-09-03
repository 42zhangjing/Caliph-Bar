import AppKit
import Combine
import CaliphBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = UsageStore()
    private let selection = SelectionModel()
    private var detailPanel: DetailPanelWindow!
    private var pillWindow: FloatingPillWindow!
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "CaliphBar")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusItemClicked)
        }

        detailPanel = DetailPanelWindow(store: store, selection: selection)
        pillWindow = FloatingPillWindow(store: store, selection: selection)

        detailPanel.hoverExclusionFrame = { [weak self] in
            self?.pillWindow.hoverInteractionFrame
        }

        pillWindow.companionHoverFrame = { [weak self] in
            guard let self, self.detailPanel.isShown, !self.detailPanel.isMenuBarMode else { return nil }
            return self.detailPanel.frame
        }

        pillWindow.onProviderTapped = { [weak self] _, anchor, pillFrame, screen, side in
            guard let self else { return }
            self.store.refresh()
            self.detailPanel.showOrUpdate(
                anchoredTo: anchor,
                on: screen,
                side: side,
                excluding: pillFrame
            )
        }

        pillWindow.onProviderHovered = { [weak self] _, anchor, pillFrame, screen, side in
            guard let self else { return }

            // Do not let a passive pill hover replace the full menu-bar panel
            // while the user is reading settings or interacting with it.
            if self.detailPanel.isShown && self.detailPanel.isMenuBarMode { return }

            self.detailPanel.showOrUpdate(
                anchoredTo: anchor,
                on: screen,
                side: side,
                excluding: pillFrame
            )
        }

        pillWindow.onRadarTapped = { [weak self] anchor, pillFrame, screen, side in
            guard let self else { return }
            CodexRadarStore.shared.refresh()
            self.detailPanel.showRadarOrUpdate(
                anchoredTo: anchor,
                on: screen,
                side: side,
                excluding: pillFrame
            )
        }

        pillWindow.onRadarHovered = { [weak self] anchor, pillFrame, screen, side in
            guard let self else { return }
            if self.detailPanel.isShown && self.detailPanel.isMenuBarMode { return }
            self.detailPanel.showRadarOrUpdate(
                anchoredTo: anchor,
                on: screen,
                side: side,
                excluding: pillFrame
            )
        }

        pillWindow.onPillMouseExited = { [weak self] in
            self?.detailPanel.scheduleHoverDismiss()
        }

        if store.pillVisible { pillWindow.show() }

        store.$pillVisible
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                guard let self else { return }
                visible ? self.pillWindow.show() : self.pillWindow.hide()
            }
            .store(in: &cancellables)

        store.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        selection.$selected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        L10n.shared.$currentLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let item = store.item(for: selection.selected)
        let remaining = item?.headlineRemainingFraction

        button.image = miniGaugeImage(for: selection.selected, remainingFraction: remaining)
        button.imagePosition = .imageLeading

        let title: String
        let color: NSColor
        if let remaining {
            title = " \(StatusColor.percentageText(for: remaining))"
            color = StatusColor.nsValueColor(for: remaining)
        } else {
            title = " —"
            color = .secondaryLabelColor
        }
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
                    weight: .semibold
                ),
            ]
        )
        let l10n = L10n.shared
        let remainingHint = remaining.map { " (\(l10n.remainingPercentText(Int(($0 * 100).rounded()))))" } ?? ""
        button.toolTip = "\(l10n.appTitle) · \(selection.selected.displayName)\(remainingHint)"
    }

    private func miniGaugeImage(for provider: ProviderID, remainingFraction: Double?) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 6.4
            let lineWidth: CGFloat = 1.6

            // Background track
            context.setLineWidth(lineWidth)
            context.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.20).cgColor)
            context.strokeEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            // Active progress track
            if let fraction = remainingFraction, fraction > 0.001 {
                let startAngle = CGFloat.pi / 2 // 12 o'clock in CoreGraphics
                let sweep = CGFloat(min(1.0, max(0.0, fraction))) * 2 * CGFloat.pi
                let endAngle = startAngle - sweep

                let progressPath = CGMutablePath()
                progressPath.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: true
                )

                let progressColor: NSColor
                if fraction < 0.10 {
                    progressColor = NSColor(calibratedRed: 1.0, green: 0.271, blue: 0.227, alpha: 1.0)
                } else if fraction < 0.20 {
                    progressColor = NSColor(calibratedRed: 1.0, green: 0.624, blue: 0.039, alpha: 1.0)
                } else {
                    progressColor = NSColor.labelColor.withAlphaComponent(0.92)
                }

                context.setStrokeColor(progressColor.cgColor)
                context.setLineCap(.round)
                context.addPath(progressPath)
                context.strokePath()
            }

            // Inner Provider Mark
            context.setFillColor(NSColor.labelColor.withAlphaComponent(0.85).cgColor)
            switch provider {
            case .claude:
                context.fillEllipse(in: CGRect(x: center.x - 1.8, y: center.y - 1.8, width: 3.6, height: 3.6))
            case .codex:
                context.fill(CGRect(x: center.x - 1.7, y: center.y - 1.7, width: 3.4, height: 3.4))
            case .gemini:
                let diamond = CGMutablePath()
                diamond.move(to: CGPoint(x: center.x, y: center.y + 2.4))
                diamond.addLine(to: CGPoint(x: center.x + 2.2, y: center.y))
                diamond.addLine(to: CGPoint(x: center.x, y: center.y - 2.4))
                diamond.addLine(to: CGPoint(x: center.x - 2.2, y: center.y))
                diamond.closeSubpath()
                context.addPath(diamond)
                context.fillPath()
            }

            return true
        }

        if let fraction = remainingFraction, fraction < 0.20 {
            image.isTemplate = false
        } else {
            image.isTemplate = true
        }
        return image
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }

        if detailPanel.isShown && detailPanel.isMenuBarMode {
            detailPanel.hide()
            return
        }

        store.refresh()
        detailPanel.show(relativeTo: button.bounds, of: button, side: nil)
    }
}
