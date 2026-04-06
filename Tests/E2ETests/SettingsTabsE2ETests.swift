import XCTest

private func launchApp(skipOnboarding: Bool = true, resetSettings: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    if resetSettings { app.launchArguments.append("--reset-settings") }
    if skipOnboarding { app.launchArguments.append("--skip-onboarding") }
    app.launchArguments.append("--e2e-testing")
    app.launch()
    return app
}

final class SettingsTabsE2ETests: XCTestCase {

    func testCameraTabShowsPreview() {
        let app = launchApp()

        // Camera tab should be default
        // Verify the settings window is showing camera tab content
        let cameraText = app.staticTexts["Source Camera"]
        XCTAssertTrue(cameraText.waitForExistence(timeout: 5))
    }

    func testCameraTabShowsResolutionPicker() {
        let app = launchApp()

        let resolutionText = app.staticTexts["Resolution"]
        XCTAssertTrue(resolutionText.waitForExistence(timeout: 5))
    }

    func testCameraTabShowsFrameratePicker() {
        let app = launchApp()

        let framerateText = app.staticTexts["Framerate"]
        XCTAssertTrue(framerateText.waitForExistence(timeout: 5))
    }

    func testNavigateToBackgroundTab() {
        let app = launchApp()

        let bgTab = app.staticTexts["Background"]
        XCTAssertTrue(bgTab.waitForExistence(timeout: 5))
        bgTab.tap()

        // Verify background tab content - the toggle renders as checkBox on macOS
        let effectToggle = app.checkBoxes["backgroundEffectToggle"].firstMatch
        let effectSwitch = app.switches["backgroundEffectToggle"].firstMatch
        let effectExists = effectToggle.waitForExistence(timeout: 3)
            || effectSwitch.waitForExistence(timeout: 1)
            || app.staticTexts["Enable Background Effect"].waitForExistence(timeout: 1)
        XCTAssertTrue(effectExists, "Background effect toggle should be visible")
    }

    func testNavigateToLoopTab() {
        let app = launchApp()

        let loopTab = app.staticTexts["Loop"]
        XCTAssertTrue(loopTab.waitForExistence(timeout: 5))
        loopTab.tap()

        // Verify loop tab content - the toggle renders as checkBox on macOS
        let bufferCheckBox = app.checkBoxes["bufferEnabledToggle"].firstMatch
        let bufferSwitch = app.switches["bufferEnabledToggle"].firstMatch
        let bufferExists = bufferCheckBox.waitForExistence(timeout: 3)
            || bufferSwitch.waitForExistence(timeout: 1)
            || app.staticTexts["Enable Rolling Buffer"].waitForExistence(timeout: 1)
        XCTAssertTrue(bufferExists, "Buffer toggle should be visible on Loop tab")
    }

    func testNavigateToHotkeysTab() {
        let app = launchApp()

        let hotkeysTab = app.staticTexts["Hotkeys"]
        XCTAssertTrue(hotkeysTab.waitForExistence(timeout: 5))
        hotkeysTab.tap()

        // Verify hotkeys content
        let shortcutsText = app.staticTexts["Global Keyboard Shortcuts"]
        XCTAssertTrue(shortcutsText.waitForExistence(timeout: 3))
    }

    func testNavigateToGeneralTab() {
        let app = launchApp()

        let generalTab = app.staticTexts["General"]
        XCTAssertTrue(generalTab.waitForExistence(timeout: 5))
        generalTab.tap()

        // Verify general tab content
        let generalTitle = app.staticTexts["General Settings"]
        XCTAssertTrue(generalTitle.waitForExistence(timeout: 3))
    }

    func testBackgroundTabModeSelector() {
        let app = launchApp()

        app.staticTexts["Background"].tap()

        // Segmented picker items may appear as buttons or radioButtons on macOS
        // Also check for the picker by accessibility identifier
        let picker = app.segmentedControls["backgroundModePicker"].firstMatch
        let blurButton = app.buttons["Blur"].firstMatch
        let blurRadio = app.radioButtons["Blur"].firstMatch
        let modeExists = picker.waitForExistence(timeout: 3)
            || blurButton.waitForExistence(timeout: 1)
            || blurRadio.waitForExistence(timeout: 1)
            || app.staticTexts["Mode"].waitForExistence(timeout: 1)
        XCTAssertTrue(modeExists, "Background mode selector should be visible")
    }

    func testLoopTabMemoryEstimate() {
        let app = launchApp()

        let loopTab = app.staticTexts["Loop"]
        XCTAssertTrue(loopTab.waitForExistence(timeout: 5))
        loopTab.tap()

        // Wait for Loop tab content to load
        let bufferDuration = app.staticTexts["Buffer Duration"]
        XCTAssertTrue(bufferDuration.waitForExistence(timeout: 3))

        // The HStack with memory info has accessibilityIdentifier "memoryEstimateInfo"
        // Try finding it by iterating element types that SwiftUI HStack might map to
        var found = false
        for elementType: XCUIElement.ElementType in [.group, .other, .staticText, .any] {
            let query = app.descendants(matching: elementType).matching(identifier: "memoryEstimateInfo")
            if query.firstMatch.waitForExistence(timeout: 1) {
                found = true
                break
            }
        }

        // Fallback: look for known text patterns in the memory estimate
        if !found {
            // The text "Estimated memory: ~X.X GB" is interpolated at runtime
            // Check for the tilde-number pattern or just any text with "GB" or "MB"
            let allTexts = app.staticTexts.allElementsBoundByIndex
            for text in allTexts {
                let label = text.label
                if label.contains("GB") || label.contains("MB") || label.contains("Estimated") || label.contains("memory") {
                    found = true
                    break
                }
            }
        }

        XCTAssertTrue(found, "Memory estimate should be displayed on Loop tab")
    }

    func testLoopTabBufferDuration() {
        let app = launchApp()

        app.staticTexts["Loop"].tap()

        // Buffer Duration label should exist
        let bufferDuration = app.staticTexts["Buffer Duration"]
        XCTAssertTrue(bufferDuration.waitForExistence(timeout: 3))
    }

    func testHotkeysTabRestoreDefaults() {
        let app = launchApp()

        app.staticTexts["Hotkeys"].tap()

        // Restore Defaults button should exist
        let restoreButton = app.buttons["restoreDefaultsButton"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 3))
    }

    func testGeneralTabToggles() {
        let app = launchApp()

        app.staticTexts["General"].tap()

        // On macOS, SwiftUI Toggle renders as checkBox, not switch
        let launchCheckBox = app.checkBoxes["launchAtLoginToggle"].firstMatch
        let launchSwitch = app.switches["launchAtLoginToggle"].firstMatch
        let launchExists = launchCheckBox.waitForExistence(timeout: 3)
            || launchSwitch.waitForExistence(timeout: 1)
            || app.staticTexts["Launch at Login"].waitForExistence(timeout: 1)
        XCTAssertTrue(launchExists, "Launch at Login toggle should be visible")

        let menubarCheckBox = app.checkBoxes["showInMenubarToggle"].firstMatch
        let menubarSwitch = app.switches["showInMenubarToggle"].firstMatch
        let menubarExists = menubarCheckBox.exists || menubarSwitch.exists
            || app.staticTexts["Show in Menu Bar"].exists
        XCTAssertTrue(menubarExists, "Show in Menu Bar toggle should be visible")
    }
}
