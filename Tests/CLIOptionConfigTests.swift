import XCTest
@testable import AgentSessionManager

final class StatusLineConfigTests: XCTestCase {
    func testDefaultRowCount() {
        let config = StatusLineConfig()
        XCTAssertEqual(config.rows.count, 1)
    }

    func testDefaultRowItems() {
        let config = StatusLineConfig()
        XCTAssertEqual(Set(config.rows[0].items.map(\.id)), ["model", "worktree", "cost", "context"])
    }

    func testDefaultUsedItemIDs() {
        let config = StatusLineConfig()
        XCTAssertEqual(config.usedItemIDs, ["model", "worktree", "cost", "context"])
    }

    func testAllItemsCount() {
        XCTAssertEqual(StatusLineConfig.allItems.count, 24)
    }

    func testUsedItemIDsSpansAllRows() {
        var config = StatusLineConfig()
        let durationItem = StatusLineConfig.allItems.first { $0.id == "duration" }!
        config.rows.append(StatusLineRow(items: [durationItem]))
        XCTAssertTrue(config.usedItemIDs.contains("duration"))
        XCTAssertTrue(config.usedItemIDs.contains("model"))
    }

    func testNewFormatRoundTrip() throws {
        var config = StatusLineConfig()
        let costItem = StatusLineConfig.allItems.first { $0.id == "cost" }!
        config.rows.append(StatusLineRow(items: [costItem]))
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StatusLineConfig.self, from: encoded)
        XCTAssertEqual(decoded.rows.count, 2)
        XCTAssertTrue(decoded.usedItemIDs.contains("cost"))
        XCTAssertTrue(decoded.usedItemIDs.contains("model"))
    }

    func testEncodedJSONUsesRowsKey() throws {
        let config = StatusLineConfig()
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["rows"])
        XCTAssertNil(json["items"], "Legacy 'items' key must not appear in encoded output")
    }

    func testMigrationFromLegacyFormat() throws {
        let legacyJSON = """
        {
            "items": [
                {"id": "model", "label": "Model", "sfSymbol": "cpu", "isVisible": true},
                {"id": "cost", "label": "Cost", "sfSymbol": "dollarsign.circle", "isVisible": false},
                {"id": "worktree", "label": "Worktree", "sfSymbol": "folder.badge.gearshape", "isVisible": true}
            ],
            "chipLabelStyle": "symbolOnly",
            "rowAlignment": "leading"
        }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: legacyJSON)
        XCTAssertEqual(config.rows.count, 1)
        XCTAssertEqual(config.rows[0].items.map(\.id), ["model", "worktree"])
        XCTAssertEqual(config.usedItemIDs, ["model", "worktree"])
    }

    func testStatusLineDataFullParse() throws {
        let json = """
        {
            "model": {"id": "claude-opus-4-7", "display_name": "Opus"},
            "cost": {"total_cost_usd": 0.01234, "total_duration_ms": 45000, "total_lines_added": 156, "total_lines_removed": 23},
            "context_window": {"used_percentage": 8, "remaining_percentage": 92, "total_input_tokens": 15234, "total_output_tokens": 4521},
            "rate_limits": {
                "five_hour": {"used_percentage": 23.5, "resets_at": 1738425600},
                "seven_day": {"used_percentage": 41.2, "resets_at": 1738857600}
            },
            "worktree": {"name": "my-feature", "branch": "worktree-my-feature"},
            "workspace": {"git_worktree": "feature-xyz"},
            "effort": {"level": "high"},
            "thinking": {"enabled": true},
            "agent": {"name": "security-reviewer"},
            "output_style": {"name": "default"},
            "vim": {"mode": "NORMAL"},
            "session_name": "my-session",
            "version": "2.1.90",
            "exceeds_200k_tokens": false
        }
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(data.model?.id, "claude-opus-4-7")
        XCTAssertEqual(data.model?.displayName, "Opus")
        XCTAssertEqual(data.cost?.totalCostUsd, 0.01234)
        XCTAssertEqual(data.cost?.totalDurationMs, 45000)
        XCTAssertEqual(data.cost?.totalLinesAdded, 156)
        XCTAssertEqual(data.cost?.totalLinesRemoved, 23)
        XCTAssertEqual(data.contextWindow?.usedPercentage, 8)
        XCTAssertEqual(data.contextWindow?.remainingPercentage, 92)
        XCTAssertEqual(data.contextWindow?.totalInputTokens, 15234)
        XCTAssertEqual(data.contextWindow?.totalOutputTokens, 4521)
        XCTAssertEqual(data.rateLimits?.fiveHour?.usedPercentage, 23.5)
        XCTAssertEqual(data.rateLimits?.fiveHour?.resetsAt, 1738425600)
        XCTAssertEqual(data.rateLimits?.sevenDay?.usedPercentage, 41.2)
        XCTAssertEqual(data.worktree?.name, "my-feature")
        XCTAssertEqual(data.worktree?.branch, "worktree-my-feature")
        XCTAssertEqual(data.workspace?.gitWorktree, "feature-xyz")
        XCTAssertEqual(data.effort?.level, "high")
        XCTAssertEqual(data.thinking?.enabled, true)
        XCTAssertEqual(data.agent?.name, "security-reviewer")
        XCTAssertEqual(data.outputStyle?.name, "default")
        XCTAssertEqual(data.vim?.mode, "NORMAL")
        XCTAssertEqual(data.sessionName, "my-session")
        XCTAssertEqual(data.version, "2.1.90")
        XCTAssertEqual(data.exceeds200kTokens, false)
    }

    func testStatusLineDataPartialParse() throws {
        let json = """
        {"model": {"id": "claude-sonnet-4-6"}}
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(data.model?.id, "claude-sonnet-4-6")
        XCTAssertNil(data.model?.displayName)
        XCTAssertNil(data.cost)
        XCTAssertNil(data.contextWindow)
        XCTAssertNil(data.rateLimits)
        XCTAssertNil(data.worktree)
    }

    func testStatusLineDataEmptyJsonDoesNotCrash() throws {
        let json = "{}".data(using: .utf8)!
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertNil(data.model)
        XCTAssertNil(data.cost)
    }
}


final class CLIOptionConfigTests: XCTestCase {

    // All 62 flags from https://code.claude.com/docs/en/cli-reference#cli-flags
    private let expectedFlagIDs: Set<String> = [
        "--add-dir",
        "--agent",
        "--agents",
        "--allow-dangerously-skip-permissions",
        "--allowedTools",
        "--append-system-prompt",
        "--append-system-prompt-file",
        "--bare",
        "--betas",
        "--channels",
        "--chrome",
        "--continue",
        "--dangerously-load-development-channels",
        "--dangerously-skip-permissions",
        "--debug",
        "--debug-file",
        "--disable-slash-commands",
        "--disallowedTools",
        "--effort",
        "--enable-auto-mode",
        "--exclude-dynamic-system-prompt-sections",
        "--fallback-model",
        "--fork-session",
        "--from-pr",
        "--ide",
        "--include-hook-events",
        "--include-partial-messages",
        "--init",
        "--init-only",
        "--input-format",
        "--json-schema",
        "--maintenance",
        "--max-budget-usd",
        "--max-turns",
        "--mcp-config",
        "--model",
        "--name",
        "--no-chrome",
        "--no-session-persistence",
        "--output-format",
        "--permission-mode",
        "--permission-prompt-tool",
        "--plugin-dir",
        "--print",
        "--remote",
        "--remote-control",
        "--remote-control-session-name-prefix",
        "--replay-user-messages",
        "--resume",
        "--session-id",
        "--setting-sources",
        "--settings",
        "--strict-mcp-config",
        "--system-prompt",
        "--system-prompt-file",
        "--teleport",
        "--teammate-mode",
        "--tmux",
        "--tools",
        "--verbose",
        "--version",
        "--worktree",
    ]

    private var officialFlags: [CLIOptionConfig] {
        CLIOptionConfig.all.filter { !$0.isUserAdded }
    }

    func testAllExpectedFlagsArePresent() {
        let actualIDs = Set(officialFlags.map(\.id))
        let missing = expectedFlagIDs.subtracting(actualIDs)
        XCTAssertTrue(missing.isEmpty, "Missing flags: \(missing.sorted().joined(separator: ", "))")
    }

    func testNoUnexpectedFlagsPresent() {
        let actualIDs = Set(officialFlags.map(\.id))
        let unexpected = actualIDs.subtracting(expectedFlagIDs)
        XCTAssertTrue(unexpected.isEmpty, "Unexpected flags: \(unexpected.sorted().joined(separator: ", "))")
    }

    func testFlagCount() {
        XCTAssertEqual(officialFlags.count, 62, "Expected exactly 62 CLI flags")
    }

    func testNoDuplicateIDs() {
        let ids = officialFlags.map(\.id)
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "Duplicate flag IDs detected")
    }

    func testAllFlagsHaveNonEmptyLabelsAndDescriptions() {
        for option in officialFlags {
            XCTAssertFalse(option.label.isEmpty, "\(option.id) has empty label")
            XCTAssertFalse(option.description.isEmpty, "\(option.id) has empty description")
        }
    }

    func testOptionTypeDefinedForAllFlags() {
        for option in officialFlags {
            switch option.optionType {
            case .boolean:
                break
            case .string(let placeholder):
                XCTAssertFalse(placeholder.isEmpty, "\(option.id) string type has empty placeholder")
            }
        }
    }

    func testUserAddedBooleanFlag() {
        let flag = CLIOptionConfig.makeUserAdded(id: "--my-flag", isString: false)
        XCTAssertTrue(flag.isUserAdded)
        XCTAssertFalse(flag.customIsStringType)
        XCTAssertEqual(flag.id, "--my-flag")
        if case .boolean = flag.optionType {} else {
            XCTFail("Expected boolean optionType for user-added boolean flag")
        }
    }

    func testUserAddedStringFlag() {
        let flag = CLIOptionConfig.makeUserAdded(id: "--my-str-flag", isString: true)
        XCTAssertTrue(flag.isUserAdded)
        XCTAssertTrue(flag.customIsStringType)
        if case .string(let placeholder) = flag.optionType {
            XCTAssertFalse(placeholder.isEmpty)
        } else {
            XCTFail("Expected string optionType for user-added string flag")
        }
    }

    func testUserAddedFlagCodingRoundTrip() throws {
        let original = CLIOptionConfig.makeUserAdded(id: "--test-flag", isString: true)
        var mutable = original
        mutable.isAvailable = true
        mutable.isDefaultEnabled = true

        let encoded = try JSONEncoder().encode(mutable)
        let decoded = try JSONDecoder().decode(CLIOptionConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, "--test-flag")
        XCTAssertTrue(decoded.isUserAdded)
        XCTAssertTrue(decoded.customIsStringType)
        XCTAssertTrue(decoded.isAvailable)
        XCTAssertTrue(decoded.isDefaultEnabled)
        if case .string = decoded.optionType {} else {
            XCTFail("Expected string optionType after decoding")
        }
    }

    func testOfficialFlagCodingDoesNotIncludeUserAddedFields() throws {
        let flag = CLIOptionConfig.all.first!
        let encoded = try JSONEncoder().encode(flag)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertNil(json["isUserAdded"], "Official flags should not encode isUserAdded")
        XCTAssertNil(json["customIsStringType"], "Official flags should not encode customIsStringType")
    }
}
