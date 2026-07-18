import XCTest

@testable import AgentSessionManager

final class TabBuildOpenCodeCommandTests: XCTestCase {
    func testBuildOpenCodeCommandIncludesPortAndDefaults() {
        let command = Tab.buildOpenCodeCommand(port: 12345, extraArgs: ["--model", "test"])

        XCTAssertEqual(command.prefix(5), ["opencode", "--hostname", "127.0.0.1", "--mdns", "false"])
        XCTAssertTrue(command.contains("--port"))
        XCTAssertTrue(command.contains("12345"))
        XCTAssertTrue(command.contains("--model"))
        XCTAssertTrue(command.contains("test"))
    }

    func testBuildOpenCodeCommandOmitsPortWhenNil() {
        let command = Tab.buildOpenCodeCommand(port: nil, extraArgs: ["--verbose"])

        XCTAssertFalse(command.contains("--port"))
        XCTAssertEqual(command, ["opencode", "--hostname", "127.0.0.1", "--mdns", "false", "--verbose"])
    }

    func testBuildOpenCodeCommandNoExtraArgs() {
        let command = Tab.buildOpenCodeCommand(port: 54321, extraArgs: [])

        XCTAssertEqual(command, ["opencode", "--hostname", "127.0.0.1", "--mdns", "false", "--port", "54321"])
    }

    func testBuildOpenCodeCommandSatisfiesPortPolicy() {
        let command = Tab.buildOpenCodeCommand(port: 54321, extraArgs: ["--session", "ses_123"])

        XCTAssertTrue(command.contains("--hostname"))
        XCTAssertTrue(command.contains("127.0.0.1"))
        XCTAssertTrue(command.contains("--mdns"))
        XCTAssertTrue(command.contains("false"))
        XCTAssertTrue(command.contains("--port"))
        XCTAssertTrue(command.contains("54321"))
        XCTAssertTrue(command.contains("--session"))
        XCTAssertTrue(command.contains("ses_123"))
    }

    func testBuildOpenCodeCommandQuotesShellMetacharacters() {
        let command = Tab.buildOpenCodeCommand(port: 12345, extraArgs: ["--session", "ses_$(touch /tmp/pwned)"])

        XCTAssertTrue(command.contains("--session"))
        XCTAssertTrue(command.contains("ses_$(touch /tmp/pwned)"))
    }
}
