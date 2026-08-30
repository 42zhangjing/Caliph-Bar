import AppKit
import SwiftUI
import QuartzCore
import CaliphBarCore

@MainActor
final class DetailPanelWindow {
    private let panel: NSPanel
    private let store: UsageStore
    private let selection: SelectionModel
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isAnimating = false
    private var outsideClickExclusionFrame: NSRect?
    private var dismissWorkItem: DispatchWorkItem?
    private let shadowPadding: CGFloat = 28
    private var currentSide: EdgeSide?

    init(store: UsageStore, selection: SelectionModel) {
        self.store = store
        self.selection = selection
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
    }

    var isShown: Bool { panel.isVisible && panel.alphaValue > 0.01 }
    var frame: NSRect { panel.frame }

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
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        let chosenSide = side ?? .right
        outsideClickExclusionFrame = exclusionFrame
        currentSide = side

        // Recreate root view only if side or content controller changed
        if panel.contentViewController == nil || currentSide != side {
            let rootView: AnyView
            if side != nil {
                rootView = AnyView(
                    SideDetailPanelView(store: store, selection: selection, side: chosenSide)
                )
            } else {
                rootView = AnyView(
                    DetailPanelView(store: store, selection: selection, side: chosenSide)
                )
            }
            let hosting = NSHostingController(rootView: rootView)
            hosting.sizingOptions = [.preferredContentSize]
            hosting.view.wantsLayer = true
            hosting.view.layer?.backgroundColor = .clear
            panel.contentViewController = hosting
        }

        guard let hosting = panel.contentViewController else { return }
        var size = hosting.view.fittingSize
        if size.width < 1 || size.height < 1 { size = NSSize(width: 356 + shadowPadding * 2, height: 280 + shadowPadding * 2) }
        panel.setContentSize(size)

        let targetOrigin = calculateOrigin(for: anchor, size: size, on: screen, side: side)

        if isShown {
            // Already visible: smoothly animate position to the new provider row
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 1.0, 0.32, 1.0)
                panel.animator().setFrameOrigin(targetOrigin)
            }
        } else {
            // Not visible: set position and smoothly fade in
            panel.setFrameOrigin(targetOrigin)
            panel.alphaValue = 0
            panel.orderFrontRegardless()

            isAnimating = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 1.0, 0.32, 1.0)
                panel.animator().alphaValue = 1.0
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    self?.isAnimating = false
                }
            }
        }

        installOutsideClickMonitors()
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
            // Pointer tip is at the right edge of the card, distance to view boundary is shadowPadding.
            // We want pointer tip X to be anchor.minX - pointerGap.
            targetOrigin = NSPoint(
                x: anchor.minX - size.width - pointerGap + shadowPadding,
                y: anchor.midY - size.height / 2
            )
        case .left:
            // Pointer tip is at the left edge of the card, distance to view boundary is shadowPadding.
            // We want pointer tip X to be anchor.maxX + pointerGap.
            targetOrigin = NSPoint(
                x: anchor.maxX + pointerGap - shadowPadding,
                y: anchor.midY - size.height / 2
            )
        case nil:
            targetOrigin = NSPoint(
                x: anchor.midX - size.width / 2,
                y: anchor.minY - size.height - 8 + shadowPadding
            )
        }

        let frame = screen.visibleFrame
        targetOrigin.x = min(max(targetOrigin.x, frame.minX - shadowPadding + 8), frame.maxX - size.width + shadowPadding - 8)
        targetOrigin.y = min(max(targetOrigin.y, frame.minY - shadowPadding + 8), frame.maxY - size.height + shadowPadding - 8)

        return targetOrigin
    }

    func scheduleHoverDismiss(delay: TimeInterval = 0.35) {
        guard isShown else { return }
        dismissWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let mouse = NSEvent.mouseLocation
                // If mouse is currently inside the panel or exclusion frame, don't dismiss
                if self.panel.frame.contains(mouse) || self.outsideClickExclusionFrame?.contains(mouse) == true {
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
        guard isShown, !isAnimating else { return }
        removeOutsideClickMonitors()
        isAnimating = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.panel.orderOut(nil)
                self.isAnimating = false
            }
        }
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
        if outsideClickExclusionFrame?.contains(point) == true { return false }
        return true
    }

    private func removeOutsideClickMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        outsideClickExclusionFrame = nil
    }
}
