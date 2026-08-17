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
        let studyTab = app.buttons["tab.study"]
        let decksTab = app.buttons["tab.decks"]
        let insightsTab = app.buttons["tab.insights"]

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

    @MainActor
    func testGeneratedSampleDeckUsesEditorialStudyCard() {
        app.buttons["tab.insights"].tap()
        let settingsButton = app.navigationBars.buttons["insights.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        let generateButton = app.buttons["more.generateSamplesButton"]
        for _ in 0..<6 where !generateButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3))
        generateButton.tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let studyTab = app.buttons["tab.study"]
        XCTAssertTrue(studyTab.waitForExistence(timeout: 3))
        studyTab.tap()
        XCTAssertTrue(app.buttons["home.deckButton"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Today-With-Sample-Card")

        let revealButton = app.buttons["home.revealButton"]
        XCTAssertTrue(revealButton.waitForExistence(timeout: 3))
        revealButton.tap()
        XCTAssertTrue(app.buttons["home.grade.1"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Today-Answer-And-Grades")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
