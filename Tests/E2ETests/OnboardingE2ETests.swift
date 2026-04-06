import XCTest

private func launchApp(skipOnboarding: Bool = true, resetSettings: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    if resetSettings { app.launchArguments.append("--reset-settings") }
    if skipOnboarding { app.launchArguments.append("--skip-onboarding") }
    app.launchArguments.append("--e2e-testing")
    app.launch()
    return app
}

final class OnboardingE2ETests: XCTestCase {

    func testOnboardingFlowShows() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-settings", "--e2e-testing"]
        // Do NOT add --skip-onboarding
        app.launch()

        // Welcome screen should appear
        let welcomeTitle = app.staticTexts["welcomeTitle"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5), "Welcome title should appear")
    }

    func testGetStartedButtonAdvancesStep() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-settings", "--e2e-testing"]
        app.launch()

        let getStarted = app.buttons["getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        // Should show camera permission step
        let cameraTitle = app.staticTexts["cameraAccessTitle"]
        XCTAssertTrue(cameraTitle.waitForExistence(timeout: 3))
    }

    func testCameraStepContinueAdvances() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-settings", "--e2e-testing"]
        app.launch()

        // Navigate past welcome
        let getStarted = app.buttons["getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        // Tap continue on camera step
        let cameraContinue = app.buttons["cameraContinueButton"]
        XCTAssertTrue(cameraContinue.waitForExistence(timeout: 3))
        cameraContinue.tap()

        // Should show accessibility permission step
        let accessibilityTitle = app.staticTexts["accessibilityTitle"]
        XCTAssertTrue(accessibilityTitle.waitForExistence(timeout: 3))
    }

    func testFullOnboardingFlowReachesDone() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-settings", "--e2e-testing"]
        app.launch()

        // Step 0: Welcome -> Get Started
        let getStarted = app.buttons["getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        // Step 1: Camera -> Continue
        let cameraContinue = app.buttons["cameraContinueButton"]
        XCTAssertTrue(cameraContinue.waitForExistence(timeout: 3))
        cameraContinue.tap()

        // Step 2: Accessibility -> Continue
        let accessibilityContinue = app.buttons["accessibilityContinueButton"]
        XCTAssertTrue(accessibilityContinue.waitForExistence(timeout: 3))
        accessibilityContinue.tap()

        // Step 3: Extension -> Continue
        let extensionContinue = app.buttons["extensionContinueButton"]
        XCTAssertTrue(extensionContinue.waitForExistence(timeout: 3))
        extensionContinue.tap()

        // Step 4: Done step should show
        let doneTitle = app.staticTexts["doneTitle"]
        XCTAssertTrue(doneTitle.waitForExistence(timeout: 3))

        // Open Settings button should exist
        let openSettings = app.buttons["openSettingsButton"]
        XCTAssertTrue(openSettings.waitForExistence(timeout: 3))
    }

    func testSkipOnboardingGoesDirectlyToSettings() {
        let app = launchApp(skipOnboarding: true)

        // Should show settings window, not onboarding
        // Look for the sidebar tabs
        let cameraTab = app.staticTexts["Camera"]
        XCTAssertTrue(cameraTab.waitForExistence(timeout: 5), "Camera tab should appear when onboarding is skipped")
    }
}
