import AppKit
import SwiftUI
import Combine
import QuartzCore
import CaliphBarCore

@MainActor
final class FloatingPillWindow: NSObject {
    private let panel: NSPanel
    private let hosting: NSHostingController<FloatingPillView>
    private let position: PillPositionModel
    private let store: UsageStore
    private let selection: SelectionModel
    private var cancellables: Set<AnyCancellable> = []
    private var dragStartFrame: NSRect?
    private var screenObserver: NSObjectProtocol?
    private var hoverGlobalMonitor: Any?
    private var hoverLocalMonitor: Any?
    private var hoverCollapseWorkItem: DispatchWorkItem?
    private var lastHoveredProvider: ProviderID?
    private var radarWasHovered = false
    private var pointerWasInsidePill = false
    private var lastHoverEvaluation: CFTimeInterval = 0

    var onProviderTapped: ((ProviderID, NSRect, NSRect, NSScreen, EdgeSide) -> Void)?
    var onProviderHovered: ((ProviderID, NSRect, NSRect, NSScreen, EdgeSide) -> Void)?
    var onRadarTapped: ((NSRect, NSRect, NSScreen, EdgeSide) -> Void)?
    var onRadarHovered: ((NSRect, NSRect, NSScreen, EdgeSide) -> Void)?
    var onPillMouseExited: (() -> Void)?
    var companionHoverFrame: (() -> NSRect?)?

    private enum Keys {
        static let originY = "caliphbar.pillOriginY"
        static let side = "caliphbar.pillSide"
    }

    init(store: UsageStore, selection: SelectionModel) {
        self.store = store
        self.selection = selection
        position = PillPositionModel(side: store.pillSide)

        panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: SideNotchLayout.compactWindowSize.width,
                height: SideNotchLayout.compactWindowSize.height
            ),
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
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true

        hosting = NSHostingController(rootView: FloatingPillView(store: store, position: position))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear
        panel.contentViewController = hosting

        super.init()

        position.onProviderTapped = { [weak self] provider in
            self?.handleProviderAction(provider, isTap: true)
        }

        position.onRadarTapped = { [weak self] in
            self?.handleRadarAction(isTap: true)
        }

        position.onDragMoved = { [weak self] translation in
            self?.handleDrag(translation: translation, isEnded: false)
        }

        position.onDragEnded = { [weak self] translation in
            self?.handleDrag(translation: translation, isEnded: true)
        }

