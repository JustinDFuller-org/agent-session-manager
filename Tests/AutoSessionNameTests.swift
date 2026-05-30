import XCTest

@testable import AgentSessionManager

final class AutoSessionNameTests: XCTestCase {
    func testInjectsNameWhenEnabled() {
        let result = Tab.applyAutoSessionName(
            tabName: "my-repo",
            paneName: "auth-refactor",
            extraArgs: [],
            harness: .claude,
            enabled: true
        )
        XCTAssertEqual(result, ["--name", "'my-repo/auth-refactor'"])
    }

    func testPrependsBeforeExistingArgs() {
        let result = Tab.applyAutoSessionName(
            tabName: "repo",
            paneName: "fix",
            extraArgs: ["--dangerously-skip-permissions"],
            harness: .claude,
            enabled: true
        )
        XCTAssertEqual(result, ["--name", "'repo/fix'", "--dangerously-skip-permissions"])
    }

    func testSkipsWhenNameFlagPresent() {
        let result = Tab.applyAutoSessionName(
            tabName: "repo",
            paneName: "fix",
            extraArgs: ["--name", "'custom-name'"],
            harness: .claude,
            enabled: true
        )
        XCTAssertEqual(result, ["--name", "'custom-name'"])
    }

    func testSkipsWhenShortNameFlagPresent() {
        let result = Tab.applyAutoSessionName(
            tabName: "repo",
            paneName: "fix",
            extraArgs: ["-n", "'custom-name'"],
            harness: .claude,
            enabled: true
        )
        XCTAssertEqual(result, ["-n", "'custom-name'"])
    }

    func testSkipsWhenDisabled() {
        let result = Tab.applyAutoSessionName(
            tabName: "repo",
            paneName: "fix",
            extraArgs: ["--model", "claude-opus-4-5"],
            harness: .claude,
            enabled: false
        )
        XCTAssertEqual(result, ["--model", "claude-opus-4-5"])
    }

    func testSkipsForNonClaudeHarness() {
        let result = Tab.applyAutoSessionName(
            tabName: "repo",
            paneName: "fix",
            extraArgs: [],
            harness: .codex,
            enabled: true
        )
        XCTAssertEqual(result, [])
    }

    func testEscapesSingleQuotesInName() {
        let result = Tab.applyAutoSessionName(
            tabName: "it's",
            paneName: "fix",
            extraArgs: [],
            harness: .claude,
            enabled: true
        )
        XCTAssertEqual(result, ["--name", "'it'\\''s/fix'"])
    }

    func testNameFormat() {
        let result = Tab.applyAutoSessionName(
            tabName: "agent-session-manager",
            paneName: "session-names",
            extraArgs: [],
            harness: .claude,
            enabled: true
        )
        XCTAssertEqual(result[0], "--name")
        XCTAssertEqual(result[1], "'agent-session-manager/session-names'")
    }
}
