import XCTest

/// Tests that the app correctly surfaces version information and the Sparkle
/// "Check for Updates…" entry in the menu bar menu.
///
/// Note: We cannot test the full Sparkle download/install flow in a UI test
/// (that requires a real update on the feed). These tests verify the surface:
/// the version label is visible and the update action is triggerable.
final class UpdatesUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Test 1: Version label is shown in the menu bar menu

    func testVersionLabelIsVisibleInMenu() throws {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Menu bar status item should appear")
        statusItem.click()

        // The version label is a static text reading "DeepFocus v<semver>"
        let versionLabel = app.menuItems.matching(identifier: "versionMenuItem").firstMatch
        XCTAssertTrue(
            versionLabel.waitForExistence(timeout: 3),
            "Version label should appear in the menu"
        )

        // Label must contain a version string — at minimum "DeepFocus v"
        let labelText = versionLabel.title
        XCTAssertTrue(
            labelText.hasPrefix("DeepFocus v"),
            "Version label should read 'DeepFocus v<version>', got: \(labelText)"
        )
    }

    // MARK: - Test 2: "Check for Updates…" menu item exists and is tappable

    func testCheckForUpdatesMenuItemExists() throws {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Menu bar status item should appear")
        statusItem.click()

        let updateButton = app.menuItems.matching(identifier: "checkForUpdatesButton").firstMatch
        XCTAssertTrue(
            updateButton.waitForExistence(timeout: 3),
            "'Check for Updates…' menu item should be present"
        )
        XCTAssertTrue(updateButton.isEnabled, "'Check for Updates…' should be enabled")
    }

    // MARK: - Test 3: Version in menu matches bundle version

    func testMenuVersionMatchesBundleVersion() throws {
        let bundleVersion = Bundle(for: type(of: self))
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Menu bar status item should appear")
        statusItem.click()

        let versionLabel = app.menuItems.matching(identifier: "versionMenuItem").firstMatch
        XCTAssertTrue(versionLabel.waitForExistence(timeout: 3))

        if let expected = bundleVersion {
            XCTAssertTrue(
                versionLabel.title.contains(expected),
                "Menu version label should contain bundle version '\(expected)', got: \(versionLabel.title)"
            )
        }
    }
}
