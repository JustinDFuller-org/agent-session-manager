import XCTest

@testable import AgentSessionManager

final class StatusLineDataDecodingTests: XCTestCase {
    func testDecodeContextWindowSize() throws {
        let json = Data(
            """
            {"context_window": {"context_window_size": 200000, "used_percentage": 10}}
            """.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(data.contextWindow?.contextWindowSize, 200000)
    }

    func testDecodeContextWindowSizeAsDouble() throws {
        let json = Data(
            """
            {"context_window": {"context_window_size": 200000.0}}
            """.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(data.contextWindow?.contextWindowSize, 200000)
    }

    func testDecodeCurrentUsageCacheReadTokens() throws {
        let json = Data(
            """
            {"context_window": {"current_usage": {"cache_read_input_tokens": 1234, "cache_creation_input_tokens": 567, "input_tokens": 8000, "output_tokens": 200}}}
            """.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(data.contextWindow?.currentUsage?.cacheReadInputTokens, 1234)
        XCTAssertEqual(data.contextWindow?.currentUsage?.cacheCreationInputTokens, 567)
        XCTAssertEqual(data.contextWindow?.currentUsage?.inputTokens, 8000)
        XCTAssertEqual(data.contextWindow?.currentUsage?.outputTokens, 200)
    }

    func testDecodeCurrentUsageMissingIsNil() throws {
        let json = Data(
            """
            {"context_window": {"used_percentage": 50}}
            """.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertNil(data.contextWindow?.currentUsage)
    }

    func testDecodeTotalApiDurationMs() throws {
        let json = Data(
            """
            {"cost": {"total_api_duration_ms": 5432.1}}
            """.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(data.cost?.totalApiDurationMs, 5432.1)
    }

    func testDecodeTotalApiDurationMsMissing() throws {
        let json = Data(
            """
            {"cost": {"total_cost_usd": 0.01}}
            """.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertNil(data.cost?.totalApiDurationMs)
    }

    func testNewFactIdsExistInMetadata() {
        for id in ["repo", "contextSize", "cacheRead", "cacheCreation", "apiDuration"] {
            XCTAssertNotNil(StatusLineConfig.itemMetadata[id], "Missing metadata for \(id)")
        }
    }

    func testNewFactIdsExistInItemOrder() {
        let order = StatusLineConfig.itemOrder
        for id in ["repo", "contextSize", "cacheRead", "cacheCreation", "apiDuration"] {
            XCTAssertTrue(order.contains(id), "Missing \(id) from itemOrder")
        }
    }

    func testAllItemsIncludesNewFacts() {
        let allIDs = Set(StatusLineConfig.allItems.map(\.id))
        for id in ["repo", "contextSize", "cacheRead", "cacheCreation", "apiDuration"] {
            XCTAssertTrue(allIDs.contains(id), "allItems missing \(id)")
        }
    }

    func testRepoIsGlobalCapability() {
        let cap = StatusLineConfig.itemCapabilities["repo"]
        XCTAssertEqual(cap?.owner, .app)
        XCTAssertTrue(cap?.supportedHarnesses.contains(.claude) ?? false)
        XCTAssertTrue(cap?.supportedHarnesses.contains(.codex) ?? false)
        XCTAssertTrue(cap?.supportedHarnesses.contains(.cursor) ?? false)
    }

    func testContextSizeIsClaudeOnly() {
        let cap = StatusLineConfig.itemCapabilities["contextSize"]
        XCTAssertTrue(cap?.supportedHarnesses.contains(.claude) ?? false)
        XCTAssertFalse(cap?.supportedHarnesses.contains(.codex) ?? true)
        XCTAssertFalse(cap?.supportedHarnesses.contains(.cursor) ?? true)
    }

    func testCacheReadIsClaudeOnly() {
        let cap = StatusLineConfig.itemCapabilities["cacheRead"]
        XCTAssertTrue(cap?.supportedHarnesses.contains(.claude) ?? false)
        XCTAssertFalse(cap?.supportedHarnesses.contains(.codex) ?? true)
        XCTAssertFalse(cap?.supportedHarnesses.contains(.cursor) ?? true)
    }

    func testCacheCreationIsClaudeOnly() {
        let cap = StatusLineConfig.itemCapabilities["cacheCreation"]
        XCTAssertTrue(cap?.supportedHarnesses.contains(.claude) ?? false)
        XCTAssertFalse(cap?.supportedHarnesses.contains(.codex) ?? true)
        XCTAssertFalse(cap?.supportedHarnesses.contains(.cursor) ?? true)
    }

    func testApiDurationIsClaudeOnly() {
        let cap = StatusLineConfig.itemCapabilities["apiDuration"]
        XCTAssertTrue(cap?.supportedHarnesses.contains(.claude) ?? false)
        XCTAssertFalse(cap?.supportedHarnesses.contains(.codex) ?? true)
        XCTAssertFalse(cap?.supportedHarnesses.contains(.cursor) ?? true)
    }

    func testDecodePrBlockSucceeds() throws {
        let json = Data(
            """
            {"model": {"id": "claude-sonnet-4-6"}, "pr": {"number": 42, "url": "https://github.com/org/repo/pull/42", "review_state": "draft"}}
            """.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(data.model?.id, "claude-sonnet-4-6")
    }

    func testDecodePrBlockYieldsNilPr() throws {
        let json = Data(
            """
            {"pr": {"number": 42, "url": "https://github.com/org/repo/pull/42", "review_state": "approved"}}
            """.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertNil(data.pr)
    }

    func testCustomFieldsAbsentByDefault() throws {
        let json = Data(#"{"model": {"id": "claude-sonnet-4-6"}}"#.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertNil(data.customFields)
    }

    func testCustomFieldsCannotBeSpoofedByHarnessPayload() throws {
        let json = Data(#"{"customFields": {"custom:x": {"text": "spoofed"}}}"#.utf8)
        let data = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertNil(data.customFields)
    }
}
