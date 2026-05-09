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
        XCTAssertEqual(StatusLineConfig.allItems.count, 25)
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

    func testItemAvailabilityCoversAllMetadataIDs() {
        for id in StatusLineConfig.itemMetadata.keys {
            XCTAssertNotNil(StatusLineConfig.itemAvailability[id], "Missing availability for item: \(id)")
        }
    }

    func testItemAvailabilityMatchesMetadataCount() {
        XCTAssertEqual(StatusLineConfig.itemAvailability.count, StatusLineConfig.itemMetadata.count)
    }

    func testAgnosticItemsAreCorrect() {
        let agnosticIds: Set<String> = ["worktree", "worktreeBranch", "gitWorktree", "duration", "version", "pr"]
        for id in agnosticIds {
            XCTAssertEqual(StatusLineConfig.itemAvailability[id], .all, "\(id) should be .all")
        }
    }

    func testClaudeOnlyItemsAreAllOtherItems() {
        let agnosticIds: Set<String> = ["worktree", "worktreeBranch", "gitWorktree", "duration", "version", "pr"]
        for id in StatusLineConfig.itemMetadata.keys where !agnosticIds.contains(id) {
            XCTAssertEqual(StatusLineConfig.itemAvailability[id], .claudeOnly, "\(id) should be .claudeOnly")
        }
    }

    func testSupportedByClaudeReturnsTrueForAll() {
        for id in StatusLineConfig.itemMetadata.keys {
            let item = StatusLineItem(id: id, label: "Test", sfSymbol: "circle")
            XCTAssertTrue(item.supportedBy(.claude), "\(id) should be supported by Claude")
        }
    }

    func testSupportedByNonClaudeReturnsOnlyAgnostic() {
        let agnosticIds: Set<String> = ["worktree", "worktreeBranch", "gitWorktree", "duration", "version", "pr"]
        for id in StatusLineConfig.itemMetadata.keys {
            let item = StatusLineItem(id: id, label: "Test", sfSymbol: "circle")
            let expected = agnosticIds.contains(id)
            for cliType: CLIType in [.codex, .cursor, .opencode] {
                XCTAssertEqual(item.supportedBy(cliType), expected, "\(id) supportedBy \(cliType) should be \(expected)")
            }
        }
    }

    func testDefaultVisibleIncludesMixedAvailability() {
        let defaultVisible = StatusLineConfig().rows.flatMap { $0.items.map(\.id) }
        let hasAgnostic = defaultVisible.contains { StatusLineConfig.itemAvailability[$0] == .all }
        let hasClaudeOnly = defaultVisible.contains { StatusLineConfig.itemAvailability[$0] == .claudeOnly }
        XCTAssertTrue(hasAgnostic, "Default visible items should include at least one agnostic item")
        XCTAssertTrue(hasClaudeOnly, "Default visible items should include at least one Claude-only item")
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
        XCTAssertEqual(officialFlags.count, 61, "Expected exactly 61 CLI flags")
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

final class CodexCLIOptionConfigTests: XCTestCase {
    private var codexOptions: [CLIOptionConfig] {
        CLIOptionConfig.codexAll.filter { !$0.isUserAdded }
    }

    func testCodexFlagCount() {
        XCTAssertEqual(codexOptions.count, 12, "Expected exactly 12 Codex CLI flags")
    }

    func testNoDuplicateCodexIDs() {
        let ids = codexOptions.map(\.id)
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "Duplicate Codex flag IDs detected")
    }

    func testAllCodexFlagsHaveNonEmptyLabelsAndDescriptions() {
        for option in codexOptions {
            XCTAssertFalse(option.label.isEmpty, "\(option.id) has empty label")
            XCTAssertFalse(option.description.isEmpty, "\(option.id) has empty description")
        }
    }

    func testCodexOptionTypeDefinedForAllFlags() {
        for option in codexOptions {
            switch option.optionType {
            case .boolean:
                break
            case .string(let placeholder):
                XCTAssertFalse(placeholder.isEmpty, "\(option.id) string type has empty placeholder")
            }
        }
    }

    func testCodexFlagRoundTrip() throws {
        let original = CLIOptionConfig.codexAll.first { $0.id == "--ask-for-approval" }!
        var mutable = original
        mutable.isAvailable = true
        mutable.isDefaultEnabled = false

        let encoded = try JSONEncoder().encode(mutable)
        let decoded = try JSONDecoder().decode(CLIOptionConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, "--ask-for-approval")
        XCTAssertFalse(decoded.isUserAdded)
        XCTAssertTrue(decoded.isAvailable)
        XCTAssertFalse(decoded.isDefaultEnabled)
    }
}

