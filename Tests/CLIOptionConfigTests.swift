import XCTest
@testable import AgentSessionManager

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

    func testAllExpectedFlagsArePresent() {
        let actualIDs = Set(CLIOptionConfig.all.map(\.id))
        let missing = expectedFlagIDs.subtracting(actualIDs)
        XCTAssertTrue(missing.isEmpty, "Missing flags: \(missing.sorted().joined(separator: ", "))")
    }

    func testNoUnexpectedFlagsPresent() {
        let actualIDs = Set(CLIOptionConfig.all.map(\.id))
        let unexpected = actualIDs.subtracting(expectedFlagIDs)
        XCTAssertTrue(unexpected.isEmpty, "Unexpected flags: \(unexpected.sorted().joined(separator: ", "))")
    }

    func testFlagCount() {
        XCTAssertEqual(CLIOptionConfig.all.count, 62, "Expected exactly 62 CLI flags")
    }

    func testNoDuplicateIDs() {
        let ids = CLIOptionConfig.all.map(\.id)
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "Duplicate flag IDs detected")
    }

    func testAllFlagsHaveNonEmptyLabelsAndDescriptions() {
        for option in CLIOptionConfig.all {
            XCTAssertFalse(option.label.isEmpty, "\(option.id) has empty label")
            XCTAssertFalse(option.description.isEmpty, "\(option.id) has empty description")
        }
    }

    func testOptionTypeDefinedForAllFlags() {
        for option in CLIOptionConfig.all {
            switch option.optionType {
            case .boolean:
                break
            case .string(let placeholder):
                XCTAssertFalse(placeholder.isEmpty, "\(option.id) string type has empty placeholder")
            }
        }
    }
}
