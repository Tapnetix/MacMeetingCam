import XCTest
@testable import MacMeetingCam

@MainActor
final class SettingsViewTests: XCTestCase {

    var appState: AppState!

    override func setUp() {
        super.setUp()
        appState = AppState()
    }

    // MARK: - Tab Enum Tests

    func testSettingsViewHasAllTabs() {
        XCTAssertEqual(SettingsView.Tab.allCases.count, 5)
    }

    func testTabIdentifiers() {
        XCTAssertEqual(SettingsView.Tab.camera.rawValue, "Camera")
        XCTAssertEqual(SettingsView.Tab.background.rawValue, "Background")
        XCTAssertEqual(SettingsView.Tab.loop.rawValue, "Loop")
        XCTAssertEqual(SettingsView.Tab.hotkeys.rawValue, "Hotkeys")
        XCTAssertEqual(SettingsView.Tab.general.rawValue, "General")
    }

    func testTabIcons() {
        XCTAssertEqual(SettingsView.Tab.camera.icon, "video")
        XCTAssertEqual(SettingsView.Tab.background.icon, "photo")
        XCTAssertEqual(SettingsView.Tab.loop.icon, "arrow.2.squarepath")
        XCTAssertEqual(SettingsView.Tab.hotkeys.icon, "keyboard")
        XCTAssertEqual(SettingsView.Tab.general.icon, "gear")
    }

    func testTabIdMatchesRawValue() {
        for tab in SettingsView.Tab.allCases {
            XCTAssertEqual(tab.id, tab.rawValue)
        }
    }

    // MARK: - View Creation Smoke Tests

    func testSettingsViewCreation() {
        let view = SettingsView(appState: appState)
        XCTAssertNotNil(view)
    }

    func testCameraTabViewCreation() {
        let view = CameraTabView(appState: appState)
        XCTAssertNotNil(view)
    }

    func testBackgroundTabViewCreation() {
        let view = BackgroundTabView(appState: appState)
        XCTAssertNotNil(view)
    }

    func testLoopTabViewCreation() {
        let view = LoopTabView(appState: appState)
        XCTAssertNotNil(view)
    }

    func testHotkeysTabViewCreation() {
        let view = HotkeysTabView()
        XCTAssertNotNil(view)
    }

    func testGeneralTabViewCreation() {
        let view = GeneralTabView(appState: appState)
        XCTAssertNotNil(view)
    }

    // MARK: - HotkeyAction Display Names

    func testHotkeyActionDisplayNames() {
        XCTAssertEqual(HotkeyAction.toggleBackgroundEffect.displayName, "Toggle Background Effect")
        XCTAssertEqual(HotkeyAction.toggleFreeze.displayName, "Toggle Freeze")
        XCTAssertEqual(HotkeyAction.toggleLoop.displayName, "Toggle Loop")
        XCTAssertEqual(HotkeyAction.toggleCamera.displayName, "Camera On / Off")
    }

    // MARK: - Deferred Changes Integration

    func testDeferredChangesLabel() {
        appState.backgroundEffectEnabled = true
        appState.toggleFreeze()
        appState.blurIntensity = 0.5
        XCTAssertTrue(appState.hasDeferredChanges)
    }

    // MARK: - Memory Estimate Integration

    func testMemoryEstimateInLoopTab() {
        let estimate = MemoryEstimator.formattedEstimate(
            durationSeconds: appState.bufferDuration,
            width: 1920, height: 1080, fps: 30
        )
        XCTAssertFalse(estimate.isEmpty)
    }
}
