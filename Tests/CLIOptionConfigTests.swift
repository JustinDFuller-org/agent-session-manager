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
