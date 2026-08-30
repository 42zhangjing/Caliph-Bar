import AppKit
import SwiftUI
import Combine
import QuartzCore
import CaliphBarCore

@MainActor
final class FloatingPillWindow {
    private let panel: NSPanel
    private let hosting: NSHostingController<FloatingPillView>
    private let position: PillPositionModel
    private var moveObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var snapWorkItem: DispatchWorkItem?
    private var isProgrammaticMove = false
    private var selectionCancellable: AnyCancellable?

    var onProviderTapped: ((ProviderID, NSView, EdgeSide) -> Void)?

    private enum Keys {
        static let origin = "caliphbar.pillOrigin"
        static let side = "caliphbar.pillSide"
    }

    init(store: UsageStore, selection: SelectionModel) {
        let storedSide = UserDefaults.standard.string(forKey: Keys.side).flatMap(EdgeSide.init(rawValue:)) ?? .right
        position = PillPositionModel(side: storedSide)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 82, height: 235),
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
        panel.isMovableByWindowBackground = true

        hosting = NSHostingController(rootView: FloatingPillView(store: store, selection: selection, position: position))
        hosting.sizingOptions = [.preferredContentSize]
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear
        panel.contentViewController = hosting

        selectionCancellable = selection.$selected.dropFirst().sink { [weak self] provider in
            guard let self, let view = self.panel.contentView else { return }
            self.onProviderTapped?(provider, view, self.position.side)
        }

        installObservers()
    }

    deinit {
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    var side: EdgeSide { position.side }
    var isVisible: Bool { panel.isVisible }

    func show() {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        var size = hosting.view.fittingSize
        if size.width < 1 || size.height < 1 { size = NSSize(width: 82, height: 235) }
        panel.setContentSize(size)
        restoreOrDefaultPosition()
        panel.alphaValue = 1
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func installObservers() {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleSnap() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.snapToNearestEdge(animated: false) }
        }
    }

    private func scheduleSnap() {
        guard !isProgrammaticMove else { return }
        snapWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.snapToNearestEdge(animated: true) }
        }
        snapWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func restoreOrDefaultPosition() {
        if let saved = UserDefaults.standard.string(forKey: Keys.origin) {
            let origin = NSPointFromString(saved)
            panel.setFrameOrigin(origin)
            snapToNearestEdge(animated: false)
            return
        }
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(x: frame.maxX - panel.frame.width - 3, y: frame.midY - panel.frame.height / 2)
        panel.setFrameOrigin(origin)
        snapToNearestEdge(animated: false)
    }

    private func snapToNearestEdge(animated: Bool) {
        guard let screen = screenContainingPanel() ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let centerX = panel.frame.midX
        let chosen: EdgeSide = abs(centerX - visible.minX) < abs(visible.maxX - centerX) ? .left : .right
        position.side = chosen

        let x = chosen == .left ? visible.minX + 3 : visible.maxX - panel.frame.width - 3
        let y = min(max(panel.frame.origin.y, visible.minY + 6), visible.maxY - panel.frame.height - 6)
        let target = NSPoint(x: x, y: y)

        isProgrammaticMove = true
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrameOrigin(target)
            } completionHandler: { [weak self] in
                Task { @MainActor in self?.finishProgrammaticMove(target) }
            }
        } else {
            panel.setFrameOrigin(target)
            finishProgrammaticMove(target)
        }
    }

    private func finishProgrammaticMove(_ origin: NSPoint) {
        isProgrammaticMove = false
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: Keys.origin)
        UserDefaults.standard.set(position.side.rawValue, forKey: Keys.side)
    }

    private func screenContainingPanel() -> NSScreen? {
        let point = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        return NSScreen.screens.first { $0.frame.contains(point) }
    }
}
