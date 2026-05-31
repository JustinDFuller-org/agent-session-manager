import XCTest

@testable import AgentSessionManager

final class StatusLineMonitorHookSettingsTests: XCTestCase {
    private func makeSettings(hidePRStatus: Bool = false) -> [String: Any] {
        StatusLineMonitor.makeClaudeSettingsDictionary(
            statusOutputPath: "/tmp/status.json",
            attentionOutputPath: "/tmp/attention.json",
            activityOutputPath: "/tmp/activity.json",
            hidePRStatus: hidePRStatus
        )
    }

    private func firstEntry(for event: String, in hooks: [String: Any]) throws -> [String: Any] {
        try XCTUnwrap((hooks[event] as? [[String: Any]])?.first)
    }

    func testMakeClaudeSettingsAlwaysIncludesLifecycleHooks() throws {
        let settings = makeSettings()
        let hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])

        for event in ["UserPromptSubmit", "Stop", "StopFailure"] {
            let entry = try firstEntry(for: event, in: hooks)
            let command = try XCTUnwrap((entry["hooks"] as? [[String: Any]])?.first?["command"] as? String)
            XCTAssertEqual(command, "cat > '/tmp/activity.json'")
        }
    }

    func testMakeClaudeSettingsIncludesFocusedAttentionHooks() throws {
        let hooks = try XCTUnwrap(makeSettings()["hooks"] as? [String: Any])

        XCTAssertEqual(
            try firstEntry(for: "PreToolUse", in: hooks)["matcher"] as? String,
            "AskUserQuestion|ExitPlanMode"
        )
        XCTAssertEqual(
            try firstEntry(for: "Notification", in: hooks)["matcher"] as? String,
            "permission_prompt|elicitation_dialog"
        )
        for event in ["PreToolUse", "PermissionRequest", "Notification", "Elicitation"] {
            let entry = try firstEntry(for: event, in: hooks)
            let command = try XCTUnwrap((entry["hooks"] as? [[String: Any]])?.first?["command"] as? String)
            XCTAssertEqual(command, "cat > '/tmp/attention.json'")
        }
    }

    func testMakeClaudeSettingsOmitsPRStatusFooterByDefault() {
        let settings = makeSettings()
        XCTAssertNil(settings["prStatusFooterEnabled"])
        XCTAssertNil(settings["showPRStatus"])
    }

    func testMakeClaudeSettingsIncludesPRStatusFooterFalseWhenHidden() {
        let settings = makeSettings(hidePRStatus: true)
        XCTAssertEqual(settings["prStatusFooterEnabled"] as? Bool, false)
        XCTAssertEqual(settings["showPRStatus"] as? Bool, false)
        XCTAssertNotNil(settings["hooks"])
        XCTAssertNotNil(settings["statusLine"])
    }
}
