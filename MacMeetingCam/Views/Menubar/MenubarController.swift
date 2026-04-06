import AppKit
import SwiftUI

@MainActor
final class MenubarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Configure button
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "MacMeetingCam")
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: PopoverView(appState: appState))
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = buildContextMenu()
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // Reset so left-click works again
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Camera selection section
        // (placeholder -- will be populated from CaptureManager)
        menu.addItem(NSMenuItem(title: "No Camera Selected", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Effect toggles
        let bgItem = NSMenuItem(title: "Background Effect", action: #selector(toggleBackground), keyEquivalent: "")
        bgItem.target = self
        bgItem.state = appState.backgroundEffectEnabled ? .on : .off
        menu.addItem(bgItem)

        let freezeItem = NSMenuItem(title: "Freeze", action: #selector(toggleFreeze), keyEquivalent: "")
        freezeItem.target = self
        freezeItem.state = appState.pipelineMode == .frozen ? .on : .off
        menu.addItem(freezeItem)

        let loopItem = NSMenuItem(title: "Loop", action: #selector(toggleLoop), keyEquivalent: "")
        loopItem.target = self
        loopItem.state = appState.pipelineMode == .looping ? .on : .off
        menu.addItem(loopItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Action Handlers

    @objc private func toggleBackground() { appState.toggleBackgroundEffect() }
    @objc private func toggleFreeze() { appState.toggleFreeze() }
    @objc private func toggleLoop() { appState.toggleLoop() }
    @objc private func openSettings() { /* will be wired later */ }
    @objc private func quitApp() { NSApp.terminate(nil) }

    // MARK: - Icon Logic

    /// The SF Symbol name for the current state, used by `updateIcon()`.
    var iconSymbolName: String {
        switch appState.pipelineMode {
        case .live:
            return appState.backgroundEffectEnabled ? "video.fill.badge.checkmark" : "video.fill"
        case .frozen:
            return "pause.circle.fill"
        case .looping:
            return "arrow.2.squarepath"
        }
    }

    /// Update the menubar icon based on current state.
    func updateIcon() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: iconSymbolName, accessibilityDescription: "MacMeetingCam")
    }

    // MARK: - Test Helpers

    /// Exposes the context menu builder for testing.
    func testableContextMenu() -> NSMenu {
        return buildContextMenu()
    }
}
