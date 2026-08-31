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
        let title: String
        let color: NSColor
        if let remaining = item?.headlineRemainingFraction {
            let percent = Int((remaining * 100).rounded())
            title = " \(percent)%"
            color = StatusColor.nsColor(for: remaining)
        } else {
            title = " —"
            color = .secondaryLabelColor
        }
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.menuBarFont(ofSize: 0),
            ]
        )
        let l10n = L10n.shared
        let remainingHint = item?.headlineRemainingFraction.map { " (\(l10n.remainingPercentText(Int(($0 * 100).rounded()))))" } ?? ""
        button.toolTip = "\(l10n.appTitle) · \(selection.selected.displayName)\(remainingHint)"
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
