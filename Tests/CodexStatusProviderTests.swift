import SQLite3
import XCTest

@testable import AgentSessionManager

final class CodexStatusProviderTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-codex-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testStateStoreSelectsThreadByCwdAndProcessStart() throws {
        let dbURL = tempDir.appending(path: "state_5.sqlite")
        try executeSQL(
            """
            CREATE TABLE threads (
              id TEXT,
              cwd TEXT,
              rollout_path TEXT,
              model TEXT,
              cli_version TEXT,
              tokens_used INTEGER,
              git_branch TEXT,
              created_at_ms INTEGER,
              updated_at_ms INTEGER
            );
            INSERT INTO threads VALUES ('old', '/repo', '/old.jsonl', 'gpt-old', '0.136.0', 3, 'main', 1000, 1000);
            INSERT INTO threads VALUES ('new', '/repo', '/new.jsonl', 'gpt-5.1-codex', '0.136.2', 42, 'feature', 3000, 4000);
            INSERT INTO threads VALUES ('other', '/other', '/other.jsonl', 'gpt-other', '0.136.2', 1, 'main', 5000, 5000);
            """,
            at: dbURL
        )

        let selected = try CodexStateStore(databaseURL: dbURL)
            .selectThread(cwd: "/repo", processStartTime: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(selected?.id, "new")
        XCTAssertEqual(selected?.rolloutPath, "/new.jsonl")
        XCTAssertEqual(selected?.model, "gpt-5.1-codex")
        XCTAssertEqual(selected?.cliVersion, "0.136.2")
        XCTAssertEqual(selected?.tokensUsed, 42)
        XCTAssertEqual(selected?.gitBranch, "feature")
    }

    func testStateStoreReportsMissingSchema() throws {
        let dbURL = tempDir.appending(path: "missing.sqlite")
        try executeSQL("CREATE TABLE other (id TEXT);", at: dbURL)

        XCTAssertThrowsError(
            try CodexStateStore(databaseURL: dbURL)
                .selectThread(cwd: "/repo", processStartTime: Date())
        ) { error in
            XCTAssertEqual(error as? CodexStateStoreError, .schemaUnavailable)
        }
    }

    func testRolloutParserMapsTokenCountAndRateLimits() throws {
        let line = Data(
            """
            {"type":"event_msg","payload":{"type":"token_count","model":"gpt-5.1-codex","total_token_usage":{"input_tokens":300,"output_tokens":100},"model_context_window":1000,"rate_limits":{"primary":{"window_minutes":300,"used_percentage":25,"resets_at":2000000000},"secondary":{"window_minutes":10080,"used_percentage":50,"resets_at":2000003600}}}}
            """.utf8)

        let data = CodexRolloutParser.parseLine(line, expectedCWD: "/repo")

        XCTAssertEqual(data?.model?.id, "gpt-5.1-codex")
        XCTAssertEqual(data?.contextWindow?.totalInputTokens, 300)
        XCTAssertEqual(data?.contextWindow?.totalOutputTokens, 100)
        XCTAssertEqual(data?.contextWindow?.usedPercentage, 40)
        XCTAssertEqual(data?.contextWindow?.remainingPercentage, 60)
        XCTAssertEqual(data?.rateLimits?.fiveHour?.usedPercentage, 25)
        XCTAssertEqual(data?.rateLimits?.fiveHour?.resetsAt, 2_000_000_000)
        XCTAssertEqual(data?.rateLimits?.sevenDay?.usedPercentage, 50)
        XCTAssertEqual(data?.rateLimits?.sevenDay?.resetsAt, 2_000_003_600)
    }

    func testRolloutParserIgnoresContentRecords() {
        let line = Data(#"{"type":"event_msg","payload":{"type":"agent_message","message":"secret"}}"#.utf8)
        XCTAssertNil(CodexRolloutParser.parseLine(line, expectedCWD: "/repo"))
    }

    func testVersionAdapterRejectsUnknownCodexVersions() {
        XCTAssertTrue(CodexVersionAdapter.supports("codex 0.136.2"))
        XCTAssertFalse(CodexVersionAdapter.supports("codex 0.137.0"))
        XCTAssertFalse(CodexVersionAdapter.supports(nil))
    }

    func testCapabilityFilteringSupportsCodexTokensButNotCost() {
        let cost = StatusLineItem(id: "cost", label: "Cost", sfSymbol: "dollarsign.circle")
        let input = StatusLineItem(id: "inputTokens", label: "Input Tokens", sfSymbol: "arrow.down.circle")
        let context = StatusLineItem(id: "context", label: "Context %", sfSymbol: "gauge.with.needle")

        XCTAssertFalse(cost.supportedBy(.codex))
        XCTAssertTrue(input.supportedBy(.codex))
        XCTAssertTrue(context.supportedBy(.codex))
    }

    private func executeSQL(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw NSError(domain: "SQLiteTest", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