final class CursorCLIOptionConfigTests: XCTestCase {
    private var cursorOptions: [CLIOptionConfig] {
        CLIOptionConfig.cursorAll.filter { !$0.isUserAdded }
    }

    func testCursorFlagCount() {
        XCTAssertEqual(cursorOptions.count, 17, "Expected exactly 17 Cursor CLI flags")
    }

    func testNoDuplicateCursorIDs() {
        let ids = cursorOptions.map(\.id)
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "Duplicate Cursor flag IDs detected")
    }

    func testAllCursorFlagsHaveNonEmptyLabelsAndDescriptions() {
        for option in cursorOptions {
            XCTAssertFalse(option.label.isEmpty, "\(option.id) has empty label")
            XCTAssertFalse(option.description.isEmpty, "\(option.id) has empty description")
        }
    }

    func testCursorOptionTypeDefinedForAllFlags() {
        for option in cursorOptions {
            switch option.optionType {
            case .boolean:
                break
            case .string(let placeholder):
                XCTAssertFalse(placeholder.isEmpty, "\(option.id) string type has empty placeholder")
            }
        }
    }

    func testCursorFlagRoundTrip() throws {
        let original = CLIOptionConfig.cursorAll.first { $0.id == "--api-key" }!
        var mutable = original
        mutable.isAvailable = true
        mutable.isDefaultEnabled = false

        let encoded = try JSONEncoder().encode(mutable)
        let decoded = try JSONDecoder().decode(CLIOptionConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, "--api-key")
        XCTAssertFalse(decoded.isUserAdded)
        XCTAssertTrue(decoded.isAvailable)
        XCTAssertFalse(decoded.isDefaultEnabled)
    }
}

final class OpenCodeCLIOptionConfigTests: XCTestCase {
    private var opencodeOptions: [CLIOptionConfig] {
        CLIOptionConfig.opencodeAll.filter { !$0.isUserAdded }
    }

    func testOpenCodeFlagCount() {
        XCTAssertEqual(opencodeOptions.count, 11, "Expected exactly 11 OpenCode CLI flags")
    }

    func testNoDuplicateOpenCodeIDs() {
        let ids = opencodeOptions.map(\.id)
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "Duplicate OpenCode flag IDs detected")
    }

    func testAllOpenCodeFlagsHaveNonEmptyLabelsAndDescriptions() {
        for option in opencodeOptions {
            XCTAssertFalse(option.label.isEmpty, "\(option.id) has empty label")
            XCTAssertFalse(option.description.isEmpty, "\(option.id) has empty description")
        }
    }

    func testOpenCodeOptionTypeDefinedForAllFlags() {
        for option in opencodeOptions {
            switch option.optionType {
            case .boolean:
                break
            case .string(let placeholder):
                XCTAssertFalse(placeholder.isEmpty, "\(option.id) string type has empty placeholder")
            }
        }
    }

    func testOpenCodeFlagRoundTrip() throws {
        let original = CLIOptionConfig.opencodeAll.first { $0.id == "--prompt" }!
        var mutable = original
        mutable.isAvailable = true
        mutable.isDefaultEnabled = false

        let encoded = try JSONEncoder().encode(mutable)
        let decoded = try JSONDecoder().decode(CLIOptionConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, "--prompt")
        XCTAssertFalse(decoded.isUserAdded)
        XCTAssertTrue(decoded.isAvailable)
        XCTAssertFalse(decoded.isDefaultEnabled)
    }

    func testOpenCodeBooleanFlags() {
        let booleanIDs: Set<String> = ["--continue", "--fork", "--mdns"]
        for flag in opencodeOptions where booleanIDs.contains(flag.id) {
            if case .boolean = flag.optionType {} else {
                XCTFail("\(flag.id) should be boolean type")
            }
        }
    }

    func testOpenCodeStringFlags() {
        let stringIDs: Set<String> = [
            "--session", "--prompt", "--model", "--agent",
            "--port", "--hostname", "--mdns-domain", "--cors",
        ]
        for flag in opencodeOptions where stringIDs.contains(flag.id) {
            if case .string = flag.optionType {} else {
                XCTFail("\(flag.id) should be string type")
            }
        }
    }
}

