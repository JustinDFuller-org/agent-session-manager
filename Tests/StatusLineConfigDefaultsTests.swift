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

    func testDefaultInitUsesRequestedRows() {
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

    func testDecodingMissingFieldsMigratesToSymbolsAndLabels() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.factLabelStyle, .symbolAndLabel)
    }

    func testDecodingExplicitLabelOnlyPreservesIt() throws {
        let json = Data(#"{"factLabelStyle":"labelOnly"}"#.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.factLabelStyle, .labelOnly)
    }

    func testDecodingMissingFieldsFallsBackToSpaceBetween() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(config.rowAlignment, .spaceBetween)
    }

    func testDecodingMissingRowsFallsBackToRequestedRows() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertEqual(
            config.rows.map { $0.items.map(\.id) },
            [
                ["pr", "profileName", "model", "effort"],
                ["context", "contextRemaining", "contextSize", "exceeds200k"],
                ["inputTokens", "outputTokens", "cacheRead", "cacheCreation"],
                ["worktree", "cost", "linesAdded", "linesRemoved"],
            ])
    }

    func testDecodingExplicitRowsPreservesSavedLayout() throws {
        var savedConfig = StatusLineConfig()
        savedConfig.rows = [
            StatusLineRow(items: [
                StatusLineItem(id: "model", label: "Model", sfSymbol: "cpu")
            ])
        ]

        let encoded = try JSONEncoder().encode(savedConfig)
        let decoded = try JSONDecoder().decode(StatusLineConfig.self, from: encoded)

        XCTAssertEqual(decoded.rows.map { $0.items.map(\.id) }, [["model"]])
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
        XCTAssertEqual(field.supportedHarnesses, StatusLineConfig.allHarnesses)
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
            command: "litellm-metric.sh spend", refreshIntervalSeconds: 20, timeoutSeconds: 8,
            supportedHarnesses: [.claude, .cursor])
        var config = StatusLineConfig()
        config.customFields = [field]
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StatusLineConfig.self, from: encoded)
        XCTAssertEqual(decoded.customFields, [field])
    }

    func testMissingCustomFieldHarnessesDecodeAsAll() throws {
        let json = Data(
            """
            {
              "customFields": [
                {
                  "id": "custom:abc",
                  "label": "Spend",
                  "sfSymbol": "dollarsign.circle",
                  "command": "echo hi"
                }
              ]
            }
            """.utf8
        )

        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)

        XCTAssertEqual(config.customFields.first?.supportedHarnesses, StatusLineConfig.allHarnesses)
    }

    func testUnknownCustomFieldIconFallsBackToTerminal() throws {
        let json = Data(
            """
            {
              "customFields": [
                {
                  "id": "custom:abc",
                  "label": "Spend",
                  "sfSymbol": "not-a-real-symbol",
                  "command": "echo hi"
                }
              ]
            }
            """.utf8
        )

        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)

        XCTAssertEqual(config.customFields.first?.sfSymbol, "terminal")
    }

    func testCustomRowMetadataFollowsDecodedField() throws {
        let rowID = UUID().uuidString
        let json = Data(
            """
            {
              "customFields": [
                {
                  "id": "custom:abc",
                  "label": "Current Spend",
                  "sfSymbol": "dollarsign.square",
                  "command": "echo hi"
                }
              ],
              "rows": [
                {
                  "id": "\(rowID)",
                  "items": [
                    {
                      "id": "custom:abc",
                      "label": "Stale",
                      "sfSymbol": "not-a-real-symbol"
                    }
                  ]
                }
              ]
            }
            """.utf8
        )

        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        let item = try XCTUnwrap(config.rows.first?.items.first)

        XCTAssertEqual(item.label, "Current Spend")
        XCTAssertEqual(item.sfSymbol, "dollarsign.square")
    }

    func testCustomFieldCapabilityUsesSelectedHarnesses() {
        var config = StatusLineConfig()
        let field = CustomStatusLineField(
            id: "custom:cursor", label: "Cursor", command: "echo cursor", supportedHarnesses: [.cursor])
        config.customFields = [field]
        let item = StatusLineItem(id: field.id, label: field.label, sfSymbol: field.sfSymbol)

        XCTAssertTrue(config.supports(item, on: .cursor))
        XCTAssertFalse(config.supports(item, on: .claude))
    }

    func testAgentControlValidationRejectsEmptyCustomFieldHarnesses() {
        var config = StatusLineConfig()
        config.customFields = [
            CustomStatusLineField(
                id: "custom:00000000-0000-0000-0000-000000000001",
                label: "Empty",
                command: "echo empty",
                supportedHarnesses: []
            )
        ]

        XCTAssertThrowsError(try config.validateForAgentControl()) { error in
            XCTAssertEqual(
                error as? StatusLineConfigurationValidationError,
                .invalidCustomFieldHarnesses("custom:00000000-0000-0000-0000-000000000001")
            )
        }
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
