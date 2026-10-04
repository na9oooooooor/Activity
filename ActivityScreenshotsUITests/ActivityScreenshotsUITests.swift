import XCTest

@MainActor
final class ActivityScreenshotsUITests:
    XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMarketing01Recommendation()
        throws {

        let app = launchApp(
            scenario: "recommendation",
            appearance: "Dark"
        )

        XCTAssertTrue(
            app.staticTexts["Today"]
                .waitForExistence(timeout: 10)
        )

        waitForAnimations()

        saveScreenshot(
            named:
                "Marketing-01-Recommendation"
        )
    }

    func testMarketing02Covered()
        throws {

        let app = launchApp(
            scenario: "covered",
            appearance: "Dark"
        )

        XCTAssertTrue(
            app.staticTexts["On track"]
                .waitForExistence(timeout: 10)
        )

        waitForAnimations()

        saveScreenshot(
            named:
                "Marketing-02-Covered"
        )
    }

    func testMarketing03Recovery()
        throws {

        let app = launchApp(
            scenario: "recovery",
            appearance: "Dark"
        )

        XCTAssertTrue(
            app.buttons["Recovery"]
                .waitForExistence(timeout: 10)
        )

        waitForAnimations()

        saveScreenshot(
            named:
                "Marketing-03-Recovery"
        )
    }

    func testMarketing04Trends30()
        throws {

        let app = launchApp(
            scenario: "trends30",
            appearance: "Dark",
            plusAccess: true
        )

        let trendsButton =
            app.tabBars.buttons["Trends"]

        XCTAssertTrue(
            trendsButton.waitForExistence(
                timeout: 10
            )
        )

        trendsButton.tap()

        let thirtyDayButton =
            app.buttons["30D"]

        XCTAssertTrue(
            thirtyDayButton.waitForExistence(
                timeout: 5
            )
        )

        thirtyDayButton.tap()

        XCTAssertTrue(
            app.staticTexts[
                "Covered 3 of 4 weeks"
            ]
            .waitForExistence(timeout: 5)
        )

        waitForAnimations()

        saveScreenshot(
            named:
                "Marketing-04-Trends"
        )
    }

    private func launchApp(
        scenario: String,
        appearance: String,
        plusAccess: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()

        app.launchArguments = [
            "--screenshot-mode",
            "--screenshot-scenario",
            scenario,
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]

        if appearance == "Dark" {
            app.launchArguments.append(
                "--screenshot-dark"
            )
        }

        if plusAccess {
            app.launchArguments.append(
                "--screenshot-plus"
            )
        }

        app.launch()

        return app
    }

    private func waitForAnimations() {
        Thread.sleep(
            forTimeInterval: 1.2
        )
    }

    private func saveScreenshot(
        named name: String
    ) {
        let screenshot =
            XCUIScreen.main.screenshot()

        let attachment =
            XCTAttachment(
                screenshot: screenshot
            )

        attachment.name = name
        attachment.lifetime = .keepAlways

        add(attachment)
    }
}
