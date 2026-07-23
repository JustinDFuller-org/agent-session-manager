import XCTest

@testable import AgentSessionManager

final class StatusLineConfigWizardDefaultTests: XCTestCase {
    func testWizardDefaultProducesThreeRows() {
        let config = StatusLineConfig.wizardDefault()
        XCTAssertEqual(config.rows.count, 3)
    }

    func testWizardDefaultRow1Items() {
        let config = StatusLineConfig.wizardDefault()
        let ids = config.rows[0].items.map(\.id)
        XCTAssertEqual(ids, ["pr", "profileName", "model"])
    }

    func testWizardDefaultRow2Items() {
        let config = StatusLineConfig.wizardDefault()
        let ids = config.rows[1].items.map(\.id)
        XCTAssertEqual(ids, ["context", "contextRemaining", "inputTokens", "outputTokens"])
    }

    func testWizardDefaultRow3Items() {
        let config = StatusLineConfig.wizardDefault()
        let ids = config.rows[2].items.map(\.id)
        XCTAssertEqual(ids, ["worktree", "linesAdded", "linesRemoved"])
    }

    func testWizardDefaultFactLabelStyle() {
        let config = StatusLineConfig.wizardDefault()
        XCTAssertEqual(config.factLabelStyle, .symbolAndLabel)
    }

    func testWizardDefaultRowAlignment() {
        let config = StatusLineConfig.wizardDefault()
        XCTAssertEqual(config.rowAlignment, .spaceBetween)
    }

    func testCatalogDefaultIsUnchanged() {
        let config = StatusLineConfig()
        XCTAssertEqual(config.rows.count, 1)
        let ids = config.rows[0].items.map(\.id)
        XCTAssertEqual(ids, ["model", "worktree", "cost", "context"])
    }
}
