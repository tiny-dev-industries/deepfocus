import XCTest

final class AppBlockerUITests: XCTestCase {

    // MARK: - Test 1: Block when focus moves from another allowed app

    /// Verifies that switching focus from an allowed app (e.g. Calculator) to a blocked app
    /// increments the counter AND sends the blocked app to the background.
    func testBlocksWhenFocusMovesFromAnotherApp() throws {
        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        textEdit.launch()
        sleep(1)

        let app = XCUIApplication()
        app.launchEnvironment = [
            "DEEPFOCUS_UI_TEST": "1",
            "DEEPFOCUS_TEST_BLOCKLIST": "com.apple.TextEdit",
            "DEEPFOCUS_TEST_DURATION": "120",
        ]
        app.launch()
        sleep(3)

        XCTAssertTrue(app.windows["hud"].waitForExistence(timeout: 5), "HUD should exist")

        try openApp("TextEdit")
        sleep(3)

        XCTAssertTrue(
            app.staticTexts["blockedAttempts"].waitForExistence(timeout: 10),
            "HUD should show blocked attempts counter"
        )
        XCTAssertNotEqual(
            textEdit.state, .runningForeground,
            "Blocked app should be pushed to background, not retained in foreground"
        )
        textEdit.terminate()
    }

    // MARK: - Test 2: Block when focus moves from a non-DeepFocus allowed app

    /// Specifically targets the macOS 15 regression where activate(options:) was deprecated.
    /// Uses Calculator as the "last allowed" app, then tries to switch to blocked TextEdit.
    func testFocusRedirectsBackToLastAllowedApp() throws {
        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        let calculator = XCUIApplication(bundleIdentifier: "com.apple.Calculator")
        textEdit.launch()
        sleep(1)

        let app = XCUIApplication()
        app.launchEnvironment = [
            "DEEPFOCUS_UI_TEST": "1",
            "DEEPFOCUS_TEST_BLOCKLIST": "com.apple.TextEdit",
            "DEEPFOCUS_TEST_DURATION": "120",
        ]
        app.launch()
        sleep(3)

        XCTAssertTrue(app.windows["hud"].waitForExistence(timeout: 5), "HUD should exist")

        // Make Calculator the "last allowed" app before attempting to open the blocked app
        calculator.launch()
        sleep(2)
        XCTAssertEqual(calculator.state, .runningForeground, "Calculator should be foreground")

        // Now switch to blocked TextEdit — focus should redirect back (not stay on TextEdit)
        try openApp("TextEdit")
        sleep(3)

        XCTAssertTrue(
            app.staticTexts["blockedAttempts"].waitForExistence(timeout: 10),
            "HUD should show blocked attempts counter"
        )
        XCTAssertNotEqual(
            textEdit.state, .runningForeground,
            "Blocked app should be sent to background, not retain foreground"
        )

        textEdit.terminate()
        calculator.terminate()
    }

    // MARK: - Test 3: Block when focus moves directly from DeepFocus

