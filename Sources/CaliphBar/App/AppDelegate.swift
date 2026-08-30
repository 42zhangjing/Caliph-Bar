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
        pillWindow.onProviderTapped = { [weak self] _, view, side in
            guard let self else { return }
            if self.detailPanel.isShown { return }
            self.store.refresh()
            self.detailPanel.show(relativeTo: view.bounds, of: view, side: side)
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

        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let item = store.item(for: selection.selected)
        let title: String
        let color: NSColor
        if let fraction = item?.headlineFraction {
            title = " \(min(999, Int(fraction * 100)))%"
            color = StatusColor.nsColor(for: fraction)
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
        button.toolTip = "CaliphBar · \(selection.selected.displayName)"
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        if detailPanel.isShown {
            detailPanel.hide()
        } else {
            store.refresh()
            detailPanel.show(relativeTo: button.bounds, of: button, side: nil)
        }
    }
}