final class CLITypeTests: XCTestCase {
    func testCLITypeRoundTrip() throws {
        let encoded = try JSONEncoder().encode(CLIType.codex)
        let decoded = try JSONDecoder().decode(CLIType.self, from: encoded)
        XCTAssertEqual(decoded, .codex)
    }

    func testCLITypeRawValues() {
        XCTAssertEqual(CLIType.claude.rawValue, "claude")
        XCTAssertEqual(CLIType.codex.rawValue, "codex")
        XCTAssertEqual(CLIType.cursor.rawValue, "cursor")
        XCTAssertEqual(CLIType.opencode.rawValue, "opencode")
    }

    func testCLITypeDisplayNames() {
        XCTAssertEqual(CLIType.claude.displayName, "Claude Code")
        XCTAssertEqual(CLIType.codex.displayName, "Codex")
        XCTAssertEqual(CLIType.cursor.displayName, "Cursor")
        XCTAssertEqual(CLIType.opencode.displayName, "OpenCode")
    }

    func testAllCLITypeCases() {
        XCTAssertEqual(CLIType.allCases.count, 4)
        XCTAssertTrue(CLIType.allCases.contains(.claude))
        XCTAssertTrue(CLIType.allCases.contains(.codex))
        XCTAssertTrue(CLIType.allCases.contains(.cursor))
        XCTAssertTrue(CLIType.allCases.contains(.opencode))
    }
}

final class PersistedPaneBackwardCompatTests: XCTestCase {
    func testDecodesWithoutCLITypeDefaultsToClaude() throws {
        let json = """
        {"id":"A78E5B1C-0000-0000-0000-000000000001","name":"my-pane"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertEqual(decoded.name, "my-pane")
        XCTAssertEqual(decoded.cliType, .claude)
        XCTAssertNil(decoded.worktreeDirectory)
        XCTAssertFalse(decoded.worktreeIsManaged)
    }

    func testDecodesCodexCLIType() throws {
        let json = """
        {"id":"A78E5B1C-0000-0000-0000-000000000002","name":"codex-pane","cliType":"codex"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertEqual(decoded.name, "codex-pane")
        XCTAssertEqual(decoded.cliType, .codex)
        XCTAssertNil(decoded.worktreeDirectory)
        XCTAssertFalse(decoded.worktreeIsManaged)
    }

    func testRoundTrip() throws {
        let pane = PersistedPane(id: UUID(), name: "test", cliType: .codex, isPriority: false)
        let encoded = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: encoded)
        XCTAssertEqual(decoded.name, "test")
        XCTAssertEqual(decoded.cliType, .codex)
        XCTAssertNil(decoded.worktreeDirectory)
        XCTAssertFalse(decoded.worktreeIsManaged)
    }

