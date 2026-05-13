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

    // MARK: - CursorHookSetup

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

    @Test func testHookOutputFilePathContainsPaneID() {
        let paneID = UUID()
        let provider = CursorDataProvider(
            workingDirectory: "/tmp/test", paneID: paneID, processStartTime: Date())
        #expect(provider.hookOutputFilePath.contains(paneID.uuidString))
        #expect(provider.hookOutputFilePath.contains("agent-session-manager-cursor-hook-"))
    }

    // MARK: - StatusLineConfig availability

    @Test func testModelAvailabilityIncludesCursor() {
        let availability = StatusLineConfig.itemAvailability["model"]
        #expect(availability == .all)
    }

    @Test func testModelItemSupportedByCursor() {
        let item = StatusLineConfig.allItems.first { $0.id == "model" }
        #expect(item != nil)
        #expect(item?.supportedBy(.cursor) == true)
        #expect(item?.supportedBy(.claude) == true)
        #expect(item?.supportedBy(.opencode) == true)
        #expect(item?.supportedBy(.codex) == true)
    }

    @Test func testCostStillNotSupportedByCursor() {
        let item = StatusLineConfig.allItems.first { $0.id == "cost" }
        #expect(item != nil)
        #expect(item?.supportedBy(.cursor) == false)
    }
}
