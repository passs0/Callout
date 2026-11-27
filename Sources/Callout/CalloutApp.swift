import AppKit
import SwiftUI

@main
@MainActor
final class CalloutApp: NSObject, NSApplicationDelegate {
    private let monitor = SelectionMonitor()
    private let panelController = FloatingPanelController()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var toggleMenuItem: NSMenuItem?
    private var permissionMenuItem: NSMenuItem?

    static func main() {
        let app = NSApplication.shared
        let delegate = CalloutApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        let autoShow = UserDefaults.standard.object(forKey: "autoShowEnabled") as? Bool ?? true
        monitor.setEnabled(autoShow)

        monitor.onSelectionDetected = { [weak self] event in
            self?.panelController.show(for: event)
        }
        monitor.onDismissRequested = { [weak self] in
            self?.panelController.dismiss()
        }
        monitor.isPanelVisible = { [weak self] in
            self?.panelController.isVisible == true
        }
        monitor.start()

        if !monitor.isAccessibilityGranted {
            openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "Callout")
        }

        let menu = NSMenu()

        let autoShow = UserDefaults.standard.object(forKey: "autoShowEnabled") as? Bool ?? true
        let toggleItem = NSMenuItem(
            title: "Auto-Show on Text Selection",
            action: #selector(toggleAutoShow),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = autoShow ? .on : .off
        toggleItem.image = NSImage(systemSymbolName: "cursorarrow.click", accessibilityDescription: nil)
        menu.addItem(toggleItem)
        self.toggleMenuItem = toggleItem

        let triggerItem = NSMenuItem(
            title: "Show Bar for Selection / Clipboard",
            action: #selector(triggerManual),
            keyEquivalent: ""
        )
        triggerItem.target = self
        triggerItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
        menu.addItem(triggerItem)

        menu.addItem(.separator())

        let permItem = NSMenuItem(
            title: permissionTitle(),
            action: #selector(handlePermissionClick),
            keyEquivalent: ""
        )
        permItem.target = self
        permItem.image = NSImage(
            systemSymbolName: monitor.isAccessibilityGranted ? "checkmark.shield" : "hand.raised",
            accessibilityDescription: nil
        )
        menu.addItem(permItem)
        self.permissionMenuItem = permItem

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Callout",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    private func permissionTitle() -> String {
        monitor.refreshAccessibilityStatus()
        return monitor.isAccessibilityGranted
            ? "Accessibility: Granted"
            : "Grant Accessibility Permission..."
    }

    @objc private func toggleAutoShow() {
        let current = UserDefaults.standard.object(forKey: "autoShowEnabled") as? Bool ?? true
        let next = !current
        UserDefaults.standard.set(next, forKey: "autoShowEnabled")
        monitor.setEnabled(next)
        toggleMenuItem?.state = next ? .on : .off
    }

    @objc private func triggerManual() {
        monitor.triggerManualSelectionAtCursor()
    }

    @objc private func handlePermissionClick() {
        monitor.refreshAccessibilityStatus()
        if !monitor.isAccessibilityGranted {
            monitor.requestAccessibilityPermission()
        } else {
            openSettings()
        }
        permissionMenuItem?.title = permissionTitle()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(monitor: monitor)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Callout Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
