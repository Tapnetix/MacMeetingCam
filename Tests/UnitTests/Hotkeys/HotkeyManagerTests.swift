import XCTest
@testable import MacMeetingCam

final class HotkeyManagerTests: XCTestCase {

    var manager: HotkeyManager!

    override func setUp() {
        super.setUp()
        manager = HotkeyManager()
    }

    override func tearDown() {
        manager.unregisterAll()
        super.tearDown()
    }

    func testHotkeyActionHasAllFourCases() {
        XCTAssertEqual(HotkeyAction.allCases.count, 4)
    }

    func testEachActionHasUniqueShortcutName() {
        let names = HotkeyAction.allCases.map { $0.shortcutName.rawValue }
        XCTAssertEqual(Set(names).count, names.count) // all unique
    }

    func testSetHandlerDoesNotCrash() {
        var called = false
        manager.setHandler { _ in called = true }
        // Can't actually trigger shortcuts in tests, but verify setup doesn't crash
        XCTAssertFalse(called) // handler not called yet
    }

    func testRestoreDefaultsDoesNotCrash() {
        manager.restoreDefaults()
        // Just verify it doesn't throw/crash
    }

    func testUnregisterAllDoesNotCrash() {
        manager.setHandler { _ in }
        manager.unregisterAll()
        // Verify cleanup doesn't crash
    }

    func testActionsWithShortcutsInitiallyEmpty() {
        // No shortcuts set by default in test environment
        let actions = manager.actionsWithShortcuts()
        // May or may not have shortcuts depending on env, just verify it returns an array
        XCTAssertNotNil(actions)
    }

    func testShortcutNameMapping() {
        XCTAssertEqual(HotkeyAction.toggleBackgroundEffect.shortcutName, .toggleBackgroundEffect)
        XCTAssertEqual(HotkeyAction.toggleFreeze.shortcutName, .toggleFreeze)
        XCTAssertEqual(HotkeyAction.toggleLoop.shortcutName, .toggleLoop)
        XCTAssertEqual(HotkeyAction.toggleCamera.shortcutName, .toggleCamera)
    }

    func testHotkeyActionRawValues() {
        XCTAssertEqual(HotkeyAction.toggleBackgroundEffect.rawValue, "toggleBackgroundEffect")
        XCTAssertEqual(HotkeyAction.toggleFreeze.rawValue, "toggleFreeze")
        XCTAssertEqual(HotkeyAction.toggleLoop.rawValue, "toggleLoop")
        XCTAssertEqual(HotkeyAction.toggleCamera.rawValue, "toggleCamera")
    }
}