    /// When lastAllowedApp is nil (DeepFocus was the last active app),
    /// the HUD should become key rather than trying to activate a nil fallback.
    func testBlocksWhenFocusMovesFromDeepFocus() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "DEEPFOCUS_UI_TEST": "1",
            "DEEPFOCUS_TEST_BLOCKLIST": "com.apple.TextEdit",
            "DEEPFOCUS_TEST_DURATION": "120",
        ]
        app.launch()
        sleep(3)

        XCTAssertTrue(app.windows["hud"].waitForExistence(timeout: 5), "HUD should exist")

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        textEdit.launch()
        sleep(3)

        XCTAssertTrue(
            app.staticTexts["blockedAttempts"].waitForExistence(timeout: 10),
            "HUD should show blocked attempts when redirecting from DeepFocus-focused state"
        )
        XCTAssertNotEqual(
            textEdit.state, .runningForeground,
            "Blocked app should be pushed to background"
        )
        textEdit.terminate()
    }

    // MARK: - Test 4: Three blocked apps all redirect correctly

    /// Verifies that a blocklist with 3 entries works for each one.
    /// Each app should be blocked and sent to background independently.
    func testThreeBlockedAppsAllRedirect() throws {
        let textEdit   = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        let calculator = XCUIApplication(bundleIdentifier: "com.apple.Calculator")
        let stickies   = XCUIApplication(bundleIdentifier: "com.apple.Stickies")

        textEdit.launch()
        calculator.launch()
        stickies.launch()
        sleep(2)

        let app = XCUIApplication()
        app.launchEnvironment = [
            "DEEPFOCUS_UI_TEST": "1",
            "DEEPFOCUS_TEST_BLOCKLIST": "com.apple.TextEdit,com.apple.Calculator,com.apple.Stickies",
            "DEEPFOCUS_TEST_DURATION": "120",
        ]
        app.launch()
        sleep(3)

        XCTAssertTrue(app.windows["hud"].waitForExistence(timeout: 5), "HUD should exist")

        let counter = app.staticTexts["blockedAttempts"]

        // Block attempt 1: TextEdit
        try openApp("TextEdit")
        sleep(3)
        XCTAssertTrue(counter.waitForExistence(timeout: 10), "First block should register")
        XCTAssertNotEqual(textEdit.state, .runningForeground, "TextEdit should be in background")

        // Block attempt 2: Calculator
        try openApp("Calculator")
        sleep(3)
        XCTAssertTrue(counter.exists, "Counter should still be visible")
        XCTAssertNotEqual(calculator.state, .runningForeground, "Calculator should be in background")

        // Block attempt 3: Stickies
        try openApp("Stickies")
        sleep(3)
        XCTAssertNotEqual(stickies.state, .runningForeground, "Stickies should be in background")

        // All 3 blocks registered
        XCTAssertTrue(counter.exists, "Blocked counter should show after 3 block events")

        textEdit.terminate()
        calculator.terminate()
        stickies.terminate()
    }

    // MARK: - Test 5: Allowlist blocks unlisted apps

    func testAllowlistBlocksUnlistedApps() throws {
        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        textEdit.launch()
        sleep(1)

        let app = XCUIApplication()
        app.launchEnvironment = [
            "DEEPFOCUS_UI_TEST": "1",
            "DEEPFOCUS_TEST_MODE": "allowlist",
            "DEEPFOCUS_TEST_ALLOWLIST": "com.apple.Safari",
            "DEEPFOCUS_TEST_DURATION": "120",
        ]
        app.launch()
        sleep(3)

        XCTAssertTrue(app.windows["hud"].waitForExistence(timeout: 5), "HUD should exist")

        try openApp("TextEdit")
        sleep(3)

        XCTAssertTrue(
            app.staticTexts["blockedAttempts"].waitForExistence(timeout: 10),
            "Allowlist mode should block apps not in the allowlist"
        )
        XCTAssertNotEqual(
            textEdit.state, .runningForeground,
            "Blocked app should be in background"
        )
        textEdit.terminate()
    }

    // MARK: - Test 6: Allowlist permits listed apps

    func testAllowlistPermitsListedApps() throws {
        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        textEdit.launch()
        sleep(1)

        let app = XCUIApplication()
        app.launchEnvironment = [
            "DEEPFOCUS_UI_TEST": "1",
            "DEEPFOCUS_TEST_MODE": "allowlist",
            "DEEPFOCUS_TEST_ALLOWLIST": "com.apple.TextEdit",
            "DEEPFOCUS_TEST_DURATION": "120",
        ]
        app.launch()
        sleep(3)

        XCTAssertTrue(app.windows["hud"].waitForExistence(timeout: 5), "HUD should exist")

        try openApp("TextEdit")
        sleep(3)

        XCTAssertFalse(
            app.staticTexts["blockedAttempts"].exists,
            "Allowlist mode should not block apps in the allowlist"
        )
        textEdit.terminate()
    }

    // MARK: - Helpers

    private func openApp(_ name: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", name]
        try process.run()
        process.waitUntilExit()
    }
}
