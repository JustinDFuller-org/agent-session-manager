import XCTest

@testable import AgentSessionManager

final class StatusLineConfigWizardDefaultTests: XCTestCase {
    func testWizardDefaultProducesFourRows() {
        let config = StatusLineConfig.wizardDefault()
        XCTAssertEqual(config.rows.count, 4)
    }

    func testWizardDefaultRow1Items() {
        let config = StatusLineConfig.wizardDefault()
        let ids = config.rows[0].items.map(\.id)
        XCTAssertEqual(ids, ["pr", "profileName", "model", "effort"])
    }

    func testWizardDefaultRow2Items() {
        let config = StatusLineConfig.wizardDefault()
        let ids = config.rows[1].items.map(\.id)
        XCTAssertEqual(ids, ["context", "contextRemaining", "contextSize", "exceeds200k"])
    }

    func testWizardDefaultRow3Items() {
        let config = StatusLineConfig.wizardDefault()
        let ids = config.rows[2].items.map(\.id)
        XCTAssertEqual(ids, ["inputTokens", "outputTokens", "cacheRead", "cacheCreation"])
    }

    func testWizardDefaultRow4Items() {
        let config = StatusLineConfig.wizardDefault()
        let ids = config.rows[3].items.map(\.id)
        XCTAssertEqual(ids, ["worktree", "cost", "linesAdded", "linesRemoved"])
    }

    func testWizardDefaultFactLabelStyle() {
        let config = StatusLineConfig.wizardDefault()
        XCTAssertEqual(config.factLabelStyle, .symbolAndLabel)
    }

    func testWizardDefaultRowAlignment() {
        let config = StatusLineConfig.wizardDefault()
        XCTAssertEqual(config.rowAlignment, .spaceBetween)
    }

    func testCatalogDefaultUsesRequestedRows() {
        let config = StatusLineConfig()
        XCTAssertEqual(
            config.rows.map { $0.items.map(\.id) },
            [
                ["pr", "profileName", "model", "effort"],
                ["context", "contextRemaining", "contextSize", "exceeds200k"],
                ["inputTokens", "outputTokens", "cacheRead", "cacheCreation"],
                ["worktree", "cost", "linesAdded", "linesRemoved"],
            ])
    }

    func testWizardAndCatalogDefaultsUseSameRows() {
        let catalogRows = StatusLineConfig().rows.map(\.items)
        let wizardRows = StatusLineConfig.wizardDefault().rows.map(\.items)
        XCTAssertEqual(catalogRows, wizardRows)
    }
}
