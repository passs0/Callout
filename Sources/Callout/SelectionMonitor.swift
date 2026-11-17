import AppKit
import ApplicationServices

struct TextSelectionEvent: Equatable {
    let text: String
    let anchorPoint: NSPoint // AppKit screen coordinates (bottom-left origin)
    let selectionRect: NSRect? // AppKit screen coordinates if available
    let frontmostBundleID: String?
}

@MainActor
final class SelectionMonitor: ObservableObject {
    @Published var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    var onSelectionDetected: ((TextSelectionEvent) -> Void)?
    var onDismissRequested: (() -> Void)?

    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var keyDownMonitor: Any?
    private var scrollMonitor: Any?
    private var permissionTimer: Timer?

    private var mouseDownLocation: NSPoint?
    private var mouseDownDragChangeCount: Int = 0
    private var isEnabled: Bool = true
    private var pendingWorkItem: DispatchWorkItem?
    private var isReadingSelection = false

    func start() {
        refreshAccessibilityStatus()

        if !isAccessibilityGranted {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.refreshAccessibilityStatus()
                    if self.isAccessibilityGranted {
                        self.permissionTimer?.invalidate()
                        self.permissionTimer = nil
                    }
                }
            }
        }

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            let loc = NSEvent.mouseLocation
            let dragCount = NSPasteboard(name: .drag).changeCount
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.mouseDownLocation = loc
                self.mouseDownDragChangeCount = dragCount
                if !self.isClickInsideOurWindows(loc) {
                    self.onDismissRequested?()
                }
            }
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            let clickCount = event.clickCount
            let upLocation = NSEvent.mouseLocation
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let dragCount = NSPasteboard(name: .drag).changeCount
            Task { @MainActor [weak self] in
                guard let self, self.isEnabled else { return }
                if self.isClickInsideOurWindows(upLocation) { return }
                // Ignore drag-and-drop operations (files, images, links, etc.)
                if dragCount != self.mouseDownDragChangeCount { return }
                // Ignore if user is holding Cmd/Ctrl/Opt while clicking (e.g. Cmd+click link)
                if !modifiers.isDisjoint(with: [.command, .control, .option]) { return }

                let dragDistance: CGFloat
                if let down = self.mouseDownLocation {
                    dragDistance = hypot(upLocation.x - down.x, upLocation.y - down.y)
                } else {
                    dragDistance = 0
                }

                // Trigger on drag-select or double/triple-click word/line selection
                guard dragDistance > 6 || clickCount >= 2 else { return }

                let anchorFallback: NSPoint
                if dragDistance > 6, let down = self.mouseDownLocation {
                    anchorFallback = NSPoint(
                        x: (down.x + upLocation.x) / 2,
                        y: min(down.y, upLocation.y) - 4
                    )
                } else {
                    anchorFallback = NSPoint(x: upLocation.x, y: upLocation.y - 8)
                }

                self.scheduleSelectionRead(mouseLocation: anchorFallback)
            }
        }

        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onDismissRequested?()
            }
        }

        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if keyCode == 53 { // Escape
                    self.onDismissRequested?()
                    return
                }
                // Global shortcut: Option + Space (49) or Cmd + Shift + E (14)
                if (modifiers == .option && keyCode == 49) || (modifiers == [.command, .shift] && keyCode == 14) {
                    self.triggerManualSelectionAtCursor()
                }
            }
        }
    }

    func stop() {
        if let m = mouseDownMonitor { NSEvent.removeMonitor(m); mouseDownMonitor = nil }
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m); mouseUpMonitor = nil }
        if let m = keyDownMonitor { NSEvent.removeMonitor(m); keyDownMonitor = nil }
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        permissionTimer?.invalidate()
        permissionTimer = nil
        pendingWorkItem?.cancel()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            onDismissRequested?()
        }
    }

    func refreshAccessibilityStatus() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshAccessibilityStatus()
        }
    }

    func triggerManualSelectionAtCursor() {
        let mouseLocation = NSEvent.mouseLocation
        readSelectionWithFallback(mouseLocation: mouseLocation, allowClipboardFallback: true)
    }

    private func scheduleSelectionRead(mouseLocation: NSPoint) {
        pendingWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.refreshAccessibilityStatus()
            guard self.isAccessibilityGranted else { return }
            self.readSelectionWithFallback(mouseLocation: mouseLocation, allowClipboardFallback: false)
        }
        pendingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: item)
    }

    private func readSelectionWithFallback(mouseLocation: NSPoint, allowClipboardFallback: Bool) {
        guard !isReadingSelection else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        // 1. Try Accessibility API first (instant, no pasteboard touch)
        if isAccessibilityGranted, let axEvent = readFrontmostAXSelection(frontApp: frontApp, fallbackPoint: mouseLocation) {
            onSelectionDetected?(axEvent)
            return
        }

        // 2. Fallback: simulate Cmd+C and restore pasteboard (only if Copy is actually enabled in frontmost app!)
        if isAccessibilityGranted && isCopyEnabled(for: frontApp) {
            isReadingSelection = true
            readSelectionViaCopyFallback(frontApp: frontApp, mouseLocation: mouseLocation) { [weak self] copiedEvent in
                guard let self else { return }
                self.isReadingSelection = false
                if let copiedEvent {
                    self.onSelectionDetected?(copiedEvent)
                } else if allowClipboardFallback,
                          let existing = NSPasteboard.general.string(forType: .string),
                          !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.onSelectionDetected?(TextSelectionEvent(
                        text: existing,
                        anchorPoint: mouseLocation,
                        selectionRect: nil,
                        frontmostBundleID: frontApp.bundleIdentifier
                    ))
                }
            }
        } else if allowClipboardFallback,
                  let existing = NSPasteboard.general.string(forType: .string),
                  !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onSelectionDetected?(TextSelectionEvent(
                text: existing,
                anchorPoint: mouseLocation,
                selectionRect: nil,
                frontmostBundleID: frontApp.bundleIdentifier
            ))
        }
    }

    private func isClickInsideOurWindows(_ point: NSPoint) -> Bool {
        for window in NSApp.windows where window.isVisible {
            if window.frame.contains(point) {
                return true
            }
        }
        return false
    }

    private func readFrontmostAXSelection(frontApp: NSRunningApplication, fallbackPoint: NSPoint) -> TextSelectionEvent? {
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Enable accessibility tree in Chromium / Electron / Safari web views
        AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)

        // Try focused element first
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
           let focusedElement = focusedRef {
            let axElement = focusedElement as! AXUIElement
            if let event = extractSelectedText(from: axElement, bundleID: frontApp.bundleIdentifier, fallbackPoint: fallbackPoint) {
                return event
            }
        }

        // Try element at mouse position
        if let primaryHeight = NSScreen.screens.first?.frame.height {
            let axX = Float(fallbackPoint.x)
            let axY = Float(primaryHeight - fallbackPoint.y)
            var hitRef: AXUIElement?
            if AXUIElementCopyElementAtPosition(appElement, axX, axY, &hitRef) == .success,
               let hitElement = hitRef {
                if let event = extractSelectedText(from: hitElement, bundleID: frontApp.bundleIdentifier, fallbackPoint: fallbackPoint) {
                    return event
                }
            }
        }

        return nil
    }

    private func extractSelectedText(from element: AXUIElement, bundleID: String?, fallbackPoint: NSPoint) -> TextSelectionEvent? {
        var selectedTextRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextRef) == .success,
              let selectedText = selectedTextRef as? String else {
            return nil
        }

        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let rect = readSelectionBounds(from: element)
        let anchor = rect.map { NSPoint(x: $0.midX, y: $0.minY) } ?? fallbackPoint

        return TextSelectionEvent(
            text: selectedText,
            anchorPoint: anchor,
            selectionRect: rect,
            frontmostBundleID: bundleID
        )
    }

    private func readSelectionBounds(from element: AXUIElement) -> NSRect? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef else {
            return nil
        }

        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsRef
        ) == .success, let boundsValue = boundsRef else {
            return nil
        }

        var axRect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &axRect),
              axRect.width > 0 || axRect.height > 0 else {
            return nil
        }

        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        let appKitY = primaryHeight - axRect.origin.y - axRect.size.height
        return NSRect(x: axRect.origin.x, y: appKitY, width: axRect.size.width, height: axRect.size.height)
    }

    private func isCopyEnabled(for frontApp: NSRunningApplication) -> Bool {
        // Never send Cmd+C fallback in Finder (avoids copying files or beeping on file drag-and-drop)
        if frontApp.bundleIdentifier == "com.apple.finder" {
            return false
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef else {
            return false
        }

        var topItemsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &topItemsRef) == .success,
              let topItems = topItemsRef as? [AXUIElement] else {
            return false
        }

        for topItem in topItems {
            var subMenusRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(topItem, kAXChildrenAttribute as CFString, &subMenusRef) == .success,
                  let subMenus = subMenusRef as? [AXUIElement] else {
                continue
            }
            for subMenu in subMenus {
                var itemsRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &itemsRef) == .success,
                      let items = itemsRef as? [AXUIElement] else {
                    continue
                }
                for item in items {
                    var cmdCharRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef) == .success,
                       let cmdChar = cmdCharRef as? String,
                       cmdChar.uppercased() == "C" {
                        var modifiersRef: CFTypeRef?
                        let hasOnlyCmd: Bool
                        if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdModifiersAttribute as CFString, &modifiersRef) == .success,
                           let mod = modifiersRef as? Int {
                            hasOnlyCmd = (mod == 0) // 0 = Command only in AXMenuItemCmdModifiers
                        } else {
                            hasOnlyCmd = true
                        }
                        if hasOnlyCmd {
                            var enabledRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(item, kAXEnabledAttribute as CFString, &enabledRef) == .success,
                               let enabled = enabledRef as? Bool {
                                return enabled
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    private func readSelectionViaCopyFallback(
        frontApp: NSRunningApplication,
        mouseLocation: NSPoint,
        completion: @escaping (TextSelectionEvent?) -> Void
    ) {
        let pb = NSPasteboard.general
        let previousChangeCount = pb.changeCount
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = (pb.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }

        // Send Cmd+C (virtualKey 8 = 'c')
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else {
            completion(nil)
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let newChangeCount = pb.changeCount
            guard newChangeCount != previousChangeCount,
                  let copiedText = pb.string(forType: .string),
                  !copiedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                completion(nil)
                return
            }

            // Restore previous pasteboard contents
            pb.clearContents()
            if !savedItems.isEmpty {
                let restored: [NSPasteboardItem] = savedItems.map { dict in
                    let item = NSPasteboardItem()
                    for (type, data) in dict {
                        item.setData(data, forType: type)
                    }
                    return item
                }
                pb.writeObjects(restored)
            }

            completion(TextSelectionEvent(
                text: copiedText,
                anchorPoint: mouseLocation,
                selectionRect: nil,
                frontmostBundleID: frontApp.bundleIdentifier
            ))
        }
    }
}
