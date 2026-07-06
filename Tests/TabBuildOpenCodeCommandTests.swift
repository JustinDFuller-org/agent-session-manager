import XCTest

@testable import AgentSessionManager

final class TabBuildOpenCodeCommandTests: XCTestCase {
    func testBuildOpenCodeCommandIncludesPortAndDefaults() {
        let command = Tab.buildOpenCodeCommand(port: 12345, extraArgs: " --model test")

        XCTAssertTrue(command.hasPrefix("opencode --hostname 127.0.0.1 --mdns=false"))
        XCTAssertTrue(command.contains(" --port 12345"))
        XCTAssertTrue(command.hasSuffix(" --model test"))
    }

    func testBuildOpenCodeCommandOmitsPortWhenNil() {
        let command = Tab.buildOpenCodeCommand(port: nil, extraArgs: " --verbose")

        XCTAssertFalse(command.contains("--port"))
        XCTAssertEqual(command, "opencode --hostname 127.0.0.1 --mdns=false --verbose")
    }

    func testBuildOpenCodeCommandNoExtraArgs() {
        let command = Tab.buildOpenCodeCommand(port: 54321, extraArgs: "")

        XCTAssertEqual(command, "opencode --hostname 127.0.0.1 --mdns=false --port 54321")
    }
}
