import XCTest

@testable import AgentSessionManager

final class StatusLineConfigDefaultsTests: XCTestCase {
    func testDefaultInitProducesLabelOnly() {
        let config = StatusLineConfig()
        XCTAssertEqual(config.factLabelStyle, .labelOnly)
    }

    func testDefaultInitProducesSpaceBetween() {
        let config = StatusLineConfig()
        XCTAssertEqual(config.rowAlignment, .spaceBetween)
    }

    func testDecodingMissingFieldsFallsBackToLabelOnly() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.factLabelStyle, .labelOnly)
    }

    func testDecodingMissingFieldsFallsBackToSpaceBetween() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.rowAlignment, .spaceBetween)
    }

    func testDecodingExplicitSymbolOnlyPreservesIt() throws {
        let json = Data(#"{"factLabelStyle":"symbolOnly"}"#.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.factLabelStyle, .symbolOnly)
    }

    func testDecodingExplicitLeadingPreservesIt() throws {
        let json = Data(#"{"rowAlignment":"leading"}"#.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.rowAlignment, .leading)
    }

    func testDefaultInitShowPercentagesAsTextIsFalse() {
        let config = StatusLineConfig()
        XCTAssertFalse(config.showPercentagesAsText)
    }

    func testDecodingMissingFieldsFallsBackToShowPercentagesAsTextFalse() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertFalse(config.showPercentagesAsText)
    }

    func testDecodingExplicitShowPercentagesAsTextTrueRoundTrips() throws {
        let json = Data(#"{"showPercentagesAsText":true}"#.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertTrue(config.showPercentagesAsText)
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StatusLineConfig.self, from: encoded)
        XCTAssertTrue(decoded.showPercentagesAsText)
    }
}
