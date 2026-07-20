import XCTest

final class FlashForgeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("UITEST_SKIP_ONBOARDING")
        app.launch()
    }

    @MainActor
    func testTabsAreVisibleAndNavigable() {
        let studyTab = app.tabBars.buttons["tab.study"]
        let decksTab = app.tabBars.buttons["tab.decks"]
        let insightsTab = app.tabBars.buttons["tab.insights"]

        XCTAssertTrue(studyTab.waitForExistence(timeout: 5))
        XCTAssertTrue(decksTab.exists)
        XCTAssertTrue(insightsTab.exists)

        studyTab.tap()
        XCTAssertTrue(app.buttons["home.deckButton"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Today")

        decksTab.tap()
        XCTAssertTrue(app.navigationBars.buttons["decks.addButton"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Library")

        insightsTab.tap()
        let settingsButton = app.navigationBars.buttons["insights.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        attachScreenshot(named: "Insights")
        app.swipeUp()
        attachScreenshot(named: "Insights-Scrolled")

        settingsButton.tap()
        XCTAssertTrue(app.buttons["more.backupButton"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Settings")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