        store.$pillBehavior
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.lastHoveredProvider = nil
                self.updateWindowFrame(animated: false)
            }
            .store(in: &cancellables)

        store.$pillSide
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] side in
                guard let self, self.position.side != side else { return }
                self.position.side = side
                self.updateWindowFrame(animated: true)
            }
            .store(in: &cancellables)

        store.$radarPinned
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let centerY = self.panel.frame.midY
                UserDefaults.standard.set(centerY - self.windowSize.height / 2, forKey: Keys.originY)
                self.lastHoveredProvider = nil
                self.radarWasHovered = false
                self.updateWindowFrame(animated: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .caliphBarCenterPill)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.centerOnCurrentScreen() }
            .store(in: &cancellables)

        installObservers()
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let hoverGlobalMonitor { NSEvent.removeMonitor(hoverGlobalMonitor) }
        if let hoverLocalMonitor { NSEvent.removeMonitor(hoverLocalMonitor) }
    }

    var side: EdgeSide { position.side }
    var isVisible: Bool { panel.isVisible }
    var hoverInteractionFrame: NSRect { hoverHitFrame() }

    func show() {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        updateWindowFrame(animated: false)
        panel.alphaValue = 1
    }

    func hide() {
        hoverCollapseWorkItem?.cancel()
        hoverCollapseWorkItem = nil
        pointerWasInsidePill = false
        lastHoveredProvider = nil
        panel.orderOut(nil)
    }

    private var windowSize: NSSize {
        let size = SideNotchLayout.windowSize(radarPinned: store.radarPinned)
        return NSSize(width: size.width, height: size.height)
    }

    private func updateWindowFrame(animated: Bool) {
        guard let screen = screenContainingPanel() ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = windowSize

        let savedY = UserDefaults.standard.object(forKey: Keys.originY) as? CGFloat ?? (visible.midY - size.height / 2)
        let clampedY = min(max(savedY, visible.minY + 12), visible.maxY - size.height - 12)

        let targetX: CGFloat
        switch position.side {
        case .right:
            targetX = screen.frame.maxX - size.width + SideNotchLayout.edgeBleed
        case .left:
            targetX = screen.frame.minX - SideNotchLayout.edgeBleed
        }

        let targetRect = NSRect(x: targetX, y: clampedY, width: size.width, height: size.height)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 1.0, 0.32, 1.0)
                panel.animator().setFrame(targetRect, display: true)
            }
        } else {
            panel.setFrame(targetRect, display: true)
        }

        UserDefaults.standard.set(clampedY, forKey: Keys.originY)
        UserDefaults.standard.set(position.side.rawValue, forKey: Keys.side)
    }

    private func handleProviderAction(_ provider: ProviderID, isTap: Bool) {
        if selection.sidePreview != provider {
            withAnimation(.easeOut(duration: 0.14)) {
                selection.previewFromPill(provider)
            }
        }

        guard
            let index = ProviderID.allCases.firstIndex(of: provider),
            let screen = panel.screen ?? screenContainingPanel() ?? NSScreen.main
        else { return }

        let centerFromTop = SideNotchLayout.providerCenterYFromTop(
            index: index,
            providerCount: moduleCount,
            height: windowSize.height
        )
        let centerY = panel.frame.maxY - centerFromTop
        let anchor = NSRect(
            x: panel.frame.minX,
            y: centerY - SideNotchLayout.itemSize.height / 2,
            width: panel.frame.width,
            height: SideNotchLayout.itemSize.height
        )

        if isTap {
            onProviderTapped?(provider, anchor, panel.frame, screen, position.side)
        } else {
            onProviderHovered?(provider, anchor, panel.frame, screen, position.side)
        }
    }

    private var moduleCount: Int { ProviderID.allCases.count + (store.radarPinned ? 1 : 0) }

    private func handleRadarAction(isTap: Bool) {
        guard store.radarPinned,
              let screen = panel.screen ?? screenContainingPanel() ?? NSScreen.main
        else { return }

        let centerFromTop = SideNotchLayout.providerCenterYFromTop(
            index: ProviderID.allCases.count,
            providerCount: moduleCount,
            height: windowSize.height
        )
        let centerY = panel.frame.maxY - centerFromTop
        let anchor = NSRect(
            x: panel.frame.minX,
            y: centerY - SideNotchLayout.itemSize.height / 2,
            width: panel.frame.width,
            height: SideNotchLayout.itemSize.height
        )
        if isTap {
            onRadarTapped?(anchor, panel.frame, screen, position.side)
        } else {
            onRadarHovered?(anchor, panel.frame, screen, position.side)
        }
    }

    private func centerOnCurrentScreen() {
        guard let screen = screenContainingPanel() ?? NSScreen.main else { return }
        let y = screen.visibleFrame.midY - windowSize.height / 2
        UserDefaults.standard.set(y, forKey: Keys.originY)
        updateWindowFrame(animated: true)
    }

    private func handleDrag(translation: CGSize, isEnded: Bool) {
        if dragStartFrame == nil { dragStartFrame = panel.frame }
        guard let startFrame = dragStartFrame else { return }

        var proposedFrame = startFrame
        proposedFrame.origin.x += translation.width
        proposedFrame.origin.y -= translation.height

        let candidateCenter = NSPoint(x: proposedFrame.midX, y: proposedFrame.midY)
        guard let screen = screen(containing: candidateCenter) ?? nearestScreen(to: candidateCenter) else { return }

        let visible = screen.visibleFrame
        proposedFrame.origin.y = min(
            max(proposedFrame.origin.y, visible.minY + 12),
            visible.maxY - proposedFrame.height - 12
        )

        if isEnded {
            let chosenSide: EdgeSide = abs(proposedFrame.midX - screen.frame.minX)
                <= abs(screen.frame.maxX - proposedFrame.midX) ? .left : .right
            position.side = chosenSide
            store.pillSide = chosenSide

            switch chosenSide {
            case .left:
                proposedFrame.origin.x = screen.frame.minX - SideNotchLayout.edgeBleed
            case .right:
                proposedFrame.origin.x = screen.frame.maxX - proposedFrame.width + SideNotchLayout.edgeBleed
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 1.0, 0.32, 1.0)
                panel.animator().setFrame(proposedFrame, display: true)
            }

            UserDefaults.standard.set(proposedFrame.origin.y, forKey: Keys.originY)
            UserDefaults.standard.set(chosenSide.rawValue, forKey: Keys.side)
            dragStartFrame = nil
            lastHoveredProvider = nil
        } else {
            panel.setFrameOrigin(proposedFrame.origin)
        }
    }

    private func installObservers() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateWindowFrame(animated: false) }
        }

        hoverGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in self?.updateHoverState(at: NSEvent.mouseLocation) }
        }
        hoverLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateHoverState(at: NSEvent.mouseLocation)
            return event
        }
    }

    private func updateHoverState(at point: NSPoint) {
        let now = CACurrentMediaTime()
        guard now - lastHoverEvaluation >= (1.0 / 90.0) else { return }
        lastHoverEvaluation = now

        let insidePill = hoverHitFrame().contains(point)

        if insidePill {
            pointerWasInsidePill = true
            hoverCollapseWorkItem?.cancel()
            hoverCollapseWorkItem = nil

            if store.pillBehavior == .autoCollapse && !position.isHovered {
                withAnimation(.interpolatingSpring(stiffness: 280, damping: 24)) {
                    position.isHovered = true
                }
            }

            if let provider = provider(at: point), provider != lastHoveredProvider {
                radarWasHovered = false
                lastHoveredProvider = provider
                handleProviderAction(provider, isTap: false)
            } else if radar(at: point), !radarWasHovered {
                lastHoveredProvider = nil
                radarWasHovered = true
                handleRadarAction(isTap: false)
            }
            return
        }

        if pointerWasInsidePill {
            pointerWasInsidePill = false
            lastHoveredProvider = nil
            radarWasHovered = false
            onPillMouseExited?()
        }

        guard store.pillBehavior == .autoCollapse, position.isHovered, hoverCollapseWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.hoverCollapseWorkItem = nil
                let mouse = NSEvent.mouseLocation
                guard !self.hoverHitFrame().contains(mouse) else { return }
                if let companion = self.companionHoverFrame?(), companion.contains(mouse) { return }
                withAnimation(.interpolatingSpring(stiffness: 260, damping: 24)) {
                    self.position.isHovered = false
                }
                // The detail panel may have skipped its first dismissal while
                // this window still exposed the expanded hover frame. Re-arm
                // dismissal after the hit region actually becomes compact.
                self.onPillMouseExited?()
            }
        }
        hoverCollapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: workItem)
    }

    private func hoverHitFrame() -> NSRect {
        if store.pillBehavior == .alwaysExpanded || position.isHovered {
            return panel.frame
        }

        // The collapsed visual is intentionally tiny, but its hover target is
        // slightly larger so it remains easy to reveal without creating a huge
        // invisible window-wide hit area.
        let width: CGFloat = 30
        let height: CGFloat = 104
        let x = position.side == .right ? panel.frame.maxX - width : panel.frame.minX
        return NSRect(
            x: x,
            y: panel.frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func provider(at point: NSPoint) -> ProviderID? {
        let localYFromTop = panel.frame.maxY - point.y
        let providers = ProviderID.allCases
        var best: (provider: ProviderID, distance: CGFloat)?

        for (index, provider) in providers.enumerated() {
            let centerY = SideNotchLayout.providerCenterYFromTop(
                index: index,
                providerCount: moduleCount,
                height: windowSize.height
            )
            let distance = abs(localYFromTop - centerY)
            if best == nil || distance < best!.distance {
                best = (provider, distance)
            }
        }

        guard let best else { return nil }
        let activationRadius = (SideNotchLayout.itemSize.height + SideNotchLayout.itemSpacing) / 2
        return best.distance <= activationRadius ? best.provider : nil
    }

    private func radar(at point: NSPoint) -> Bool {
        guard store.radarPinned else { return false }
        let localYFromTop = panel.frame.maxY - point.y
        let centerY = SideNotchLayout.providerCenterYFromTop(
            index: ProviderID.allCases.count,
            providerCount: moduleCount,
            height: windowSize.height
        )
        let activationRadius = (SideNotchLayout.itemSize.height + SideNotchLayout.itemSpacing) / 2
        return abs(localYFromTop - centerY) <= activationRadius
    }

    private func screenContainingPanel() -> NSScreen? {
        let point = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        return screen(containing: point)
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func nearestScreen(to point: NSPoint) -> NSScreen? {
        NSScreen.screens.min { lhs, rhs in
            distanceSquared(from: point, to: lhs.frame) < distanceSquared(from: point, to: rhs.frame)
        }
    }

    private func distanceSquared(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(max(rect.minX - point.x, 0), point.x - rect.maxX)
        let dy = max(max(rect.minY - point.y, 0), point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
