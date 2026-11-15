import AppKit
import SwiftUI

private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingPanelController {
    private var panel: NonActivatingPanel?
    private var hostingView: NSHostingView<ActionMenuView>?
    private let state = PopoverState()
    private var lastAnchor: NSPoint = .zero

    init() {
        state.onRequestResize = { [weak self] in
            DispatchQueue.main.async {
                self?.resizePanelKeepingAnchor()
            }
        }
        state.onDismiss = { [weak self] in
            self?.dismiss()
        }
        state.onShareRequested = { [weak self] text in
            guard let self, let view = self.hostingView else { return }
            TextActionRunner.share(text, from: view)
        }
    }

    func show(for event: TextSelectionEvent) {
        SpeechManager.shared.stop()
        state.reset(text: event.text, bundleID: event.frontmostBundleID)
        lastAnchor = event.anchorPoint

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

    func dismiss() {
        guard let panel, panel.isVisible else { return }
        SpeechManager.shared.stop()
        panel.orderOut(nil)
    }

    private func createPanel() {
        let contentView = ActionMenuView(state: state)
        let hosting = NSHostingView(rootView: contentView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
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
        // Place below the selection/cursor by default; flip above if too close to bottom
        var originY = lastAnchor.y - size.height - 10
        if originY < visibleFrame.minY + 8 {
            originY = lastAnchor.y + 18
        }

        // Clamp horizontally & vertically to screen visibleFrame
        originX = max(visibleFrame.minX + 8, min(originX, visibleFrame.maxX - size.width - 8))
        originY = max(visibleFrame.minY + 8, min(originY, visibleFrame.maxY - size.height - 8))

        let newFrame = NSRect(x: originX, y: originY, width: size.width, height: size.height)
        if initialShow {
            panel.setFrame(newFrame, display: true)
        } else {
            panel.setFrame(newFrame, display: true, animate: true)
        }
    }
}
