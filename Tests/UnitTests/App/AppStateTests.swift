import XCTest
@testable import MacMeetingCam

@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateIsLive() {
        let state = AppState()
        XCTAssertEqual(state.pipelineMode, .live)
    }

    func testInitialBackgroundEffectIsOff() {
        let state = AppState()
        XCTAssertFalse(state.backgroundEffectEnabled)
    }

    func testInitialBackgroundModeIsBlur() {
        let state = AppState()
        XCTAssertEqual(state.backgroundMode, .blur)
    }

    func testDefaultSliderValues() {
        let state = AppState()
        XCTAssertEqual(state.blurIntensity, AppConstants.Defaults.blurIntensity)
        XCTAssertEqual(state.edgeSoftness, AppConstants.Defaults.edgeSoftness)
        XCTAssertEqual(state.bufferDuration, AppConstants.Defaults.bufferDuration)
        XCTAssertEqual(state.crossfadeDuration, AppConstants.Defaults.crossfadeDuration)
        XCTAssertEqual(state.resumeTransition, AppConstants.Defaults.resumeTransition)
        XCTAssertTrue(state.bufferEnabled)
        XCTAssertEqual(state.selectedResolution, "1920x1080")
        XCTAssertEqual(state.selectedFramerate, AppConstants.Defaults.targetFramerate)
        XCTAssertEqual(state.segmentationQuality, .balanced)
        XCTAssertTrue(state.launchAtLogin)
        XCTAssertTrue(state.showInMenubar)
        XCTAssertFalse(state.showInDock)
        XCTAssertTrue(state.autoCheckUpdates)
    }

    // MARK: - Pipeline Mode Transitions

    func testTransitionLiveToFrozen() {
        let state = AppState()
        state.toggleFreeze()
        XCTAssertEqual(state.pipelineMode, .frozen)
    }

    func testTransitionFrozenToLive() {
        let state = AppState()
        state.toggleFreeze() // live -> frozen
        state.toggleFreeze() // frozen -> live
        XCTAssertEqual(state.pipelineMode, .live)
    }

    func testTransitionLiveToLooping() {
        let state = AppState()
        state.toggleLoop()
        XCTAssertEqual(state.pipelineMode, .looping)
    }

    func testTransitionLoopingToLive() {
        let state = AppState()
        state.toggleLoop()  // live -> looping
        state.toggleLoop()  // looping -> live
        XCTAssertEqual(state.pipelineMode, .live)
    }

    func testTransitionFrozenToLooping() {
        let state = AppState()
        state.toggleFreeze() // live -> frozen
        state.toggleLoop()   // frozen -> looping
        XCTAssertEqual(state.pipelineMode, .looping)
    }

    func testTransitionLoopingToFrozen() {
        let state = AppState()
        state.toggleLoop()   // live -> looping
        state.toggleFreeze() // looping -> frozen
        XCTAssertEqual(state.pipelineMode, .frozen)
    }

    // MARK: - Background Effect

    func testToggleBackgroundEffect() {
        let state = AppState()
        XCTAssertFalse(state.backgroundEffectEnabled)
        state.toggleBackgroundEffect()
        XCTAssertTrue(state.backgroundEffectEnabled)
        state.toggleBackgroundEffect()
        XCTAssertFalse(state.backgroundEffectEnabled)
    }

    func testSetBackgroundMode() {
        let state = AppState()
        state.backgroundMode = .remove
        XCTAssertEqual(state.backgroundMode, .remove)
        state.backgroundMode = .replace
        XCTAssertEqual(state.backgroundMode, .replace)
        state.backgroundMode = .blur
        XCTAssertEqual(state.backgroundMode, .blur)
    }

    func testBackgroundEffectPersistsAcrossFreezeToggle() {
        let state = AppState()
        state.toggleBackgroundEffect()
        XCTAssertTrue(state.backgroundEffectEnabled)
        state.toggleFreeze() // live -> frozen
        XCTAssertTrue(state.backgroundEffectEnabled)
        state.toggleFreeze() // frozen -> live
        XCTAssertTrue(state.backgroundEffectEnabled)
    }

    // MARK: - Deferred Changes

    func testEffectChangesAreDeferredWhenFrozen() {
        let state = AppState()
        state.toggleFreeze() // live -> frozen
        XCTAssertFalse(state.hasDeferredChanges)

        state.blurIntensity = 0.5
        XCTAssertTrue(state.hasDeferredChanges)
    }

    func testEffectChangesAreDeferredWhenLooping() {
        let state = AppState()
        state.toggleLoop() // live -> looping
        XCTAssertFalse(state.hasDeferredChanges)

        state.edgeSoftness = 0.8
        XCTAssertTrue(state.hasDeferredChanges)
    }

    func testDeferredChangesApplyOnResume() {
        let state = AppState()
        state.toggleFreeze() // live -> frozen
        state.blurIntensity = 0.5
        XCTAssertTrue(state.hasDeferredChanges)

        state.toggleFreeze() // frozen -> live
        XCTAssertFalse(state.hasDeferredChanges)
    }

    func testNoFalsePositiveDeferredChangesWhenLive() {
        let state = AppState()
        state.blurIntensity = 0.5
        XCTAssertFalse(state.hasDeferredChanges)
        state.edgeSoftness = 0.8
        XCTAssertFalse(state.hasDeferredChanges)
        state.backgroundMode = .remove
        XCTAssertFalse(state.hasDeferredChanges)
    }

    func testDeferredChangesBackgroundModeWhenFrozen() {
        let state = AppState()
        state.toggleFreeze() // live -> frozen
        state.backgroundMode = .remove
        XCTAssertTrue(state.hasDeferredChanges)
    }

    func testDeferredChangesResetOnLoopToLive() {
        let state = AppState()
        state.toggleLoop() // live -> looping
        state.blurIntensity = 0.2
        XCTAssertTrue(state.hasDeferredChanges)

        state.toggleLoop() // looping -> live
        XCTAssertFalse(state.hasDeferredChanges)
    }

    // MARK: - Consumer Tracking

    func testHasActiveConsumers() {
        let state = AppState()
        XCTAssertFalse(state.hasActiveConsumers)
        state.activeConsumerBundleIDs.insert("com.apple.FaceTime")
        XCTAssertTrue(state.hasActiveConsumers)
        state.activeConsumerBundleIDs.removeAll()
        XCTAssertFalse(state.hasActiveConsumers)
    }

    // MARK: - Virtual Camera

    func testVirtualCameraActiveFlag() {
        let state = AppState()
        XCTAssertFalse(state.virtualCameraActive)
        state.virtualCameraActive = true
        XCTAssertTrue(state.virtualCameraActive)
    }

    // MARK: - SettingsStore Wiring (Part C)

    func testLoadsBlurIntensityFromStore() {
        let suiteName = "test.appstate.load.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)
        store.blurIntensity = 0.42

        let state = AppState(settingsStore: store)
        XCTAssertEqual(state.blurIntensity, 0.42, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPersistsBlurIntensityChanges() {
        let suiteName = "test.appstate.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)

        let state = AppState(settingsStore: store)
        state.blurIntensity = 0.88

        XCTAssertEqual(store.blurIntensity, 0.88, accuracy: 0.001)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
