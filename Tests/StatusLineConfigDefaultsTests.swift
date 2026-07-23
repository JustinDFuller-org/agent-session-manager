import XCTest

@testable import AgentSessionManager

final class StatusLineConfigDefaultsTests: XCTestCase {
    func testDefaultInitProducesSymbolsAndLabels() {
        let config = StatusLineConfig()
        XCTAssertEqual(config.factLabelStyle, .symbolAndLabel)
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

    // MARK: - Custom Fields

    func testDefaultInitCustomFieldsIsEmpty() {
        XCTAssertTrue(StatusLineConfig().customFields.isEmpty)
    }

    func testDecodingMissingCustomFieldsFallsBackToEmpty() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertTrue(config.customFields.isEmpty)
    }

    func testCustomFieldDefaultInitProducesSensibleDefaults() {
        let field = CustomStatusLineField(label: "Spend", command: "echo hi")
        XCTAssertTrue(field.id.hasPrefix("custom:"))
        XCTAssertEqual(field.sfSymbol, "terminal")
        XCTAssertEqual(field.refreshIntervalSeconds, CustomStatusLineField.defaultRefreshIntervalSeconds)
        XCTAssertEqual(field.timeoutSeconds, CustomStatusLineField.defaultTimeoutSeconds)
    }

    func testCustomFieldEffectiveRefreshIntervalClampsToMinimum() {
        let field = CustomStatusLineField(label: "Spend", command: "echo hi", refreshIntervalSeconds: 1)
        XCTAssertEqual(field.effectiveRefreshIntervalSeconds, CustomStatusLineField.minimumRefreshIntervalSeconds)
    }

    func testCustomFieldEffectiveRefreshIntervalPreservesLargerValues() {
        let field = CustomStatusLineField(label: "Spend", command: "echo hi", refreshIntervalSeconds: 60)
        XCTAssertEqual(field.effectiveRefreshIntervalSeconds, 60)
    }

    func testCustomFieldRoundTripsThroughStatusLineConfigCoding() throws {
        let field = CustomStatusLineField(
            id: "custom:abc", label: "Spend", sfSymbol: "dollarsign.circle",
            command: "litellm-metric.sh spend", refreshIntervalSeconds: 20, timeoutSeconds: 8)
        var config = StatusLineConfig()
        config.customFields = [field]
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StatusLineConfig.self, from: encoded)
        XCTAssertEqual(decoded.customFields, [field])
    }

    func testAvailableItemsIncludesCustomFields() {
        var config = StatusLineConfig()
        config.customFields = [CustomStatusLineField(id: "custom:xyz", label: "Spend", command: "echo hi")]
        XCTAssertTrue(config.availableItems().map(\.id).contains("custom:xyz"))
    }

    func testAvailableItemsIncludesAllBuiltInsPlusCustomFields() {
        var config = StatusLineConfig()
        config.customFields = [CustomStatusLineField(id: "custom:xyz", label: "Spend", command: "echo hi")]
        XCTAssertEqual(config.availableItems().count, StatusLineConfig.allItems.count + 1)
    }
}
