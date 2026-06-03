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
              updated_at_ms INTEGER,
              is_archived INTEGER
            );
            INSERT INTO threads VALUES ('old', '/repo', '/old.jsonl', 'gpt-old', '0.136.0', 3, 'main', 1000, 1000, 0);
            INSERT INTO threads VALUES ('new', '/repo', '/new.jsonl', 'gpt-5.1-codex', '0.136.2', 42, 'feature', 2300, 4000, 0);
            INSERT INTO threads VALUES ('other', '/other', '/other.jsonl', 'gpt-other', '0.136.2', 1, 'main', 5000, 5000, 0);
            """,
            at: dbURL
        )

        let selection = try CodexStateStore(databaseURL: dbURL)
            .selectThread(cwd: "/repo", processStartTime: Date(timeIntervalSince1970: 2))
        let selected = selection.thread

        XCTAssertEqual(selection.candidateCount, 2)
        XCTAssertEqual(selected?.id, "new")
        XCTAssertEqual(selected?.rolloutPath, "/new.jsonl")
        XCTAssertEqual(selected?.model, "gpt-5.1-codex")
        XCTAssertEqual(selected?.cliVersion, "0.136.2")
        XCTAssertEqual(selected?.tokensUsed, 42)
        XCTAssertEqual(selected?.gitBranch, "feature")
        XCTAssertEqual(selected?.createdAtMs, 2300)
        XCTAssertEqual(selected?.updatedAtMs, 4000)
    }

    func testStateStoreChoosesClosestSameCwdThreadInsteadOfThrowing() throws {
        let dbURL = tempDir.appending(path: "state_5.sqlite")
        try executeSQL(
            """
            CREATE TABLE threads (
              id TEXT,
              cwd TEXT,
              rollout_path TEXT,
              model TEXT,
              cli_version TEXT,
              created_at_ms INTEGER,
              updated_at_ms INTEGER,
              is_archived INTEGER
            );
            INSERT INTO threads VALUES ('near-archived', '/repo', '/archived.jsonl', 'gpt-archived', '0.136.0', 2020, 2020, 1);
            INSERT INTO threads VALUES ('near-active', '/repo', '/near.jsonl', 'gpt-near', '0.136.0', 2100, 2100, 0);
            INSERT INTO threads VALUES ('later-active', '/repo', '/later.jsonl', 'gpt-later', '0.136.0', 900000, 900000, 0);
            """,
            at: dbURL
        )

        let selection = try CodexStateStore(databaseURL: dbURL)
            .selectThread(cwd: "/repo", processStartTime: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(selection.candidateCount, 3)
        XCTAssertEqual(selection.thread?.id, "near-active")
        XCTAssertFalse(selection.thread?.isArchived ?? true)
    }

    func testStateStoreReturnsNoMatchWithCandidateCount() throws {
        let dbURL = tempDir.appending(path: "state_5.sqlite")
        try executeSQL(
            """
            CREATE TABLE threads (id TEXT, cwd TEXT, created_at_ms INTEGER, updated_at_ms INTEGER);
            INSERT INTO threads VALUES ('other', '/other', 1000, 1000);
            """,
            at: dbURL
        )

        let selection = try CodexStateStore(databaseURL: dbURL)
            .selectThread(cwd: "/repo", processStartTime: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(selection.candidateCount, 0)
        XCTAssertNil(selection.thread)
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

    func testRolloutParserMapsCodex136SessionMetaPayload() throws {
        let line = Data(
            """
            {"type":"session_meta","payload":{"cwd":"/repo","cli_version":"0.136.0","model":"gpt-5.1-codex"}}
            """.utf8)

        let data = CodexRolloutParser.parseLine(line, expectedCWD: "/repo")

        XCTAssertEqual(data?.model?.id, "gpt-5.1-codex")
        XCTAssertEqual(data?.version, "0.136.0")
    }

    func testRolloutParserMapsCodex136NestedTokenCountShape() throws {
        let line = Data(
            """
            {"type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5.1-codex","total_token_usage":{"input_tokens":320,"output_tokens":80},"model_context_window":2000},"rate_limits":{"primary":{"window_minutes":300,"used_percent":12.5,"resets_at":2000000000},"secondary":{"window_minutes":10080,"used_percent":44,"resets_at":2000003600}}}}
            """.utf8)

        let data = CodexRolloutParser.parseLine(line, expectedCWD: "/repo")

        XCTAssertEqual(data?.model?.id, "gpt-5.1-codex")
        XCTAssertEqual(data?.contextWindow?.totalInputTokens, 320)
        XCTAssertEqual(data?.contextWindow?.totalOutputTokens, 80)
        XCTAssertEqual(data?.contextWindow?.usedPercentage, 20)
        XCTAssertEqual(data?.contextWindow?.remainingPercentage, 80)
        XCTAssertEqual(data?.rateLimits?.fiveHour?.usedPercentage, 12.5)
        XCTAssertEqual(data?.rateLimits?.sevenDay?.usedPercentage, 44)
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

    func testProviderMergesBaselineAndCodexRichFactsAndTracesSelection() throws {
        TracingService.shared.resetForTesting()
        TracingService.shared.enableTestCapture()
        defer { TracingService.shared.resetForTesting() }

        try run(["git", "init"], in: tempDir)
        try "one\n".write(to: tempDir.appending(path: "tracked.txt"), atomically: true, encoding: .utf8)
        try run(["git", "add", "tracked.txt"], in: tempDir)
        try run(
            ["git", "-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init"], in: tempDir)
        try "one\ntwo\n".write(to: tempDir.appending(path: "tracked.txt"), atomically: true, encoding: .utf8)

        let rolloutURL = tempDir.appending(path: "rollout.jsonl")
        try """
        {"type":"session_meta","payload":{"cwd":"\(tempDir.path)","cli_version":"0.136.0","model":"gpt-5.1-codex"}}
        {"type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5.1-codex","total_token_usage":{"input_tokens":320,"output_tokens":80},"model_context_window":2000},"rate_limits":{"primary":{"window_minutes":300,"used_percent":12.5,"resets_at":2000000000},"secondary":{"window_minutes":10080,"used_percent":44,"resets_at":2000003600}}}}
        """.write(to: rolloutURL, atomically: true, encoding: .utf8)

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
            INSERT INTO threads VALUES ('thread-abcdef1234567890', '\(tempDir.path)', '\(rolloutURL.path)', 'gpt-5.1-codex', '0.136.0', 320, 'main', 1000, 1000);
            """,
            at: dbURL
        )

        let provider = CodexStatusProvider(
            context: StatusProviderContext(
                paneID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                paneName: "codex-pane",
                tabID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                tabName: "repo",
                workingDirectory: tempDir.path,
                harness: .codex,
                processStartTime: Date(timeIntervalSince1970: 1),
                launchArgs: [],
                environment: [:],
                detectedHarnessVersion: "0.136.0"
            ),
            stateStore: CodexStateStore(databaseURL: dbURL)
        )
        let expectation = XCTestExpectation(description: "provider emits merged Codex status")
        var observed: StatusLineData?
        provider.onUpdate = { data in
            if data.model?.id == "gpt-5.1-codex",
                data.contextWindow?.totalInputTokens == 320,
                data.rateLimits?.fiveHour?.usedPercentage == 12.5,
                data.worktree?.name == self.tempDir.lastPathComponent
            {
                observed = data
                expectation.fulfill()
            }
        }

        provider.start()
        wait(for: [expectation], timeout: 5)
        provider.stop()

        XCTAssertEqual(observed?.contextWindow?.totalOutputTokens, 80)
        XCTAssertEqual(observed?.contextWindow?.usedPercentage, 20)
        XCTAssertEqual(observed?.contextWindow?.remainingPercentage, 80)
        XCTAssertEqual(observed?.rateLimits?.sevenDay?.usedPercentage, 44)
        XCTAssertEqual(observed?.version, "0.136.0")
        XCTAssertEqual(observed?.worktree?.name, tempDir.lastPathComponent)
        XCTAssertNotNil(observed?.cost?.totalDurationMs)
        XCTAssertEqual(observed?.cost?.totalLinesAdded, 1)
        XCTAssertNil(observed?.cost?.totalCostUsd)

        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertTrue(events.contains { $0.name == "statusline.codex.state_read" })
        XCTAssertTrue(events.contains { $0.name == "statusline.codex.thread_selected" })
        XCTAssertTrue(events.contains { $0.name == "statusline.codex.tailer_started" })
        XCTAssertTrue(events.contains { $0.name == "statusline.codex.tailer_read" })
        XCTAssertTrue(
            events.contains {
                $0.name == "statusline.codex.parsed_update"
                    && $0.attributes["has_model"] == "true"
                    && $0.attributes["has_tokens"] == "true"
                    && $0.attributes["has_context"] == "true"
                    && $0.attributes["has_rate_limits"] == "true"
            })
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

    private func run(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, arguments.joined(separator: " "))
    }
}
