import AppKit
import SwiftUI

private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingPanelController: NSObject {
    private var panel: NonActivatingPanel?
    private var hostingView: NSHostingView<ActionMenuView>?
    private let state = PopoverState()
    private var lastAnchor: NSPoint = .zero
    private var lastSelectionCenter: NSPoint = .zero

    var isVisible: Bool { panel?.isVisible == true }

    override init() {
        super.init()
        state.onRequestResize = { [weak self] in
            DispatchQueue.main.async {
                self?.resizePanelKeepingAnchor()
            }
        }
        state.onDismiss = { [weak self] in
            self?.dismiss(immediate: true)
        }
        state.onShowNativeMenu = { [weak self] in
            self?.showNativeContextMenu()
        }
    }

    func show(for event: TextSelectionEvent) {
        state.reset(text: event.text, bundleID: event.frontmostBundleID)
        lastAnchor = event.anchorPoint
        if let rect = event.selectionRect {
            lastSelectionCenter = NSPoint(x: rect.midX, y: rect.midY)
        } else {
            lastSelectionCenter = NSPoint(x: event.anchorPoint.x, y: event.anchorPoint.y + 10)
        }

        if panel == nil {
            createPanel()
        }

        resizePanelKeepingAnchor(initialShow: true)
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().alphaValue = 1
        }
    }

    func updatePosition(anchor: NSPoint, selectionRect: NSRect?) {
        guard let panel, panel.isVisible else { return }
        lastAnchor = anchor
        if let rect = selectionRect {
            lastSelectionCenter = NSPoint(x: rect.midX, y: rect.midY)
        } else {
            lastSelectionCenter = NSPoint(x: anchor.x, y: anchor.y + 10)
        }
        resizePanelKeepingAnchor()
    }

    func dismiss(immediate: Bool = false) {
        guard let panel, panel.isVisible else { return }
        if immediate {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
            }
        })
    }

    private func createPanel() {
        let contentView = ActionMenuView(state: state)
        let hosting = NSHostingView(rootView: contentView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        let panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentView = hosting

        self.hostingView = hosting
        self.panel = panel
    }

    private func resizePanelKeepingAnchor(initialShow: Bool = false) {
        guard let panel, let hosting = hostingView else { return }
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let screen = NSScreen.screens.first(where: { $0.frame.contains(lastAnchor) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var originX = lastAnchor.x - size.width / 2
        // Account for 32pt transparent shadow padding around the glass surface
        var originY = lastAnchor.y - size.height + 24
        if originY < visibleFrame.minY - 16 {
            originY = lastAnchor.y - 12
        }

        originX = max(visibleFrame.minX - 24, min(originX, visibleFrame.maxX - size.width + 24))
        originY = max(visibleFrame.minY - 24, min(originY, visibleFrame.maxY - size.height + 24))

        panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
    }

    // MARK: - Native App Context Menu (Right-Click)

    private func showNativeContextMenu() {
        panel?.orderOut(nil)

        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        let cgPoint = CGPoint(x: lastSelectionCenter.x, y: primaryHeight - lastSelectionCenter.y)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            guard let source = CGEventSource(stateID: .hidSystemState),
                  let rightDown = CGEvent(mouseEventSource: source, mouseType: .rightMouseDown, mouseCursorPosition: cgPoint, mouseButton: .right),
                  let rightUp = CGEvent(mouseEventSource: source, mouseType: .rightMouseUp, mouseCursorPosition: cgPoint, mouseButton: .right) else {
                return
            }
            rightDown.post(tap: .cghidEventTap)
            rightUp.post(tap: .cghidEventTap)
        }
    }
}
