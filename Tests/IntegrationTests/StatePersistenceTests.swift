import XCTest
@testable import MacMeetingCam

final class StatePersistenceTests: XCTestCase {

    @MainActor
    func testAllSettingsSurviveRestart() {
        let suiteName = "com.tapnetix.Tests.Persistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Write non-default values
        let store1 = SettingsStore(defaults: defaults)
        store1.blurIntensity = 0.42
        store1.edgeSoftness = 0.65
        store1.bufferDuration = 60.0
        store1.crossfadeDuration = 1.0
        store1.resumeTransition = 0.8
        store1.backgroundMode = .replace
        store1.backgroundEffectEnabled = true
        store1.bufferEnabled = false
        store1.launchAtLogin = false
        store1.showInMenubar = false
        store1.showInDock = true
        store1.autoCheckUpdates = false
        store1.segmentationQuality = .accurate
        store1.selectedCameraID = "test-cam-id"

        // Create new store (simulating restart)
        let store2 = SettingsStore(defaults: defaults)

        XCTAssertEqual(store2.blurIntensity, 0.42, accuracy: 0.001)
        XCTAssertEqual(store2.edgeSoftness, 0.65, accuracy: 0.001)
        XCTAssertEqual(store2.bufferDuration, 60.0, accuracy: 0.001)
        XCTAssertEqual(store2.crossfadeDuration, 1.0, accuracy: 0.001)
        XCTAssertEqual(store2.resumeTransition, 0.8, accuracy: 0.001)
        XCTAssertEqual(store2.backgroundMode, .replace)
        XCTAssertTrue(store2.backgroundEffectEnabled)
        XCTAssertFalse(store2.bufferEnabled)
        XCTAssertFalse(store2.launchAtLogin)
        XCTAssertFalse(store2.showInMenubar)
        XCTAssertTrue(store2.showInDock)
        XCTAssertFalse(store2.autoCheckUpdates)
        XCTAssertEqual(store2.segmentationQuality, .accurate)
        XCTAssertEqual(store2.selectedCameraID, "test-cam-id")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testAppStateLoadsFromSettingsStore() {
        let suiteName = "com.tapnetix.Tests.AppState.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)

        store.blurIntensity = 0.33
        store.backgroundMode = .remove
        store.segmentationQuality = .fast

        let appState = AppState(settingsStore: store)

        XCTAssertEqual(appState.blurIntensity, 0.33, accuracy: 0.001)
        XCTAssertEqual(appState.backgroundMode, .remove)
        XCTAssertEqual(appState.segmentationQuality, .fast)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
