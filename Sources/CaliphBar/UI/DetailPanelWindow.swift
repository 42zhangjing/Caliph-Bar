import AppKit
import SwiftUI

@MainActor
final class DetailPanelWindow {
    private let panel: NSPanel
    private let hosting: NSHostingController<DetailPanelView>
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(store: UsageStore, selection: SelectionModel) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 356, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false

        hosting = NSHostingController(rootView: DetailPanelView(store: store, selection: selection))
        hosting.sizingOptions = [.preferredContentSize]
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear
        panel.contentViewController = hosting
    }

    var isShown: Bool { panel.isVisible }

    func show(relativeTo rect: NSRect, of view: NSView, side: EdgeSide?) {
        guard let window = view.window, let screen = window.screen ?? NSScreen.main else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        var size = hosting.view.fittingSize
        if size.width < 1 || size.height < 1 { size = NSSize(width: 356, height: 280) }
        panel.setContentSize(size)

        let anchor = window.convertToScreen(view.convert(rect, to: nil))
        var origin: NSPoint
        switch side {
        case .right:
            origin = NSPoint(x: anchor.minX - size.width - 10, y: anchor.midY - size.height / 2)
        case .left:
            origin = NSPoint(x: anchor.maxX + 10, y: anchor.midY - size.height / 2)
        case nil:
            origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.minY - size.height - 8)
        }

        let frame = screen.visibleFrame
        origin.x = min(max(origin.x, frame.minX + 8), frame.maxX - size.width - 8)
        origin.y = min(max(origin.y, frame.minY + 8), frame.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
        panel.alphaValue = 1
        installOutsideClickMonitors()
    }

    func hide() {
        panel.orderOut(nil)
        removeOutsideClickMonitors()
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) { self.hide() }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if !self.panel.frame.contains(NSEvent.mouseLocation) { self.hide() }
            return event
        }
    }

    private func removeOutsideClickMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }
}
