import XCTest
@testable import MacMeetingCam

final class SettingsStoreTests: XCTestCase {

    private func makeStore() -> (SettingsStore, UserDefaults, String) {
        let suiteName = "test.settingsstore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)
        return (store, defaults, suiteName)
    }

    private func cleanup(_ defaults: UserDefaults, suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Default Values

    func testDefaultBlurIntensity() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertEqual(store.blurIntensity, AppConstants.Defaults.blurIntensity)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultEdgeSoftness() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertEqual(store.edgeSoftness, AppConstants.Defaults.edgeSoftness)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultBufferDuration() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertEqual(store.bufferDuration, AppConstants.Defaults.bufferDuration)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultCrossfadeDuration() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertEqual(store.crossfadeDuration, AppConstants.Defaults.crossfadeDuration)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultResumeTransition() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertEqual(store.resumeTransition, AppConstants.Defaults.resumeTransition)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultBackgroundMode() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertEqual(store.backgroundMode, .blur)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultBackgroundEffectEnabled() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertFalse(store.backgroundEffectEnabled)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultBufferEnabled() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertTrue(store.bufferEnabled)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultLaunchAtLogin() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertTrue(store.launchAtLogin)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultShowInMenubar() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertTrue(store.showInMenubar)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultShowInDock() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertFalse(store.showInDock)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultAutoCheckUpdates() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertTrue(store.autoCheckUpdates)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultSegmentationQuality() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertEqual(store.segmentationQuality, .balanced)
        cleanup(defaults, suiteName: suiteName)
    }

    func testDefaultSelectedCameraID() {
        let (store, defaults, suiteName) = makeStore()
        XCTAssertNil(store.selectedCameraID)
        cleanup(defaults, suiteName: suiteName)
    }

    // MARK: - Persistence Round-trips

    func testPersistsBlurIntensity() {
        let suiteName = "test.persist.blur.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.blurIntensity = 0.42
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.blurIntensity, 0.42, accuracy: 0.001)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsEdgeSoftness() {
        let suiteName = "test.persist.edge.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.edgeSoftness = 0.65
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.edgeSoftness, 0.65, accuracy: 0.001)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsBufferDuration() {
        let suiteName = "test.persist.buffer.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.bufferDuration = 60.0
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.bufferDuration, 60.0, accuracy: 0.001)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsCrossfadeDuration() {
        let suiteName = "test.persist.crossfade.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.crossfadeDuration = 1.0
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.crossfadeDuration, 1.0, accuracy: 0.001)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsResumeTransition() {
        let suiteName = "test.persist.resume.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.resumeTransition = 0.7
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.resumeTransition, 0.7, accuracy: 0.001)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsBackgroundMode() {
        let suiteName = "test.persist.bgmode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.backgroundMode = .remove
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.backgroundMode, .remove)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsBackgroundEffectEnabled() {
        let suiteName = "test.persist.bgeffect.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.backgroundEffectEnabled = true
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertTrue(store2.backgroundEffectEnabled)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsBufferEnabled() {
        let suiteName = "test.persist.bufenabled.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.bufferEnabled = false
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertFalse(store2.bufferEnabled)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsLaunchAtLogin() {
        let suiteName = "test.persist.launch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.launchAtLogin = false
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertFalse(store2.launchAtLogin)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsShowInMenubar() {
        let suiteName = "test.persist.menubar.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.showInMenubar = false
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertFalse(store2.showInMenubar)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsShowInDock() {
        let suiteName = "test.persist.dock.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.showInDock = true
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertTrue(store2.showInDock)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsAutoCheckUpdates() {
        let suiteName = "test.persist.updates.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.autoCheckUpdates = false
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertFalse(store2.autoCheckUpdates)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsSegmentationQuality() {
        let suiteName = "test.persist.segquality.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.segmentationQuality = .accurate
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.segmentationQuality, .accurate)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsSelectedCameraID() {
        let suiteName = "test.persist.camera.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = SettingsStore(defaults: defaults)
        store1.selectedCameraID = "com.apple.avfoundation.avcapturedevice.built-in_video:0"
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.selectedCameraID, "com.apple.avfoundation.avcapturedevice.built-in_video:0")
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Clamping Tests

    func testClampsBlurIntensityTo0_1() {
        let (store, defaults, suiteName) = makeStore()

        store.blurIntensity = -0.5
        XCTAssertEqual(store.blurIntensity, 0.0, accuracy: 0.001)

        store.blurIntensity = 1.5
        XCTAssertEqual(store.blurIntensity, 1.0, accuracy: 0.001)

        store.blurIntensity = 0.5
        XCTAssertEqual(store.blurIntensity, 0.5, accuracy: 0.001)

        cleanup(defaults, suiteName: suiteName)
    }

    func testClampsEdgeSoftnessTo0_1() {
        let (store, defaults, suiteName) = makeStore()

        store.edgeSoftness = -0.1
        XCTAssertEqual(store.edgeSoftness, 0.0, accuracy: 0.001)

        store.edgeSoftness = 2.0
        XCTAssertEqual(store.edgeSoftness, 1.0, accuracy: 0.001)

        cleanup(defaults, suiteName: suiteName)
    }

    func testClampsBufferDurationToMax() {
        let (store, defaults, suiteName) = makeStore()
        store.bufferDuration = 999.0
        XCTAssertEqual(store.bufferDuration, AppConstants.Defaults.maxBufferDuration, accuracy: 0.001)
        cleanup(defaults, suiteName: suiteName)
    }

    func testClampsBufferDurationToMin() {
        let (store, defaults, suiteName) = makeStore()
        store.bufferDuration = 0.5
        XCTAssertEqual(store.bufferDuration, AppConstants.Defaults.minBufferDuration, accuracy: 0.001)
        cleanup(defaults, suiteName: suiteName)
    }

    func testClampsCrossfadeDurationToMax() {
        let (store, defaults, suiteName) = makeStore()
        store.crossfadeDuration = 99.0
        XCTAssertEqual(store.crossfadeDuration, AppConstants.Defaults.maxCrossfadeDuration, accuracy: 0.001)
        cleanup(defaults, suiteName: suiteName)
    }

    func testClampsCrossfadeDurationToMin() {
        let (store, defaults, suiteName) = makeStore()
        store.crossfadeDuration = 0.01
        XCTAssertEqual(store.crossfadeDuration, AppConstants.Defaults.minCrossfadeDuration, accuracy: 0.001)
        cleanup(defaults, suiteName: suiteName)
    }

    func testClampsResumeTransitionToMax() {
        let (store, defaults, suiteName) = makeStore()
        store.resumeTransition = 99.0
        XCTAssertEqual(store.resumeTransition, AppConstants.Defaults.maxResumeTransition, accuracy: 0.001)
        cleanup(defaults, suiteName: suiteName)
    }

    func testClampsResumeTransitionToMin() {
        let (store, defaults, suiteName) = makeStore()
        store.resumeTransition = 0.001
        XCTAssertEqual(store.resumeTransition, AppConstants.Defaults.minResumeTransition, accuracy: 0.001)
        cleanup(defaults, suiteName: suiteName)
    }
}
