import XCTest

@testable import AgentSessionManager

final class StatusLineMonitorHookSettingsTests: XCTestCase {
    func testMakeClaudeSettingsOmitsHooksWhenDisabled() {
        let settings = StatusLineMonitor.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            includeNotificationHook: false
        )
        XCTAssertNotNil(settings["statusLine"])
        XCTAssertNil(settings["hooks"])
    }

    func testMakeClaudeSettingsIncludesNotificationHookStructure() {
        let settings = StatusLineMonitor.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            includeNotificationHook: true
        )
        guard let hooks = settings["hooks"] as? [String: Any] else {
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

    func testMakeClaudeSettingsOmitsShowPRStatusByDefault() {
        let settings = StatusLineMonitor.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            includeNotificationHook: false
        )
        XCTAssertNil(settings["showPRStatus"])
    }

    func testMakeClaudeSettingsIncludesShowPRStatusFalseWhenHidden() {
        let settings = StatusLineMonitor.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            includeNotificationHook: false,
            hidePRStatus: true
        )
        XCTAssertEqual(settings["showPRStatus"] as? Bool, false)
    }

    func testMakeClaudeSettingsOmitsShowPRStatusWhenNotHidden() {
        let settings = StatusLineMonitor.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            includeNotificationHook: false,
            hidePRStatus: false
        )
        XCTAssertNil(settings["showPRStatus"])
    }

    func testMakeClaudeSettingsHidePRStatusCombinesWithHooks() {
        let settings = StatusLineMonitor.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            includeNotificationHook: true,
            hidePRStatus: true
        )
        XCTAssertEqual(settings["showPRStatus"] as? Bool, false)
        XCTAssertNotNil(settings["hooks"])
        XCTAssertNotNil(settings["statusLine"])
    }
}
