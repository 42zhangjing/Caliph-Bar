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

    private enum VisibilityState {
        case hidden
        case presenting
        case visible
        case dismissing
    }

    private enum Motion {
        static let animationKey = "caliphbar.detail-presentation"
        static let presentedTransform = CATransform3DIdentity
        static let hiddenScale: CGFloat = 0.985
        static let showDuration: CFTimeInterval = 0.16
        static let hideDuration: CFTimeInterval = 0.12
        static let reducedMotionDuration: CFTimeInterval = 0.08
        static let showTiming = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.30, 1.0)
        static let hideTiming = CAMediaTimingFunction(controlPoints: 0.40, 0.0, 1.0, 1.0)
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
    private var visibilityState: VisibilityState = .hidden
    private var visibilityGeneration = 0

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
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let hoverGlobalMonitor { NSEvent.removeMonitor(hoverGlobalMonitor) }
        if let hoverLocalMonitor { NSEvent.removeMonitor(hoverLocalMonitor) }
    }

    var isShown: Bool {
        visibilityState == .presenting || visibilityState == .visible
    }
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
        let previousVisibility = visibilityState
        let modeChanged = currentMode != newMode

        if panel.contentViewController == nil || modeChanged {
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
                rootView = AnyView(SideRadarPanelView(side: edge, selection: selection))
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
        let (targetOrigin, pointerOffset) = calculateOrigin(for: anchor, size: size, on: screen, side: side)
        let targetFrame = NSRect(origin: targetOrigin, size: size)
        withAnimation(.easeOut(duration: 0.16)) {
            selection.sidePointerOffset = pointerOffset
        }
        let wasPresented = previousVisibility == .presenting || previousVisibility == .visible
        let wasDismissing = previousVisibility == .dismissing

        if wasPresented || wasDismissing {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.17
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.86, 0.22, 1.0)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }

        panel.contentView?.layoutSubtreeIfNeeded()
        configurePresentationAnchor(for: newMode)

        if previousVisibility == .hidden {
            setContentPresentation(visible: false, mode: newMode)
        }

        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        if !wasPresented { panel.orderFrontRegardless() }

        if wasPresented {
            if modeChanged { setContentPresentation(visible: true, mode: newMode) }
            visibilityState = .visible
        } else {
            animateContentPresentation(visible: true, mode: newMode)
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
    ) -> (origin: NSPoint, pointerOffset: CGFloat) {
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

        let idealY = targetOrigin.y
        let frame = screen.visibleFrame
        targetOrigin.x = min(max(targetOrigin.x, frame.minX - shadowPadding + 8), frame.maxX - size.width + shadowPadding - 8)
        targetOrigin.y = min(max(targetOrigin.y, frame.minY - shadowPadding + 8), frame.maxY - size.height + shadowPadding - 8)

        let pointerOffset = side != nil ? (targetOrigin.y - idealY) : 0
        return (targetOrigin, pointerOffset)
    }

    func scheduleHoverDismiss(delay: TimeInterval = 0) {
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
        guard visibilityState == .presenting || visibilityState == .visible else { return }
        removeOutsideClickMonitors()

        guard let currentMode else { return }
        animateContentPresentation(visible: false, mode: currentMode)
    }

    private func revealCurrentPanel() {
        guard visibilityState == .dismissing, let currentMode else { return }
        panel.ignoresMouseEvents = false
        animateContentPresentation(visible: true, mode: currentMode)
        installOutsideClickMonitors()
        if !isMenuBarMode { installHoverMoveMonitors() }
    }

    private func configurePresentationAnchor(for mode: PanelMode) {
        guard let layer = panel.contentView?.layer else { return }

        let targetAnchor: CGPoint
        switch mode {
        case .side(.left), .sideRadar(.left):
            targetAnchor = CGPoint(x: 0, y: 0.5)
        case .side(.right), .sideRadar(.right):
            targetAnchor = CGPoint(x: 1, y: 0.5)
        case .menuBar:
            targetAnchor = CGPoint(x: 0.5, y: 1)
        }

        guard layer.anchorPoint != targetAnchor else { return }
        let oldAnchor = layer.anchorPoint
        let oldPosition = layer.position
        layer.anchorPoint = targetAnchor
        layer.position = CGPoint(
            x: oldPosition.x + (targetAnchor.x - oldAnchor.x) * layer.bounds.width,
            y: oldPosition.y + (targetAnchor.y - oldAnchor.y) * layer.bounds.height
        )
    }

    private func setContentPresentation(visible: Bool, mode: PanelMode) {
        guard let layer = panel.contentView?.layer else { return }
        layer.removeAnimation(forKey: Motion.animationKey)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = visible ? 1 : 0
        layer.transform = presentationTransform(visible: visible, mode: mode)
        CATransaction.commit()
    }

    private func animateContentPresentation(visible: Bool, mode: PanelMode) {
        guard let layer = panel.contentView?.layer else {
            visibilityState = visible ? .visible : .hidden
            panel.ignoresMouseEvents = !visible
            return
        }

        let presentationLayer = layer.presentation()
        let startOpacity = presentationLayer?.opacity ?? layer.opacity
        let startTransform = presentationLayer?.transform ?? layer.transform
        let targetOpacity: Float = visible ? 1 : 0
        let targetTransform = presentationTransform(visible: visible, mode: mode)

        layer.removeAnimation(forKey: Motion.animationKey)
        visibilityGeneration += 1
        let generation = visibilityGeneration
        visibilityState = visible ? .presenting : .dismissing

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = targetOpacity
        layer.transform = targetTransform
        CATransaction.commit()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let baseDuration = reduceMotion
            ? Motion.reducedMotionDuration
            : (visible ? Motion.showDuration : Motion.hideDuration)
        let remaining = min(1, max(0.35, Double(abs(targetOpacity - startOpacity))))
        let duration = baseDuration * remaining

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = startOpacity
        opacity.toValue = targetOpacity

        let transform = CABasicAnimation(keyPath: "transform")
        transform.fromValue = NSValue(caTransform3D: startTransform)
        transform.toValue = NSValue(caTransform3D: targetTransform)

        let group = CAAnimationGroup()
        group.animations = reduceMotion ? [opacity] : [opacity, transform]
        group.duration = duration
        group.timingFunction = visible ? Motion.showTiming : Motion.hideTiming

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            Task { @MainActor in
                guard let self, self.visibilityGeneration == generation else { return }
                layer.removeAnimation(forKey: Motion.animationKey)
                if visible {
                    self.visibilityState = .visible
                    self.panel.ignoresMouseEvents = false
                } else {
                    // Keep the clear WindowServer surface alive instead of ordering
                    // the panel out over another app's translucent window. This avoids
                    // stale compositor tiles while remaining fully click-through.
                    self.visibilityState = .hidden
                    self.panel.ignoresMouseEvents = true
                    self.removeHoverMoveMonitors()
                }
            }
        }
        layer.add(group, forKey: Motion.animationKey)
        CATransaction.commit()
    }

    private func presentationTransform(visible: Bool, mode: PanelMode) -> CATransform3D {
        guard !visible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return Motion.presentedTransform
        }

        var transform = CATransform3DMakeScale(Motion.hiddenScale, Motion.hiddenScale, 1)
        switch mode {
        case .side(.left), .sideRadar(.left):
            transform = CATransform3DTranslate(transform, -2.5, 0, 0)
        case .side(.right), .sideRadar(.right):
            transform = CATransform3DTranslate(transform, 2.5, 0, 0)
        case .menuBar:
            break
        }
        return transform
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
        guard visibilityState != .hidden, !isMenuBarMode else { return }
        let now = CACurrentMediaTime()
        guard now - lastHoverEvaluation >= (1.0 / 90.0) else { return }
        lastHoverEvaluation = now

        if isInsideHoverRegion(point) {
            cancelHoverDismiss()
            revealCurrentPanel()
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
