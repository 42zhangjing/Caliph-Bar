import AppKit
import SwiftUI
import QuartzCore
import CaliphBarCore

@MainActor
final class DetailPanelWindow {
    private enum PanelMode: Equatable {
        case menuBar
        case side(EdgeSide)
        case sideRadar(EdgeSide)
    }

    private let panel: NSPanel
    private let store: UsageStore
    private let selection: SelectionModel
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hoverGlobalMonitor: Any?
    private var hoverLocalMonitor: Any?
    private var outsideClickExclusionFrame: NSRect?
    private var dismissWorkItem: DispatchWorkItem?
    private let shadowPadding: CGFloat = 16
    private var currentMode: PanelMode?
    private var lastHoverEvaluation: CFTimeInterval = 0

    var hoverExclusionFrame: (() -> NSRect?)?

    init(store: UsageStore, selection: SelectionModel) {
        self.store = store
        self.selection = selection
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 356, height: 330),
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
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let hoverGlobalMonitor { NSEvent.removeMonitor(hoverGlobalMonitor) }
        if let hoverLocalMonitor { NSEvent.removeMonitor(hoverLocalMonitor) }
    }

    var isShown: Bool { panel.isVisible && panel.alphaValue > 0.01 }
    var frame: NSRect { panel.frame }
    var isMenuBarMode: Bool { currentMode == .menuBar }

    func show(relativeTo rect: NSRect, of view: NSView, side: EdgeSide?) {
        guard let window = view.window, let screen = window.screen ?? NSScreen.main else { return }
        let anchor = window.convertToScreen(view.convert(rect, to: nil))
        showOrUpdate(anchoredTo: anchor, on: screen, side: side, excluding: nil)
    }

    func showOrUpdate(
        anchoredTo anchor: NSRect,
        on screen: NSScreen,
        side: EdgeSide?,
        excluding exclusionFrame: NSRect?
    ) {
        let mode: PanelMode = side.map(PanelMode.side) ?? .menuBar
        present(mode: mode, anchoredTo: anchor, on: screen, side: side, excluding: exclusionFrame)
    }

    func showRadarOrUpdate(
        anchoredTo anchor: NSRect,
        on screen: NSScreen,
        side: EdgeSide,
        excluding exclusionFrame: NSRect?
    ) {
        present(mode: .sideRadar(side), anchoredTo: anchor, on: screen, side: side, excluding: exclusionFrame)
    }

    private func present(
        mode newMode: PanelMode,
        anchoredTo anchor: NSRect,
        on screen: NSScreen,
        side: EdgeSide?,
        excluding exclusionFrame: NSRect?
    ) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        outsideClickExclusionFrame = exclusionFrame

        if panel.contentViewController == nil || currentMode != newMode {
            let rootView: AnyView
            switch newMode {
            case .menuBar:
                rootView = AnyView(
                    DetailPanelView(store: store, selection: selection)
                )
            case let .side(edge):
                rootView = AnyView(
                    SideDetailPanelView(store: store, selection: selection, side: edge)
                )
            case let .sideRadar(edge):
                rootView = AnyView(SideRadarPanelView(side: edge))
            }

            let hosting = NSHostingController(rootView: rootView)
            hosting.sizingOptions = [.preferredContentSize]
            hosting.view.wantsLayer = true
            hosting.view.layer?.backgroundColor = .clear
            panel.contentViewController = hosting
            currentMode = newMode
        }

        guard let hosting = panel.contentViewController else { return }
        let size = preferredSize(for: newMode, hosting: hosting)
        let targetOrigin = calculateOrigin(for: anchor, size: size, on: screen, side: side)
        let targetFrame = NSRect(origin: targetOrigin, size: size)

        if isShown {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.17
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.86, 0.22, 1.0)
                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = 1.0
            }
        } else {
            panel.setFrame(targetFrame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.86, 0.22, 1.0)
                panel.animator().alphaValue = 1.0
            }
        }

        installOutsideClickMonitors()
        if isMenuBarMode {
            removeHoverMoveMonitors()
        } else {
            installHoverMoveMonitors()
        }
    }

    private func preferredSize(for mode: PanelMode, hosting: NSViewController) -> NSSize {
        switch mode {
        case .side, .sideRadar:
            return NSSize(
                width: SideDetailPanelLayout.contentSize.width,
                height: SideDetailPanelLayout.contentSize.height
            )
        case .menuBar:
            let fitting = hosting.view.fittingSize
            if fitting.width >= 1, fitting.height >= 1 {
                return fitting
            }
            return NSSize(width: 342, height: 330)
        }
    }

    private func calculateOrigin(
        for anchor: NSRect,
        size: NSSize,
        on screen: NSScreen,
        side: EdgeSide?
    ) -> NSPoint {
        let pointerGap: CGFloat = 8
        var targetOrigin: NSPoint

        switch side {
        case .right:
            targetOrigin = NSPoint(
                x: anchor.minX - size.width - pointerGap + shadowPadding,
                y: anchor.midY - size.height / 2
            )
        case .left:
            targetOrigin = NSPoint(
                x: anchor.maxX + pointerGap - shadowPadding,
                y: anchor.midY - size.height / 2
            )
        case nil:
            targetOrigin = NSPoint(
                x: anchor.midX - size.width / 2,
                y: anchor.minY - size.height - 8
            )
        }

        let frame = screen.visibleFrame
        targetOrigin.x = min(max(targetOrigin.x, frame.minX - shadowPadding + 8), frame.maxX - size.width + shadowPadding - 8)
        targetOrigin.y = min(max(targetOrigin.y, frame.minY - shadowPadding + 8), frame.maxY - size.height + shadowPadding - 8)

        return targetOrigin
    }

    func scheduleHoverDismiss(delay: TimeInterval = 0.32) {
        guard isShown, !isMenuBarMode else { return }
        guard dismissWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.dismissWorkItem = nil
                let mouse = NSEvent.mouseLocation
                if self.isInsideHoverRegion(mouse) {
                    return
                }
                self.hide()
            }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func cancelHoverDismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }

    func hide() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        guard panel.isVisible else { return }
        removeOutsideClickMonitors()
        removeHoverMoveMonitors()

        // Side panels must leave the WindowServer synchronously. Deferring
        // orderOut until an alpha animation completes can strand the SwiftUI
        // shadow layer until the next system input event.
        panel.contentView?.layer?.removeAllAnimations()
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.shouldHide(for: NSEvent.mouseLocation) { self.hide() }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if self.shouldHide(for: NSEvent.mouseLocation) { self.hide() }
            return event
        }
    }

    private func shouldHide(for point: NSPoint) -> Bool {
        if panel.frame.contains(point) { return false }
        if currentExclusionFrame?.contains(point) == true { return false }
        return true
    }

    private var currentExclusionFrame: NSRect? {
        hoverExclusionFrame?() ?? outsideClickExclusionFrame
    }

    private func isInsideHoverRegion(_ point: NSPoint) -> Bool {
        panel.frame.contains(point) || currentExclusionFrame?.contains(point) == true
    }

    private func installHoverMoveMonitors() {
        guard hoverGlobalMonitor == nil, hoverLocalMonitor == nil else { return }

        hoverGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in
                self?.updateHoverDismiss(at: NSEvent.mouseLocation)
            }
        }
        hoverLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateHoverDismiss(at: NSEvent.mouseLocation)
            return event
        }
    }

    private func updateHoverDismiss(at point: NSPoint) {
        guard isShown, !isMenuBarMode else { return }
        let now = CACurrentMediaTime()
        guard now - lastHoverEvaluation >= (1.0 / 90.0) else { return }
        lastHoverEvaluation = now

        if isInsideHoverRegion(point) {
            cancelHoverDismiss()
        } else {
            scheduleHoverDismiss()
        }
    }

    private func removeHoverMoveMonitors() {
        if let hoverGlobalMonitor { NSEvent.removeMonitor(hoverGlobalMonitor) }
        if let hoverLocalMonitor { NSEvent.removeMonitor(hoverLocalMonitor) }
        hoverGlobalMonitor = nil
        hoverLocalMonitor = nil
    }

    private func removeOutsideClickMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        outsideClickExclusionFrame = nil
    }
}
