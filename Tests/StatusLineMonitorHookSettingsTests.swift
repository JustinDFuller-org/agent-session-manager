import XCTest
@testable import AgentSessionManager

final class StatusLineMonitorHookSettingsTests: XCTestCase {

    func testMakeClaudeSettingsOmitsHooksWhenDisabled() {
        let d = StatusLineMonitor.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            includeNotificationHook: false
        )
        XCTAssertNotNil(d["statusLine"])
        XCTAssertNil(d["hooks"])
    }

    func testMakeClaudeSettingsIncludesNotificationHookStructure() {
        let d = StatusLineMonitor.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            includeNotificationHook: true
        )
        guard let hooks = d["hooks"] as? [String: Any] else {
            XCTFail("expected hooks dictionary")
            return
        }
        guard let notification = hooks["Notification"] as? [[String: Any]] else {
            XCTFail("expected hooks.Notification array")
            return
        }
        XCTAssertEqual(notification.count, 1)
        guard let entryHooks = notification.first?["hooks"] as? [[String: Any]] else {
            XCTFail("expected entry hooks array")
            return
        }
        XCTAssertEqual(entryHooks.count, 1)
        XCTAssertEqual(entryHooks.first?["type"] as? String, "command")
        XCTAssertEqual(entryHooks.first?["command"] as? String, "cat > '/tmp/attention.json'")
    }
}
