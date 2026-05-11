import XCTest

final class OpenCodeStatusLineUITests: BaseTestCase {
    func testStatusLineDescriptionMentionsOpenCode() {
        app.typeKey(",", modifierFlags: .command)

        let statusLineTab = app.buttons["Status Line"]
        waitFor(statusLineTab)
        statusLineTab.click()

        let description = app.staticTexts["settings-status-line-description"]
        waitFor(description)
        XCTAssertTrue(description.exists)
        XCTAssertTrue(
            (description.value as? String ?? "").contains("OpenCode only"),
            "Status Line description should mention 'OpenCode only' items"
        )
    }
}
