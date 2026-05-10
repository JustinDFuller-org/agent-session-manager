import Testing
import Foundation
@testable import AgentSessionManager

@Suite("OpenCodeDataProvider")
struct OpenCodeDataProviderTests {

    // MARK: - parsePort

    @Test func testParsePortValidConfig() {
        let json = #"{"server":{"port":5000}}"#.data(using: .utf8)!
        #expect(OpenCodeDataProvider.parsePort(from: json) == 5000)
    }

    @Test func testParsePortMissingServerField() {
        let json = #"{"other":"value"}"#.data(using: .utf8)!
        #expect(OpenCodeDataProvider.parsePort(from: json) == nil)
    }

    @Test func testParsePortMissingPortField() {
        let json = #"{"server":{"hostname":"localhost"}}"#.data(using: .utf8)!
        #expect(OpenCodeDataProvider.parsePort(from: json) == nil)
    }

    @Test func testParsePortInvalidJSON() {
        let data = "not json at all".data(using: .utf8)!
        #expect(OpenCodeDataProvider.parsePort(from: data) == nil)
    }

    // MARK: - aggregateMessages

    @Test func testAggregateMessagesEmpty() {
        let result = OpenCodeDataProvider.aggregateMessages([])
        #expect(result.inputTokens == 0)
        #expect(result.outputTokens == 0)
        #expect(result.cost == 0.0)
        #expect(result.mode == nil)
    }

    @Test func testAggregateMessagesSingleWithAllFields() {
        let msg = OpenCodeMessage(
            role: "assistant",
            mode: "code",
            tokens: OpenCodeMessage.MessageTokens(input: 100, output: 50),
            cost: 0.01
        )
        let result = OpenCodeDataProvider.aggregateMessages([msg])
        #expect(result.inputTokens == 100)
        #expect(result.outputTokens == 50)
        #expect(result.cost == 0.01)
        #expect(result.mode == "code")
    }

    @Test func testAggregateMessagesSkipsNilTokens() {
        let msgs = [
            OpenCodeMessage(role: "user", mode: nil, tokens: nil, cost: nil),
            OpenCodeMessage(role: "assistant", mode: "ask", tokens: OpenCodeMessage.MessageTokens(input: 200, output: 80), cost: 0.02),
        ]
        let result = OpenCodeDataProvider.aggregateMessages(msgs)
        #expect(result.inputTokens == 200)
        #expect(result.outputTokens == 80)
        #expect(result.cost == 0.02)
        #expect(result.mode == "ask")
    }

    @Test func testAggregateMessagesMultiple() {
        let msgs = [
            OpenCodeMessage(role: "assistant", mode: "code", tokens: OpenCodeMessage.MessageTokens(input: 100, output: 50), cost: 0.01),
            OpenCodeMessage(role: "assistant", mode: "architect", tokens: OpenCodeMessage.MessageTokens(input: 200, output: 100), cost: 0.02),
            OpenCodeMessage(role: "assistant", mode: "ask", tokens: OpenCodeMessage.MessageTokens(input: 300, output: 150), cost: 0.03),
        ]
        let result = OpenCodeDataProvider.aggregateMessages(msgs)
        #expect(result.inputTokens == 600)
        #expect(result.outputTokens == 300)
        #expect(result.cost == 0.06)
        #expect(result.mode == "ask")
    }

    @Test func testAggregateMessagesLastModeWins() {
        let msgs = [
            OpenCodeMessage(role: "assistant", mode: "code", tokens: nil, cost: nil),
            OpenCodeMessage(role: "assistant", mode: "architect", tokens: nil, cost: nil),
        ]
        let result = OpenCodeDataProvider.aggregateMessages(msgs)
        #expect(result.mode == "architect")
    }

    // MARK: - mapStatus

    @Test func testMapStatusIdle() {
        let dict = ["abc": SessionStatusEntry(type: "idle")]
        #expect(OpenCodeDataProvider.mapStatus(dict, sessionID: "abc") == "idle")
    }

    @Test func testMapStatusBusy() {
        let dict = ["session1": SessionStatusEntry(type: "busy")]
        #expect(OpenCodeDataProvider.mapStatus(dict, sessionID: "session1") == "busy")
    }

    @Test func testMapStatusMissingSessionID() {
        let dict = ["other": SessionStatusEntry(type: "idle")]
        #expect(OpenCodeDataProvider.mapStatus(dict, sessionID: "missing") == nil)
    }

    @Test func testMapStatusEmptyDict() {
        #expect(OpenCodeDataProvider.mapStatus([:], sessionID: "abc") == nil)
    }

    // MARK: - StatusLineData round-trips

    @Test func testSessionStatusRoundTrip() throws {
        let original = StatusLineData.SessionStatus(state: "busy")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StatusLineData.SessionStatus.self, from: encoded)
        #expect(decoded.state == "busy")
    }

    @Test func testOpenCodeModeDecodesFromJSON() throws {
        let json = #"{"open_code_mode":"architect"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StatusLineData.self, from: json)
        #expect(decoded.openCodeMode == "architect")
    }

    @Test func testSessionStatusDecodesFromJSON() throws {
        let json = #"{"session_status":{"state":"retry"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StatusLineData.self, from: json)
        #expect(decoded.sessionStatus?.state == "retry")
    }

    @Test func testNewFieldsAreNilWhenAbsentFromJSON() throws {
        let json = #"{"version":"1.0"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StatusLineData.self, from: json)
        #expect(decoded.sessionStatus == nil)
        #expect(decoded.openCodeMode == nil)
    }
}
