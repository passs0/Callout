import AppKit
import SwiftUI

private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingPanelController: NSObject {
    private var panel: NonActivatingPanel?
    private var hostingView: NSHostingView<ActionMenuView>?
    private let state = PopoverState()
    private var lastAnchor: NSPoint = .zero

    override init() {
        super.init()
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
        state.onShowNativeMenu = { [weak self] in
            self?.showNativeContextMenu()
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
        // Account for 32pt transparent shadow padding around the glass surface
        var originY = lastAnchor.y - size.height + 24
        if originY < visibleFrame.minY - 16 {
            originY = lastAnchor.y - 12
        }

        originX = max(visibleFrame.minX - 24, min(originX, visibleFrame.maxX - size.width + 24))
        originY = max(visibleFrame.minY - 24, min(originY, visibleFrame.maxY - size.height + 24))

        panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
    }

    // MARK: - Native macOS Context Menu

    private func showNativeContextMenu() {
        guard let panel else { return }

        let menu = NSMenu(title: "Callout")
        let snippet = truncatedSnippet(state.selectedText)
        let searchEngineRaw = UserDefaults.standard.string(forKey: "searchEngine") ?? SearchEngine.google.rawValue
        let searchEngine = SearchEngine(rawValue: searchEngineRaw) ?? .google

        menu.addItem(makeMenuItem("Copy", symbol: "doc.on.doc", action: #selector(menuCopy)))
        menu.addItem(.separator())

        if detectedURL(in: state.selectedText) != nil {
            menu.addItem(makeMenuItem("Open Link", symbol: "safari", action: #selector(menuOpenLink)))
        }
        menu.addItem(makeMenuItem("Look Up “\(snippet)”", symbol: "info.circle", action: #selector(menuLookUp)))
        menu.addItem(makeMenuItem("Translate “\(snippet)”", symbol: "translate", action: #selector(menuTranslate)))
        menu.addItem(makeMenuItem("Find", symbol: "magnifyingglass", action: #selector(menuFind)))
        menu.addItem(makeMenuItem("Search with \(searchEngine.rawValue)", symbol: "magnifyingglass", action: #selector(menuSearchWeb)))

        menu.addItem(.separator())

        let speakTitle = SpeechManager.shared.isSpeaking ? "Stop Speaking" : "Speak"
        let speakSymbol = SpeechManager.shared.isSpeaking ? "stop.fill" : "play"
        menu.addItem(makeMenuItem(speakTitle, symbol: speakSymbol, action: #selector(menuSpeak)))
        menu.addItem(makeMenuItem("Spell", symbol: "play", action: #selector(menuSpell)))

        menu.addItem(.separator())

        menu.addItem(makeMenuItem("Copy Link with Highlight", symbol: "text.quote", action: #selector(menuCopyHighlight)))
        menu.addItem(makeMenuItem("Share...", symbol: "square.and.arrow.up", action: #selector(menuShare)))
        menu.addItem(makeMenuItem("Add to Quick Note", symbol: "note.text.badge.plus", action: #selector(menuQuickNote)))
        menu.addItem(makeMenuItem("Ask Siri", symbol: "siri", action: #selector(menuAskSiri)))

        let screenAnchor = NSPoint(x: panel.frame.midX - 110, y: panel.frame.maxY - 32)
        panel.orderOut(nil)
        menu.popUp(positioning: nil, at: screenAnchor, in: nil)
    }

    private func makeMenuItem(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    private func truncatedSnippet(_ text: String) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if cleaned.count <= 14 {
            return cleaned
        }
        return String(cleaned.prefix(14)) + "…"
    }

    private func detectedURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return detector.firstMatch(in: trimmed, range: range)?.url
    }

    @objc private func menuCopy() {
        TextActionRunner.copy(state.selectedText)
        dismiss()
    }

    @objc private func menuOpenLink() {
        if let url = detectedURL(in: state.selectedText) {
            NSWorkspace.shared.open(url)
        }
        dismiss()
    }

    @objc private func menuLookUp() {
        panel?.orderFrontRegardless()
        state.triggerLookUp()
    }

    @objc private func menuTranslate() {
        panel?.orderFrontRegardless()
        state.triggerTranslate()
    }

    @objc private func menuFind() {
        let text = state.selectedText
        dismiss()
        TextActionRunner.findInFrontmostApp(text)
    }

    @objc private func menuSearchWeb() {
        let raw = UserDefaults.standard.string(forKey: "searchEngine") ?? SearchEngine.google.rawValue
        let engine = SearchEngine(rawValue: raw) ?? .google
        TextActionRunner.searchWeb(state.selectedText, engine: engine)
        dismiss()
    }

    @objc private func menuSpeak() {
        SpeechManager.shared.toggleSpeak(state.selectedText)
    }

    @objc private func menuSpell() {
        SpeechManager.shared.spellOut(state.selectedText)
    }

    @objc private func menuCopyHighlight() {
        _ = TextActionRunner.copyLinkWithHighlight(
            state.selectedText,
            frontmostBundleID: state.frontmostBundleID
        )
        dismiss()
    }

    @objc private func menuShare() {
        guard let view = hostingView else { return }
        panel?.orderFrontRegardless()
        TextActionRunner.share(state.selectedText, from: view)
    }

    @objc private func menuQuickNote() {
        let text = state.selectedText
        dismiss()
        TextActionRunner.newQuickNote(text)
    }

    @objc private func menuAskSiri() {
        let text = state.selectedText
        dismiss()
        TextActionRunner.askSiri(text)
    }
}
