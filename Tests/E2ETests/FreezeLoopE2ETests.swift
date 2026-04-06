import XCTest

private func launchApp(skipOnboarding: Bool = true, resetSettings: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    if resetSettings { app.launchArguments.append("--reset-settings") }
    if skipOnboarding { app.launchArguments.append("--skip-onboarding") }
    app.launchArguments.append("--e2e-testing")
    app.launch()
    return app
}

final class FreezeLoopE2ETests: XCTestCase {

    // Note: These tests verify UI state changes. The actual freeze/loop
    // behavior requires a running camera pipeline which may not be
    // available in E2E tests. Focus on verifying the UI responds correctly.

    func testAppLaunchesSuccessfully() {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    func testSettingsWindowHasFiveNavItems() {
        let app = launchApp()

        // Verify all 5 sidebar tabs exist
        XCTAssertTrue(app.staticTexts["Camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Background"].exists)
        XCTAssertTrue(app.staticTexts["Loop"].exists)
        XCTAssertTrue(app.staticTexts["Hotkeys"].exists)
        XCTAssertTrue(app.staticTexts["General"].exists)
    }

    func testVirtualCameraStatusVisible() {
        let app = launchApp()

        // Camera tab is default, check for virtual camera status
        let status = app.otherElements["virtualCameraStatus"].firstMatch
        let statusExists = status.waitForExistence(timeout: 5)
            || app.staticTexts["Virtual Camera"].waitForExistence(timeout: 2)
        XCTAssertTrue(statusExists, "Virtual camera status should be visible on Camera tab")
    }

    func testLoopTabBufferControls() {
        let app = launchApp()

        // Navigate to Loop tab
        let loopTab = app.staticTexts["Loop"]
        XCTAssertTrue(loopTab.waitForExistence(timeout: 5))
        loopTab.tap()

        // Buffer toggle - on macOS, SwiftUI Toggle renders as checkBox
        let bufferCheckBox = app.checkBoxes["bufferEnabledToggle"].firstMatch
        let bufferSwitch = app.switches["bufferEnabledToggle"].firstMatch
        let bufferExists = bufferCheckBox.waitForExistence(timeout: 3)
            || bufferSwitch.waitForExistence(timeout: 1)
            || app.staticTexts["Enable Rolling Buffer"].waitForExistence(timeout: 1)
        XCTAssertTrue(bufferExists, "Buffer toggle should be visible on Loop tab")

        // Buffer duration slider should exist
        let durationSlider = app.sliders["bufferDurationSlider"].firstMatch
        let durationExists = durationSlider.waitForExistence(timeout: 3)
            || app.staticTexts["Buffer Duration"].waitForExistence(timeout: 1)
        XCTAssertTrue(durationExists, "Buffer duration control should be visible")
    }

    func testLoopTabTransitionControls() {
        let app = launchApp()

        // Navigate to Loop tab
        app.staticTexts["Loop"].tap()

        // Crossfade duration label should exist
        let crossfadeText = app.staticTexts["Crossfade Duration"]
        XCTAssertTrue(crossfadeText.waitForExistence(timeout: 3))

        // Resume transition label should exist
        let resumeText = app.staticTexts["Resume Transition"]
        XCTAssertTrue(resumeText.waitForExistence(timeout: 3))
    }

    func testLoopTabBufferTimeline() {
        let app = launchApp()

        // Navigate to Loop tab
        app.staticTexts["Loop"].tap()

        // Buffer Timeline header should exist
        let timelineHeader = app.staticTexts["Buffer Timeline"]
        XCTAssertTrue(timelineHeader.waitForExistence(timeout: 3))
    }

    func testTabNavigationRoundTrip() {
        let app = launchApp()

        // Start on Camera tab
        let sourceCameraText = app.staticTexts["Source Camera"]
        XCTAssertTrue(sourceCameraText.waitForExistence(timeout: 5))

        // Go to Loop tab
        app.staticTexts["Loop"].tap()
        let bufferDuration = app.staticTexts["Buffer Duration"]
        XCTAssertTrue(bufferDuration.waitForExistence(timeout: 3))

        // Go back to Camera tab
        app.staticTexts["Camera"].tap()
        XCTAssertTrue(sourceCameraText.waitForExistence(timeout: 3))
    }
}
