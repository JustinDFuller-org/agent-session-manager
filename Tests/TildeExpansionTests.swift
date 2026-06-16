import XCTest

@testable import AgentSessionManager

final class TildeExpansionTests: XCTestCase {
    func testExpandsHomePath() {
        let result = Tab.expandingLeadingTilde("~/.claude/mcp/glean.json")
        XCTAssertEqual(result, NSHomeDirectory() + "/.claude/mcp/glean.json")
    }

    func testExpandsBareTilde() {
        let result = Tab.expandingLeadingTilde("~")
        XCTAssertEqual(result, NSHomeDirectory())
    }

    func testLeavesAbsolutePathUnchanged() {
        let result = Tab.expandingLeadingTilde("/etc/foo")
        XCTAssertEqual(result, "/etc/foo")
    }

    func testLeavesRelativePathUnchanged() {
        let result = Tab.expandingLeadingTilde("config/foo.json")
        XCTAssertEqual(result, "config/foo.json")
    }

    func testLeavesJSONStringUnchanged() {
        let result = Tab.expandingLeadingTilde(#"{"mcpServers":{}}"#)
        XCTAssertEqual(result, #"{"mcpServers":{}}"#)
    }

    func testLeavesEmptyStringUnchanged() {
        let result = Tab.expandingLeadingTilde("")
        XCTAssertEqual(result, "")
    }
}
