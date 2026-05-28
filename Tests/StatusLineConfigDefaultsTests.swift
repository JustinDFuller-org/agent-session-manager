import XCTest

@testable import AgentSessionManager

final class StatusLineConfigDefaultsTests: XCTestCase {
    func testDefaultInitProducesLabelOnly() {
        let config = StatusLineConfig()
        XCTAssertEqual(config.chipLabelStyle, .labelOnly)
    }

    func testDefaultInitProducesSpaceBetween() {
        let config = StatusLineConfig()
        XCTAssertEqual(config.rowAlignment, .spaceBetween)
    }

    func testDecodingMissingFieldsFallsBackToLabelOnly() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.chipLabelStyle, .labelOnly)
    }

    func testDecodingMissingFieldsFallsBackToSpaceBetween() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.rowAlignment, .spaceBetween)
    }

    func testDecodingExplicitSymbolOnlyPreservesIt() throws {
        let json = Data(#"{"chipLabelStyle":"symbolOnly"}"#.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.chipLabelStyle, .symbolOnly)
    }

    func testDecodingExplicitLeadingPreservesIt() throws {
        let json = Data(#"{"rowAlignment":"leading"}"#.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.rowAlignment, .leading)
    }
}
