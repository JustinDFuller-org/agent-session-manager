import Foundation
import Testing

@testable import AgentSessionManager

@Suite("CursorDataProvider")
struct CursorDataProviderTests {
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

    @Test func testHookScriptContentIsValidBash() {
        let content = CursorHookSetup.hookScriptContent
        #expect(content.hasPrefix("#!/bin/bash"))
        #expect(content.contains("AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR"))
        #expect(content.contains("/hook.json"))
        #expect(content.contains("exit 0"))
    }

    @Test func testHookEntryCommandPointsToScript() {
        let command = CursorHookSetup.hookEntry.command
        #expect(command.contains("agent-session-manager-cursor-hook.sh"))
    }

    @MainActor
    @Test func testHookOutputFilePathUsesPrivateDirectory() {
        let paneID = UUID()
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: paneID, processStartTime: Date())
        #expect(provider.hookDirectoryPath != NSTemporaryDirectory())
        #expect(provider.hookDirectoryPath.contains("agent-session-manager-cursor-"))
        #expect(provider.hookOutputFilePath.hasSuffix("/hook.json"))
    }

    @Test func testStopHookScriptContentIsValidBash() {
        let content = CursorHookSetup.stopHookScriptContent
        #expect(content.hasPrefix("#!/bin/bash"))
        #expect(content.contains("AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR"))
        #expect(content.contains("/attention.json"))
        #expect(content.contains("/lifecycle.json"))
        #expect(content.contains("exit 0"))
    }

    @Test func testStopHookScriptWritesToAttentionFile() {
        let content = CursorHookSetup.stopHookScriptContent
        #expect(content.contains("$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/attention.json"))
    }

    @Test func testStopHookScriptWritesAttentionAndLifecycleFiles() throws {
        let directory = NSTemporaryDirectory() + "cursor-hook-script-\(UUID().uuidString)"
        let scriptPath = directory + "/stop.sh"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        try CursorHookSetup.stopHookScriptContent.write(
            to: URL(filePath: scriptPath), atomically: true, encoding: .utf8)

        let process = Process()
        let input = Pipe()
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = [scriptPath]
        process.environment = ["AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR": directory]
        process.standardInput = input
        try process.run()
        input.fileHandleForWriting.write(Data(#"{"hook_event_name":"stop"}"#.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        #expect(
            try String(contentsOf: URL(filePath: directory + "/attention.json"), encoding: .utf8)
                == #"{"hook_event_name":"stop"}"#)
        #expect(
            try String(contentsOf: URL(filePath: directory + "/lifecycle.json"), encoding: .utf8)
                == #"{"hook_event_name":"stop"}"#)
    }

    @Test func testStopHookEntryCommandPointsToStopScript() {
        let command = CursorHookSetup.stopHookEntry.command
        #expect(command.contains("agent-session-manager-cursor-stop-hook.sh"))
    }

    @Test func testStopHookScriptDiffersFromResponseHookScript() {
        #expect(CursorHookSetup.hookScriptContent != CursorHookSetup.stopHookScriptContent)
        #expect(CursorHookSetup.hookEntry.command != CursorHookSetup.stopHookEntry.command)
    }

    @Test func testLifecycleHookScriptWritesToLifecycleFile() {
        let content = CursorHookSetup.lifecycleHookScriptContent
        #expect(content.hasPrefix("#!/bin/bash"))
        #expect(content.contains("AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR"))
        #expect(content.contains("$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/lifecycle.json"))
        #expect(content.contains("exit 0"))
    }

    @Test func testCursorLifecyclePayloadParsesHookEvent() {
        let payload = CursorLifecyclePayload.parse(
            Data(
                """
                {"hook_event_name":"beforeSubmitPrompt","model":"gpt-5","conversation_id":"conversation-1",
                 "generation_id":"generation-1"}
                """.utf8
            ))
        #expect(payload?.hookEventName == "beforeSubmitPrompt")
        #expect(payload?.conversationID == "conversation-1")
        #expect(payload?.generationID == "generation-1")
    }

    @Test func testCursorLifecyclePayloadRejectsMissingHookEvent() {
        #expect(CursorLifecyclePayload.parse(Data(#"{"model":"gpt-5"}"#.utf8)) == nil)
    }

    @MainActor
    @Test func testAttentionFilePathUsesPrivateDirectory() {
        let paneID = UUID()
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: paneID, processStartTime: Date())
        #expect(provider.attentionFilePath.contains(provider.hookDirectoryPath))
        #expect(provider.attentionFilePath.hasSuffix("/attention.json"))
    }

    @MainActor
    @Test func testAttentionFilePathDiffersFromHookOutputFilePath() {
        let paneID = UUID()
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: paneID, processStartTime: Date())
        #expect(provider.attentionFilePath != provider.hookOutputFilePath)
        #expect(
            provider.hookEnvironmentVariables["AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR"]
                == provider.hookDirectoryPath)
    }

    @MainActor
    @Test func testCursorLifecycleIgnoresStaleGenerationStop() {
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: UUID(), processStartTime: Date())
        var states: [Bool] = []
        provider.onActivityChanged = { states.append($0) }

        provider.applyLifecyclePayload(
            CursorLifecyclePayload(
                hookEventName: "beforeSubmitPrompt",
                conversationID: "conversation-1",
                generationID: "generation-1"
            ))
        provider.applyLifecyclePayload(
            CursorLifecyclePayload(
                hookEventName: "beforeSubmitPrompt",
                conversationID: "conversation-1",
                generationID: "generation-2"
            ))
        provider.applyLifecyclePayload(
            CursorLifecyclePayload(
                hookEventName: "stop",
                conversationID: "conversation-1",
                generationID: "generation-1"
            ))

        #expect(states == [true, true])
    }

    @MainActor
    @Test func testStoppedProviderDoesNotRestartAttentionWatcher() async throws {
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: UUID(), processStartTime: Date())
        try FileManager.default.createDirectory(
            at: URL(filePath: provider.hookDirectoryPath), withIntermediateDirectories: true)

        provider.stop()
        provider.configureAttentionWatcher(enabled: true)

        try await Task.sleep(for: .milliseconds(100))
        #expect(!FileManager.default.fileExists(atPath: provider.hookDirectoryPath))
    }

    @MainActor
    @Test func testStoppingActiveAttentionWatcherCleansPrivateDirectory() async throws {
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: UUID(), processStartTime: Date())
        try FileManager.default.createDirectory(
            at: URL(filePath: provider.hookDirectoryPath), withIntermediateDirectories: true)
        provider.configureAttentionWatcher(enabled: true)
        try Data(#"{"hook_event_name":"stop"}"#.utf8)
            .write(to: URL(filePath: provider.attentionFilePath), options: .atomic)

        provider.stop()

        try await Task.sleep(for: .milliseconds(200))
        #expect(!FileManager.default.fileExists(atPath: provider.hookDirectoryPath))
    }

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
        afterEntries.append(CursorHookSetup.hookEntry.jsonObject)
        hooks["afterAgentResponse"] = afterEntries

        var stopEntries = hooks["stop"] as? [[String: Any]] ?? []
        stopEntries.append(CursorHookSetup.stopHookEntry.jsonObject)
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
                "afterAgentResponse": [CursorHookSetup.hookEntry.jsonObject],
                "stop": [CursorHookSetup.stopHookEntry.jsonObject],
                "afterFileEdit": [["command": "./hooks/format.sh"]],
            ] as [String: Any],
        ]
        let data = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
        try data.write(to: URL(filePath: configPath))

        let config =
            try JSONSerialization.jsonObject(with: Data(contentsOf: URL(filePath: configPath)))
            as! [String: Any]
        let hooks = config["hooks"] as? [String: Any] ?? [:]

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
            stopEntries.append(CursorHookSetup.stopHookEntry.jsonObject)
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