    func testRoundTripWithWorktreeDirectory() throws {
        let pane = PersistedPane(
            id: UUID(),
            name: "ext",
            cliType: .claude,
            worktreeDirectory: "/tmp/sibling-wt",
            worktreeIsManaged: true
        )
        let encoded = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: encoded)
        XCTAssertEqual(decoded.worktreeDirectory, "/tmp/sibling-wt")
        XCTAssertTrue(decoded.worktreeIsManaged)
    }

    func testDecodesOldClaudeProcessDirectoryFormat() throws {
        let json = """
        {"id":"A78E5B1C-0000-0000-0000-000000000010","name":"legacy-pane","claudeProcessDirectory":"/tmp/old-checkout"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertEqual(decoded.worktreeDirectory, "/tmp/old-checkout")
    }
}

final class WorktreeNameValidationTests: XCTestCase {
    func testValidNames() {
        let validNames = [
            "auth-refactor",
            "fix-login-bug",
            "feature.123",
            "my_branch",
            "UPPERCASE",
            "mixed-Case_123.branch",
            "a",
        ]
        for name in validNames {
            XCTAssertTrue(Tab.isValidWorktreeName(name), "Expected '\(name)' to be valid")
        }
    }

    func testInvalidNames() {
        let invalidNames = [
            "",
            "has space",
            "has/slash",
            "has!exclamation",
            "has@at",
            "has#hash",
            "has$dollar",
            "has%percent",
            "has^caret",
            "has&ampersand",
            "has*star",
            "has(paren",
        ]
        for name in invalidNames {
            XCTAssertFalse(Tab.isValidWorktreeName(name), "Expected '\(name)' to be invalid")
        }
    }
}

private struct DefaultBranchConfig: Codable, Equatable {
    var isEnabled: Bool = true
    var branchName: String = "main"
}

@MainActor
final class AppSettingsDefaultBranchTests: XCTestCase {
    func testDefaultBranchDefaults() {
        let settings = AppSettings()
        XCTAssertEqual(settings.defaultBranch, "main")
        XCTAssertEqual(settings.isDefaultBranchEnabled, true)
    }

    func testDefaultBranchConfigRoundTripJSON() throws {
        let config = DefaultBranchConfig(isEnabled: false, branchName: "develop")
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DefaultBranchConfig.self, from: encoded)
        XCTAssertEqual(decoded.isEnabled, false)
        XCTAssertEqual(decoded.branchName, "develop")
    }

    func testRestoreLegacyFormat() throws {
        let settings = AppSettings()
        let data = try JSONEncoder().encode("develop")
        let decoded = try JSONDecoder().decode(String.self, from: data)
        XCTAssertEqual(decoded, "develop")
        settings.defaultBranch = decoded
        settings.isDefaultBranchEnabled = true
        XCTAssertEqual(settings.defaultBranch, "develop")
        XCTAssertEqual(settings.isDefaultBranchEnabled, true)
    }

    func testRestoreEmptyStringIgnored() {
        let settings = AppSettings()
        settings.defaultBranch = "main"
        let emptyData = try! JSONEncoder().encode("")
        let decoded = try! JSONDecoder().decode(String.self, from: emptyData)
        if !decoded.isEmpty {
            settings.defaultBranch = decoded
        }
        XCTAssertEqual(settings.defaultBranch, "main")
    }

    func testToggleOffPreservesBranchName() {
        let settings = AppSettings()
        settings.defaultBranch = "develop"
        settings.isDefaultBranchEnabled = false
        XCTAssertEqual(settings.isDefaultBranchEnabled, false)
        XCTAssertEqual(settings.defaultBranch, "develop")
    }
}

@MainActor
final class AppSettingsActiveToolsTests: XCTestCase {
    func testClaudeActiveByDefault() {
        let settings = AppSettings()
        XCTAssertTrue(settings.isActive(.claude))
        XCTAssertFalse(settings.isActive(.codex))
    }

    func testSetActiveAddsRawValue() {
        let settings = AppSettings()
        settings.setActive(.codex, true)
        XCTAssertTrue(settings.isActive(.codex))
        XCTAssertTrue(settings.activeTools.contains("codex"))
    }

    func testSetInactiveRemovesRawValue() {
        let settings = AppSettings()
        settings.setActive(.claude, false)
        XCTAssertFalse(settings.isActive(.claude))
        XCTAssertFalse(settings.activeTools.contains("claude"))
    }

    func testActiveToolsRoundTripJSON() throws {
        let settings = AppSettings()
        settings.setActive(.codex, true)
        let sorted = settings.activeTools.sorted()
        let encoded = try JSONEncoder().encode(sorted)
        let decoded = try JSONDecoder().decode([String].self, from: encoded)
        XCTAssertEqual(Set(decoded), settings.activeTools)
    }

    func testRestoreDropsUnknownRawValues() {
        let settings = AppSettings()
        let knownRaws = Set(CLIType.allCases.map(\.rawValue))
        let saved: Set<String> = ["claude", "cursor", "unknowntool"]
        settings.activeTools = saved.intersection(knownRaws)
        XCTAssertTrue(settings.activeTools.contains("claude"))
        XCTAssertTrue(settings.activeTools.contains("cursor"))
        XCTAssertFalse(settings.activeTools.contains("unknowntool"))
    }
}

final class TabCommandTests: XCTestCase {
    func testBuildClaudeCommand() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/s.json", extraArgs: "")
        XCTAssertEqual(cmd, "claude --settings '/tmp/s.json'")
        XCTAssertFalse(cmd.contains("--worktree"))
    }

    func testBuildClaudeCommandWithExtraArgs() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/s.json", extraArgs: " --model claude-opus-4-7")
        XCTAssertTrue(cmd.hasSuffix("--model claude-opus-4-7"))
        XCTAssertFalse(cmd.contains("--worktree"))
    }

    func testBuildClaudeCommandEscapesSettingsQuotes() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/my's.json", extraArgs: "")
        XCTAssertTrue(cmd.contains("'/tmp/my'\\''s.json'"))
        XCTAssertFalse(cmd.contains("--worktree"))
    }

    func testBuildClaudeCommandOmitWorktreeFlag() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/s.json", extraArgs: "")
        XCTAssertEqual(cmd, "claude --settings '/tmp/s.json'")
        XCTAssertFalse(cmd.contains("--worktree"))
    }

    func testBuildClaudeCommandWithExtraArgsNoWorktree() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/s.json", extraArgs: " --verbose")
        XCTAssertTrue(cmd.hasPrefix("claude --settings '/tmp/s.json'"))
        XCTAssertTrue(cmd.hasSuffix(" --verbose"))
        XCTAssertFalse(cmd.contains("--worktree"))
    }
}

final class BranchSanitizationTests: XCTestCase {
    func testSlashesBecomeDashes() {
        let result = Tab.sanitizeBranchName("dependabot/go_modules/eligibility/go-deps-9dbd69c79b")
        XCTAssertEqual(result, "dependabot-go_modules-eligibility-go-deps-9dbd69c79b")
    }

    func testSimpleBranchPassesThrough() {
        XCTAssertEqual(Tab.sanitizeBranchName("fix-login-bug"), "fix-login-bug")
    }

    func testInvalidCharsAreStripped() {
        XCTAssertEqual(Tab.sanitizeBranchName("feature@123!"), "feature123")
    }

    func testEmptyBranchReturnsEmpty() {
        XCTAssertEqual(Tab.sanitizeBranchName(""), "")
    }

    func testSanitizedNamePassesWorktreeValidation() {
        let sanitized = Tab.sanitizeBranchName("dependabot/go_modules/eligibility/go-deps-9dbd69c79b")
        XCTAssertTrue(Tab.isValidWorktreeName(sanitized))
    }
}


final class ContinueOnRestartCommandTests: XCTestCase {
    func testBuildClaudeCommandWithContinueFlag() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/s.json", extraArgs: " --continue")
        XCTAssertTrue(cmd.contains("--continue"))
        XCTAssertTrue(cmd.hasSuffix("--continue"))
        XCTAssertFalse(cmd.contains("--worktree"))
    }

    func testBuildClaudeCommandWithoutContinueFlagWhenDisabled() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/s.json", extraArgs: "")
        XCTAssertFalse(cmd.contains("--continue"))
        XCTAssertFalse(cmd.contains("--worktree"))
    }
}

@MainActor
final class PRTrackingTests: XCTestCase {
    func testPullRequestDecode() throws {
        let json = """
        {"number": 42, "title": "Fix login bug", "state": "OPEN", "url": "https://github.com/owner/repo/pull/42"}
        """.data(using: .utf8)!
        let pr = try JSONDecoder().decode(PullRequest.self, from: json)
        XCTAssertEqual(pr.number, 42)
        XCTAssertEqual(pr.title, "Fix login bug")
        XCTAssertEqual(pr.state, "OPEN")
        XCTAssertEqual(pr.url, "https://github.com/owner/repo/pull/42")
        XCTAssertEqual(pr.id, 42)
    }

    func testPullRequestStateDisplayName() {
        let openPR = PullRequest(number: 1, title: "t", state: "OPEN", url: "https://example.com")
        XCTAssertEqual(openPR.displayState, "open")
        let mergedPR = PullRequest(number: 2, title: "t", state: "MERGED", url: "https://example.com")
        XCTAssertEqual(mergedPR.displayState, "merged")
        let closedPR = PullRequest(number: 3, title: "t", state: "CLOSED", url: "https://example.com")
        XCTAssertEqual(closedPR.displayState, "closed")
    }

    func testPullRequestDraftDisplayState() {
        let pr = PullRequest(number: 5, title: "draft pr", state: "OPEN", url: "https://example.com", isDraft: true)
        XCTAssertEqual(pr.displayState, "draft")
    }

    func testPullRequestDecodeWithStatusChecks() throws {
        let json = """
        {"number":42,"title":"Fix bug","state":"OPEN","url":"https://example.com","isDraft":true,"statusCheckRollup":[{"name":"CI","status":"COMPLETED","conclusion":"SUCCESS","detailsUrl":"https://ci.example.com"}]}
        """.data(using: .utf8)!
        let pr = try JSONDecoder().decode(PullRequest.self, from: json)
        XCTAssertEqual(pr.number, 42)
        XCTAssertEqual(pr.isDraft, true)
        XCTAssertEqual(pr.statusCheckRollup?.count, 1)
        XCTAssertEqual(pr.statusCheckRollup?.first?.name, "CI")
        XCTAssertEqual(pr.statusCheckRollup?.first?.conclusion, "SUCCESS")
    }

    func testPullRequestDecodeWithoutStatusChecks() throws {
        let json = """
        {"number":42,"title":"Fix bug","state":"OPEN","url":"https://example.com","isDraft":false,"statusCheckRollup":[]}
        """.data(using: .utf8)!
        let pr = try JSONDecoder().decode(PullRequest.self, from: json)
        XCTAssertEqual(pr.isDraft, false)
        XCTAssertEqual(pr.statusCheckRollup?.isEmpty, true)
    }

    func testBuildStatusSuccess() {
        let checks = [StatusCheck(name: "CI", status: "COMPLETED", conclusion: "SUCCESS", detailsUrl: nil)]
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u", statusCheckRollup: checks)
        XCTAssertEqual(pr.buildStatus, .success)
    }

    func testBuildStatusRunning() {
        let checks = [StatusCheck(name: "CI", status: "IN_PROGRESS", conclusion: nil, detailsUrl: nil)]
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u", statusCheckRollup: checks)
        XCTAssertEqual(pr.buildStatus, .running)
    }

    func testBuildStatusFailed() {
        let checks = [
            StatusCheck(name: "CI", status: "COMPLETED", conclusion: "SUCCESS", detailsUrl: nil),
            StatusCheck(name: "Lint", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: nil),
        ]
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u", statusCheckRollup: checks)
        XCTAssertEqual(pr.buildStatus, .failed)
    }

    func testBuildStatusCancelled() {
        let checks = [StatusCheck(name: "CI", status: "COMPLETED", conclusion: "CANCELLED", detailsUrl: nil)]
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u", statusCheckRollup: checks)
        XCTAssertEqual(pr.buildStatus, .cancelled)
    }

    func testBuildStatusUnknownWhenNil() {
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u")
        XCTAssertEqual(pr.buildStatus, .unknown)
    }

    func testBuildStatusUnknownWhenEmpty() {
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u", statusCheckRollup: [])
        XCTAssertEqual(pr.buildStatus, .unknown)
    }

    func testFailingChecks() {
        let checks = [
            StatusCheck(name: "CI", status: "COMPLETED", conclusion: "SUCCESS", detailsUrl: nil),
            StatusCheck(name: "Lint", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: nil),
            StatusCheck(name: "Test", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: nil),
        ]
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u", statusCheckRollup: checks)
        XCTAssertEqual(pr.failingChecks.count, 2)
        XCTAssertEqual(pr.failingChecks.first?.name, "Lint")
    }

    func testFailingChecksEmpty() {
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u")
        XCTAssertEqual(pr.failingChecks.count, 0)
    }

    func testBuildStatusMixedSuccessAndCancelled() {
        let checks = [
            StatusCheck(name: "CI", status: "COMPLETED", conclusion: "SUCCESS", detailsUrl: nil),
            StatusCheck(name: "Test", status: "COMPLETED", conclusion: "CANCELLED", detailsUrl: nil),
        ]
        let pr = PullRequest(number: 1, title: "t", state: "OPEN", url: "u", statusCheckRollup: checks)
        XCTAssertEqual(pr.buildStatus, .success)
    }

    func testStatusLineDataDecodeWithPR() throws {
        let json = """
        {"pr": {"number": 7, "title": "Add feature X", "state": "OPEN", "url": "https://github.com/o/r/pull/7"}}
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(data.pr?.number, 7)
        XCTAssertEqual(data.pr?.title, "Add feature X")
        XCTAssertEqual(data.pr?.state, "OPEN")
    }

    func testStatusLineDataDecodeWithoutPR() throws {
        let json = """
        {"model": {"id": "opus", "display_name": "Claude Opus"}}
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertNil(data.pr)
        XCTAssertEqual(data.model?.id, "opus")
    }

    func testAllItemsIncludesPR() {
        let items = StatusLineConfig.allItems
        XCTAssertTrue(items.contains { $0.id == "pr" })
        let prItem = items.first { $0.id == "pr" }
        XCTAssertEqual(prItem?.label, "PR")
        XCTAssertEqual(prItem?.sfSymbol, "arrow.triangle.pull")
    }

    func testItemOrderIncludesPR() {
        XCTAssertTrue(StatusLineConfig.itemOrder.contains("pr"))
    }

    func testItemMetadataIncludesPR() {
        let meta = StatusLineConfig.itemMetadata["pr"]
        XCTAssertNotNil(meta)
        XCTAssertEqual(meta?.label, "PR")
        XCTAssertEqual(meta?.symbol, "arrow.triangle.pull")
    }

    func testPRTrackingSettingsDefaultTrue() {
        let settings = AppSettings()
        XCTAssertTrue(settings.githubPRTrackingEnabled)
    }

    func testPRTrackingSettingsPersistence() throws {
        let settings = AppSettings()
        settings.githubPRTrackingEnabled = false
        SettingsPersistence.savePRTracking(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restorePRTracking(into: restored)
        XCTAssertFalse(restored.githubPRTrackingEnabled)
    }

    func testPRTrackingEnabledCheckWithoutFile() throws {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        let url = support.appending(path: "pr-tracking-settings.json")
        try? fileManager.removeItem(at: url)
        XCTAssertTrue(SettingsPersistence.isPRTrackingEnabled())
    }

    func testPRTrackingSettingsRoundTrip() throws {
        let settings = AppSettings()
        settings.githubPRTrackingEnabled = true
        SettingsPersistence.savePRTracking(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restorePRTracking(into: restored)
        XCTAssertTrue(restored.githubPRTrackingEnabled)
    }
}
