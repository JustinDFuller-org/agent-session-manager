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

final class CLITypeTests: XCTestCase {
    func testCLITypeRoundTrip() throws {
        let encoded = try JSONEncoder().encode(CLIType.codex)
        let decoded = try JSONDecoder().decode(CLIType.self, from: encoded)
        XCTAssertEqual(decoded, .codex)
    }

    func testCLITypeRawValues() {
        XCTAssertEqual(CLIType.claude.rawValue, "claude")
        XCTAssertEqual(CLIType.codex.rawValue, "codex")
    }

    func testCLITypeDisplayNames() {
        XCTAssertEqual(CLIType.claude.displayName, "Claude Code")
        XCTAssertEqual(CLIType.codex.displayName, "Codex")
    }

    func testAllCLITypeCases() {
        XCTAssertEqual(CLIType.allCases.count, 2)
        XCTAssertTrue(CLIType.allCases.contains(.claude))
        XCTAssertTrue(CLIType.allCases.contains(.codex))
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
        XCTAssertNil(decoded.claudeProcessDirectory)
    }

    func testDecodesCodexCLIType() throws {
        let json = """
        {"id":"A78E5B1C-0000-0000-0000-000000000002","name":"codex-pane","cliType":"codex"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertEqual(decoded.name, "codex-pane")
        XCTAssertEqual(decoded.cliType, .codex)
        XCTAssertNil(decoded.claudeProcessDirectory)
    }

    func testRoundTrip() throws {
        let pane = PersistedPane(id: UUID(), name: "test", cliType: .codex)
        let encoded = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: encoded)
        XCTAssertEqual(decoded.name, "test")
        XCTAssertEqual(decoded.cliType, .codex)
        XCTAssertNil(decoded.claudeProcessDirectory)
    }

    func testRoundTripWithClaudeProcessDirectory() throws {
        let pane = PersistedPane(
            id: UUID(),
            name: "ext",
            cliType: .claude,
            claudeProcessDirectory: "/tmp/sibling-wt"
        )
        let encoded = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: encoded)
        XCTAssertEqual(decoded.claudeProcessDirectory, "/tmp/sibling-wt")
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
        let saved: Set<String> = ["claude", "cursor"]
        settings.activeTools = saved.intersection(knownRaws)
        XCTAssertTrue(settings.activeTools.contains("claude"))
        XCTAssertFalse(settings.activeTools.contains("cursor"))
    }
}

final class TabCommandTests: XCTestCase {
    func testBuildClaudeCommandNoBranch() {
        let cmd = Tab.buildClaudeCommand(name: "auth-fix", settingsPath: "/tmp/s.json", extraArgs: "")
        XCTAssertEqual(cmd, "claude --worktree 'auth-fix' --settings '/tmp/s.json'")
        XCTAssertFalse(cmd.contains("git"))
    }

    func testBuildClaudeCommandWithExtraArgs() {
        let cmd = Tab.buildClaudeCommand(name: "fix", settingsPath: "/tmp/s.json", extraArgs: " --model claude-opus-4-7")
        XCTAssertTrue(cmd.hasSuffix("--model claude-opus-4-7"))
        XCTAssertFalse(cmd.contains("git"))
    }

    func testBuildClaudeCommandEscapesNameQuotes() {
        let cmd = Tab.buildClaudeCommand(name: "it's", settingsPath: "/tmp/s.json", extraArgs: "")
        XCTAssertTrue(cmd.contains("'it'\\''s'"))
        XCTAssertFalse(cmd.contains("git"))
    }

    func testBuildClaudeCommandEscapesSettingsQuotes() {
        let cmd = Tab.buildClaudeCommand(name: "fix", settingsPath: "/tmp/my's.json", extraArgs: "")
        XCTAssertTrue(cmd.contains("'/tmp/my'\\''s.json'"))
    }

    func testBuildClaudeCommandReuseExistingCheckoutOmitsWorktreeFlag() {
        let cmd = Tab.buildClaudeCommand(worktreeName: nil, settingsPath: "/tmp/s.json", extraArgs: "")
        XCTAssertEqual(cmd, "claude --settings '/tmp/s.json'")
        XCTAssertFalse(cmd.contains("--worktree"))
    }

    func testBuildClaudeCommandReuseCheckoutWithExtraArgs() {
        let cmd = Tab.buildClaudeCommand(worktreeName: nil, settingsPath: "/tmp/s.json", extraArgs: " --verbose")
        XCTAssertTrue(cmd.hasPrefix("claude --settings '/tmp/s.json'"))
        XCTAssertTrue(cmd.hasSuffix(" --verbose"))
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
