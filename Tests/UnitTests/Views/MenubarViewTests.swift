import XCTest
@testable import MacMeetingCam

@MainActor
final class MenubarViewTests: XCTestCase {

    var appState: AppState!

    override func setUp() {
        super.setUp()
        appState = AppState()
    }

    // MARK: - PopoverView Tests

    func testPopoverViewCreation() {
        let view = PopoverView(appState: appState)
        XCTAssertNotNil(view)
    }

    func testQuickToggleButtonCreation() {
        let button = QuickToggleButton(label: "Test", icon: "star", isActive: false, action: {})
        XCTAssertNotNil(button)
    }

    // MARK: - MenubarController Tests

    func testMenubarControllerCreation() {
        let controller = MenubarController(appState: appState)
        XCTAssertNotNil(controller)
    }

    // MARK: - Icon State Logic

    func testMenubarControllerIconNameLive() {
        // Live with no background effect -> "video.fill"
        XCTAssertEqual(appState.pipelineMode, .live)
        XCTAssertFalse(appState.backgroundEffectEnabled)

        let controller = MenubarController(appState: appState)
        XCTAssertEqual(controller.iconSymbolName, "video.fill")
    }

    func testMenubarControllerIconNameLiveWithBackground() {
        appState.backgroundEffectEnabled = true
        let controller = MenubarController(appState: appState)
        XCTAssertEqual(controller.iconSymbolName, "video.fill.badge.checkmark")
    }

    func testMenubarControllerIconNameFrozen() {
        appState.toggleFreeze()
        XCTAssertEqual(appState.pipelineMode, .frozen)

        let controller = MenubarController(appState: appState)
        XCTAssertEqual(controller.iconSymbolName, "pause.circle.fill")
    }

    func testMenubarControllerIconNameLooping() {
        appState.toggleLoop()
        XCTAssertEqual(appState.pipelineMode, .looping)

        let controller = MenubarController(appState: appState)
        XCTAssertEqual(controller.iconSymbolName, "arrow.2.squarepath")
    }

    // MARK: - PopoverView Status Logic

    func testPopoverStatusTextLive() {
        let view = PopoverView(appState: appState)
        XCTAssertEqual(view.testableStatusText, "Live")
    }

    func testPopoverStatusTextLiveWithBackground() {
        appState.backgroundEffectEnabled = true
        let view = PopoverView(appState: appState)
        XCTAssertEqual(view.testableStatusText, "Live \u{2014} Background Effect Active")
    }

    func testPopoverStatusTextFrozen() {
        appState.toggleFreeze()
        let view = PopoverView(appState: appState)
        XCTAssertEqual(view.testableStatusText, "Frozen")
    }

    func testPopoverStatusTextLooping() {
        appState.toggleLoop()
        let view = PopoverView(appState: appState)
        XCTAssertEqual(view.testableStatusText, "Looping")
    }

    func testPopoverStatusColorLive() {
        let view = PopoverView(appState: appState)
        XCTAssertEqual(view.testableStatusColor, .green)
    }

    func testPopoverStatusColorFrozen() {
        appState.toggleFreeze()
        let view = PopoverView(appState: appState)
        XCTAssertEqual(view.testableStatusColor, .yellow)
    }

    func testPopoverStatusColorLooping() {
        appState.toggleLoop()
        let view = PopoverView(appState: appState)
        XCTAssertEqual(view.testableStatusColor, .red)
    }

    // MARK: - Context Menu Item Count

    func testContextMenuItemCount() {
        let controller = MenubarController(appState: appState)
        let menu = controller.testableContextMenu()
        // Expected items: "No Camera Selected", separator, "Background Effect",
        // "Freeze", "Loop", separator, "Settings...", separator, "Quit"
        XCTAssertEqual(menu.items.count, 9)
    }

    func testContextMenuBackgroundEffectState() {
        appState.backgroundEffectEnabled = true
        let controller = MenubarController(appState: appState)
        let menu = controller.testableContextMenu()
        // "Background Effect" is at index 2 (after "No Camera Selected" and separator)
        let bgItem = menu.items[2]
        XCTAssertEqual(bgItem.title, "Background Effect")
        XCTAssertEqual(bgItem.state, .on)
    }

    func testContextMenuFreezeState() {
        appState.toggleFreeze()
        let controller = MenubarController(appState: appState)
        let menu = controller.testableContextMenu()
        // "Freeze" is at index 3
        let freezeItem = menu.items[3]
        XCTAssertEqual(freezeItem.title, "Freeze")
        XCTAssertEqual(freezeItem.state, .on)
    }

    func testContextMenuLoopState() {
        appState.toggleLoop()
        let controller = MenubarController(appState: appState)
        let menu = controller.testableContextMenu()
        // "Loop" is at index 4
        let loopItem = menu.items[4]
        XCTAssertEqual(loopItem.title, "Loop")
        XCTAssertEqual(loopItem.state, .on)
    }

    func testContextMenuQuitItemExists() {
        let controller = MenubarController(appState: appState)
        let menu = controller.testableContextMenu()
        let quitItem = menu.items.last
        XCTAssertEqual(quitItem?.title, "Quit")
        XCTAssertEqual(quitItem?.keyEquivalent, "q")
    }

    func testContextMenuSettingsItemExists() {
        let controller = MenubarController(appState: appState)
        let menu = controller.testableContextMenu()
        // "Settings..." is at index 6 (after Loop, separator)
        let settingsItem = menu.items[6]
        XCTAssertEqual(settingsItem.title, "Settings...")
        XCTAssertEqual(settingsItem.keyEquivalent, ",")
    }
}
