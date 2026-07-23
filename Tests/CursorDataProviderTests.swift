import Foundation
import Testing

@testable import AgentSessionManager

@Suite("CursorDataProvider")
struct CursorDataProviderTests {
    // MARK: - CursorHookPayload parsing

    @Test func testParseValidPayload() {
        let json = Data(
            """
            {
              "conversation_id": "abc-123",
              "generation_id": "gen-456",
              "model": "claude-4.6-opus-max",
              "text": "Hello world",
              "hook_event_name": "afterAgentResponse",
              "cursor_version": "2.6.21",
              "workspace_roots": ["/tmp/test"],
              "user_email": "test@example.com"
            }
            """.utf8)
        let payload = CursorHookPayload.parse(json)
        #expect(payload != nil)
        #expect(payload?.model == "claude-4.6-opus-max")
    }

    @Test func testParseMinimalPayload() {
        let json = Data(#"{"model":"gpt-5.2"}"#.utf8)
        let payload = CursorHookPayload.parse(json)
        #expect(payload != nil)
        #expect(payload?.model == "gpt-5.2")
    }

    @Test func testParseEmptyModelReturnsNil() {
        let json = Data(#"{"model":""}"#.utf8)
        let payload = CursorHookPayload.parse(json)
        #expect(payload == nil)
    }

    @Test func testParseMissingModelReturnsNil() {
        let json = Data(#"{"conversation_id":"abc"}"#.utf8)
        let payload = CursorHookPayload.parse(json)
        #expect(payload == nil)
    }

    @Test func testParseInvalidJSONReturnsNil() {
        let json = Data("not json at all".utf8)
        let payload = CursorHookPayload.parse(json)
        #expect(payload == nil)
    }

    @Test func testParseEmptyDataReturnsNil() {
        let payload = CursorHookPayload.parse(Data())
        #expect(payload == nil)
    }

    @Test func testParseModelWithDefaultKeyword() {
        let json = Data(#"{"model":"default"}"#.utf8)
        let payload = CursorHookPayload.parse(json)
        #expect(payload != nil)
        #expect(payload?.model == "default")
    }

    @Test func testParseModelAsNonStringReturnsNil() {
        let json = Data(#"{"model":42}"#.utf8)
        let payload = CursorHookPayload.parse(json)
        #expect(payload == nil)
    }

    // MARK: - CursorHookSetup (afterAgentResponse)

    @Test func testHookScriptContentIsValidBash() {
        let content = CursorHookSetup.hookScriptContent
        #expect(content.hasPrefix("#!/bin/bash"))
        #expect(content.contains("AGENT_SESSION_MANAGER_PANE_ID"))
        #expect(content.contains("agent-session-manager-cursor-hook-"))
        #expect(content.contains("exit 0"))
    }

    @Test func testHookEntryCommandPointsToScript() {
        let command = CursorHookSetup.hookEntry["command"] as? String
        #expect(command != nil)
        #expect(command?.contains("agent-session-manager-cursor-hook.sh") == true)
    }

    @MainActor
    @Test func testHookOutputFilePathContainsPaneID() {
        let paneID = UUID()
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: paneID, processStartTime: Date())
        #expect(provider.hookOutputFilePath.contains(paneID.uuidString))
        #expect(provider.hookOutputFilePath.contains("agent-session-manager-cursor-hook-"))
    }

    // MARK: - CursorHookSetup (stop hook for notifications)

    @Test func testStopHookScriptContentIsValidBash() {
        let content = CursorHookSetup.stopHookScriptContent
        #expect(content.hasPrefix("#!/bin/bash"))
        #expect(content.contains("AGENT_SESSION_MANAGER_PANE_ID"))
        #expect(content.contains("agent-session-manager-cursor-attention-"))
        #expect(content.contains("exit 0"))
    }

    @Test func testStopHookScriptWritesToAttentionFile() {
        let content = CursorHookSetup.stopHookScriptContent
        #expect(content.contains("/tmp/agent-session-manager-cursor-attention-${AGENT_SESSION_MANAGER_PANE_ID}.json"))
    }

    @Test func testStopHookEntryCommandPointsToStopScript() {
        let command = CursorHookSetup.stopHookEntry["command"] as? String
        #expect(command != nil)
        #expect(command?.contains("agent-session-manager-cursor-stop-hook.sh") == true)
    }

    @Test func testStopHookScriptDiffersFromResponseHookScript() {
        #expect(CursorHookSetup.hookScriptContent != CursorHookSetup.stopHookScriptContent)
        #expect(CursorHookSetup.hookEntry["command"] as? String != CursorHookSetup.stopHookEntry["command"] as? String)
    }

    @Test func testLifecycleHookScriptWritesToLifecycleFile() {
        let content = CursorHookSetup.lifecycleHookScriptContent
        #expect(content.hasPrefix("#!/bin/bash"))
        #expect(content.contains("AGENT_SESSION_MANAGER_PANE_ID"))
        #expect(content.contains("agent-session-manager-cursor-lifecycle-"))
        #expect(content.contains("exit 0"))
    }

    @Test func testCursorLifecyclePayloadParsesHookEvent() {
        let payload = CursorLifecyclePayload.parse(
            Data(#"{"hook_event_name":"beforeSubmitPrompt","model":"gpt-5"}"#.utf8))
        #expect(payload?.hookEventName == "beforeSubmitPrompt")
    }

    @Test func testCursorLifecyclePayloadRejectsMissingHookEvent() {
        #expect(CursorLifecyclePayload.parse(Data(#"{"model":"gpt-5"}"#.utf8)) == nil)
    }

    @MainActor
    @Test func testAttentionFilePathContainsPaneID() {
        let paneID = UUID()
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: paneID, processStartTime: Date())
        #expect(provider.attentionFilePath.contains(paneID.uuidString))
        #expect(provider.attentionFilePath.contains("agent-session-manager-cursor-attention-"))
    }

    @MainActor
    @Test func testAttentionFilePathDiffersFromHookOutputFilePath() {
        let paneID = UUID()
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: paneID, processStartTime: Date())
        #expect(provider.attentionFilePath != provider.hookOutputFilePath)
    }

    // MARK: - Hooks config merging

    @Test func testMergeHooksConfigIntoBareConfig() throws {
        let tmpDir = NSTemporaryDirectory() + "cursor-hook-test-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let configPath = tmpDir + "hooks.json"

        let bare: [String: Any] = ["version": 1, "hooks": [String: Any]()]
        let bareData = try JSONSerialization.data(withJSONObject: bare, options: .prettyPrinted)
        try bareData.write(to: URL(filePath: configPath))

        var config =
            try JSONSerialization.jsonObject(with: Data(contentsOf: URL(filePath: configPath)))
            as! [String: Any]
        var hooks = config["hooks"] as? [String: Any] ?? [:]

        var afterEntries = hooks["afterAgentResponse"] as? [[String: Any]] ?? []
        afterEntries.append(CursorHookSetup.hookEntry)
        hooks["afterAgentResponse"] = afterEntries

        var stopEntries = hooks["stop"] as? [[String: Any]] ?? []
        stopEntries.append(CursorHookSetup.stopHookEntry)
        hooks["stop"] = stopEntries

        config["hooks"] = hooks
        let finalData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try finalData.write(to: URL(filePath: configPath))

        let reloaded =
            try JSONSerialization.jsonObject(with: Data(contentsOf: URL(filePath: configPath)))
            as! [String: Any]
        let reloadedHooks = reloaded["hooks"] as! [String: Any]

        let afterArr = reloadedHooks["afterAgentResponse"] as! [[String: Any]]
        #expect(afterArr.count == 1)
        #expect((afterArr[0]["command"] as? String)?.contains("agent-session-manager-cursor-hook.sh") == true)

        let stopArr = reloadedHooks["stop"] as! [[String: Any]]
        #expect(stopArr.count == 1)
        #expect((stopArr[0]["command"] as? String)?.contains("agent-session-manager-cursor-stop-hook.sh") == true)
    }

    @Test func testMergeDoesNotDuplicateExistingHooks() throws {
        let tmpDir = NSTemporaryDirectory() + "cursor-hook-test-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let configPath = tmpDir + "hooks.json"

        let existing: [String: Any] = [
            "version": 1,
            "hooks": [
                "afterAgentResponse": [CursorHookSetup.hookEntry],
                "stop": [CursorHookSetup.stopHookEntry],
                "afterFileEdit": [["command": "./hooks/format.sh"]],
            ] as [String: Any],
        ]
        let data = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
        try data.write(to: URL(filePath: configPath))

        var config =
            try JSONSerialization.jsonObject(with: Data(contentsOf: URL(filePath: configPath)))
            as! [String: Any]
        var hooks = config["hooks"] as? [String: Any] ?? [:]

        let afterEntries = hooks["afterAgentResponse"] as? [[String: Any]] ?? []
        let afterInstalled = afterEntries.contains {
            ($0["command"] as? String)?.contains("agent-session-manager-cursor-hook.sh") == true
        }
        #expect(afterInstalled == true)

        let stopEntries = hooks["stop"] as? [[String: Any]] ?? []
        let stopInstalled = stopEntries.contains {
            ($0["command"] as? String)?.contains("agent-session-manager-cursor-stop-hook.sh") == true
        }
        #expect(stopInstalled == true)

        let editEntries = hooks["afterFileEdit"] as? [[String: Any]] ?? []
        #expect(editEntries.count == 1)
        #expect((editEntries[0]["command"] as? String) == "./hooks/format.sh")
    }

    @Test func testMergePreservesThirdPartyHooks() throws {
        let tmpDir = NSTemporaryDirectory() + "cursor-hook-test-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let configPath = tmpDir + "hooks.json"

        let existing: [String: Any] = [
            "version": 1,
            "hooks": [
                "beforeShellExecution": [["command": "./hooks/security.sh", "failClosed": true]],
                "stop": [["command": "./hooks/audit.sh"]],
            ] as [String: Any],
        ]
        let data = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
        try data.write(to: URL(filePath: configPath))

        var config =
            try JSONSerialization.jsonObject(with: Data(contentsOf: URL(filePath: configPath)))
            as! [String: Any]
        var hooks = config["hooks"] as? [String: Any] ?? [:]

        var stopEntries = hooks["stop"] as? [[String: Any]] ?? []
        let stopInstalled = stopEntries.contains {
            ($0["command"] as? String)?.contains("agent-session-manager-cursor-stop-hook.sh") == true
        }
        if !stopInstalled {
            stopEntries.append(CursorHookSetup.stopHookEntry)
            hooks["stop"] = stopEntries
        }
        config["hooks"] = hooks

        let shellEntries = hooks["beforeShellExecution"] as? [[String: Any]] ?? []
        #expect(shellEntries.count == 1)
        #expect((shellEntries[0]["command"] as? String) == "./hooks/security.sh")

        let finalStop = hooks["stop"] as? [[String: Any]] ?? []
        #expect(finalStop.count == 2)
        #expect((finalStop[0]["command"] as? String) == "./hooks/audit.sh")
        #expect(
            (finalStop[1]["command"] as? String)?.contains("agent-session-manager-cursor-stop-hook.sh") == true)
    }

    // MARK: - StatusLineConfig availability

    @Test func testModelAvailabilityIncludesCursor() {
        let availability = StatusLineConfig.itemAvailability["model"]
        #expect(availability?.supports(.cursor) == true)
        #expect(availability?.supports(.codex) == true)
    }

    @Test func testModelItemSupportedByCursor() {
        let item = StatusLineConfig.allItems.first { $0.id == "model" }
        #expect(item != nil)
        #expect(item?.supportedBy(.cursor) == true)
        #expect(item?.supportedBy(.claude) == true)
        #expect(item?.supportedBy(.codex) == true)
    }

    @Test func testDefaultStatusLineShowsSymbols() {
        #expect(StatusLineConfig().factLabelStyle == .symbolAndLabel)
        #expect(StatusLineConfig.wizardDefault().factLabelStyle == .symbolAndLabel)
    }

    @Test func testCostStillNotSupportedByCursor() {
        let item = StatusLineConfig.allItems.first { $0.id == "cost" }
        #expect(item != nil)
        #expect(item?.supportedBy(.cursor) == false)
    }
}
