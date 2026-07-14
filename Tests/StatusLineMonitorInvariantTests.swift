import XCTest

@testable import AgentSessionManager

@MainActor
final class StatusLineMonitorInvariantTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TracingService.shared.enableTestCapture()
        InvariantReporter.shared.enableTestCapture()
    }

    override func tearDown() {
        super.tearDown()
        TracingService.shared.resetForTesting()
        InvariantReporter.shared.resetForTesting()
    }

    // MARK: - I2 Migration

    func testMigrationDropsWorktreeBranchWhenWorktreePresent() throws {
        let json = Data(
            """
            {
                "rows": [
                    {
                        "id": "33333333-3333-3333-3333-333333333333",
                        "items": [
                            {"id": "worktree", "label": "Worktree", "sfSymbol": "folder.badge.gearshape"},
                            {"id": "worktreeBranch", "label": "Worktree Branch", "sfSymbol": "arrow.branch"}
                        ]
                    }
                ],
                "factLabelStyle": "labelOnly",
                "rowAlignment": "leading"
            }
            """.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertFalse(config.usedItemIDs.contains("worktreeBranch"), "worktreeBranch must be migrated out")
        XCTAssertTrue(config.usedItemIDs.contains("worktree"))
        let events = TracingService.shared.recordedEventsForTesting
        let event = events.first { $0.name == "statusline.migration.worktreebranch_merged" }
        XCTAssertNotNil(event, "Expected migration trace event")
        XCTAssertEqual(event?.attributes["substituted"], "false")
        XCTAssertEqual(event?.attributes["row_index"], "0")
    }

    func testMigrationSubstitutesWorktreeBranchWhenWorktreeAbsent() throws {
        let json = Data(
            """
            {
                "rows": [
                    {
                        "id": "44444444-4444-4444-4444-444444444444",
                        "items": [
                            {"id": "model", "label": "Model", "sfSymbol": "cpu"},
                            {"id": "worktreeBranch", "label": "Worktree Branch", "sfSymbol": "arrow.branch"}
                        ]
                    }
                ],
                "factLabelStyle": "labelOnly",
                "rowAlignment": "leading"
            }
            """.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertFalse(config.usedItemIDs.contains("worktreeBranch"), "worktreeBranch must be migrated out")
        XCTAssertTrue(config.usedItemIDs.contains("worktree"), "worktree must be substituted in")
        XCTAssertTrue(config.usedItemIDs.contains("model"))
        let events = TracingService.shared.recordedEventsForTesting
        let event = events.first { $0.name == "statusline.migration.worktreebranch_merged" }
        XCTAssertNotNil(event, "Expected migration trace event")
        XCTAssertEqual(event?.attributes["substituted"], "true")
        XCTAssertEqual(event?.attributes["row_index"], "0")
        XCTAssertEqual(event?.attributes["position"], "1")
    }

    func testMigrationDropsGitWorktreeAndTraces() throws {
        let json = Data(
            """
            {
                "rows": [
                    {
                        "id": "22222222-2222-2222-2222-222222222222",
                        "items": [
                            {"id": "model", "label": "Model", "sfSymbol": "cpu"},
                            {"id": "gitWorktree", "label": "Git Worktree", "sfSymbol": "internaldrive"}
                        ]
                    }
                ],
                "factLabelStyle": "labelOnly",
                "rowAlignment": "leading"
            }
            """.utf8)
        let config = try JSONDecoder().decode(StatusLineConfig.self, from: json)
        XCTAssertFalse(config.usedItemIDs.contains("gitWorktree"))
        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertTrue(events.contains { $0.name == "statusline.migration.gitworktree_dropped" })
    }

    // MARK: - I1: Worktree Name

    func testI1WorktreeNameMismatchIsLogged() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("right-name")
            .path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let paneID = UUID()
        let monitor = StatusLineMonitor(
            paneID: paneID,
            workingDirectory: workDir,
            harness: .claude
        )

        let json = Data(
            """
            {"worktree": {"name": "wrong-name", "branch": "main"}}
            """.utf8)
        let parsed = try JSONDecoder().decode(StatusLineData.self, from: json)
        var enforced = parsed

        monitor.testApplyI1Enforcement(to: &enforced)

        XCTAssertEqual(enforced.worktree?.name, "right-name")
        let events = TracingService.shared.recordedEventsForTesting
        let mismatch = events.first { $0.name == "statusline.worktree.name_mismatch" }
        XCTAssertNotNil(mismatch, "Expected worktree.name_mismatch trace event")
        XCTAssertEqual(mismatch?.attributes["field"], "worktree.name")
        XCTAssertEqual(mismatch?.attributes["computed"], "right-name")
        XCTAssertEqual(mismatch?.attributes["reported"], "wrong-name")
        XCTAssertEqual(mismatch?.attributes["invariant.id"], "statusline.worktree.name")
    }

    func testI1WorktreeNameMatchDoesNotLog() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("right-name")
            .path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(
            paneID: UUID(),
            workingDirectory: workDir,
            harness: .claude
        )

        let json = Data(
            """
            {"worktree": {"name": "right-name", "branch": "main"}}
            """.utf8)
        let parsed = try JSONDecoder().decode(StatusLineData.self, from: json)
        var enforced = parsed

        monitor.testApplyI1Enforcement(to: &enforced)

        XCTAssertEqual(enforced.worktree?.name, "right-name")
        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertFalse(events.contains { $0.name == "statusline.worktree.name_mismatch" })
    }

    func testI1WorkspaceGitWorktreeMismatchIsLogged() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("right-name")
            .path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(
            paneID: UUID(),
            workingDirectory: workDir,
            harness: .claude
        )

        let json = Data(
            """
            {"workspace": {"git_worktree": "/some/completely/different-name"}}
            """.utf8)
        let parsed = try JSONDecoder().decode(StatusLineData.self, from: json)
        var enforced = parsed

        monitor.testApplyI1Enforcement(to: &enforced)

        let events = TracingService.shared.recordedEventsForTesting
        let mismatch = events.first {
            $0.name == "statusline.worktree.name_mismatch" && $0.attributes["field"] == "workspace.git_worktree"
        }
        XCTAssertNotNil(mismatch, "Expected workspace.git_worktree mismatch event")
        XCTAssertEqual(mismatch?.attributes["computed"], "right-name")
        XCTAssertEqual(mismatch?.attributes["invariant.id"], "statusline.worktree.name")
    }

    // MARK: - I3: Lines Added/Removed

    func testI3LinesMismatchIsLoggedAndOverwritten() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(
            paneID: UUID(),
            workingDirectory: workDir,
            harness: .claude
        )
        monitor.testSetCachedGitStats((added: 5, removed: 0))

        let json = Data(
            """
            {"cost": {"total_cost_usd": 0.01, "total_duration_ms": 1000, "total_lines_added": 999, "total_lines_removed": 0}}
            """.utf8)
        let parsed = try JSONDecoder().decode(StatusLineData.self, from: json)
        var enforced = parsed

        monitor.testApplyI3Enforcement(to: &enforced)

        XCTAssertEqual(enforced.cost?.totalLinesAdded, 5)
        XCTAssertEqual(enforced.cost?.totalLinesRemoved, 0)

        let events = TracingService.shared.recordedEventsForTesting
        let mismatch = events.first { $0.name == "statusline.lines.source_mismatch" }
        XCTAssertNotNil(mismatch, "Expected lines.source_mismatch trace event")
        XCTAssertEqual(mismatch?.attributes["invariant.id"], "statusline.lines.source")
        XCTAssertEqual(mismatch?.attributes["computed_added"], "5")
        XCTAssertEqual(mismatch?.attributes["reported_added"], "999")
        XCTAssertEqual(mismatch?.attributes["computed_removed"], "0")
        XCTAssertEqual(mismatch?.attributes["reported_removed"], "0")
    }

    // MARK: - I6: Liveness

    func testI6FreshnessRecoveryAppliesLatestPayload() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        let earlyPayload = Data(
            """
            {"cost": {"total_cost_usd": 0.0}}
            """.utf8)
        try earlyPayload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "initial")
        XCTAssertEqual(monitor.currentData?.cost?.totalCostUsd, 0.0)

        // Simulate Claude writing a newer payload without firing the vnode handler
        let laterPayload = Data(
            """
            {"cost": {"total_cost_usd": 5.28}, "context_window": {"used_percentage": 8}}
            """.utf8)
        try laterPayload.write(to: URL(filePath: monitor.filePath))
        // Force mtime to be strictly newer
        let future = Date().addingTimeInterval(1)
        try FileManager.default.setAttributes([.modificationDate: future], ofItemAtPath: monitor.filePath)

        monitor.testCheckPayloadFreshness()

        XCTAssertEqual(monitor.currentData?.cost?.totalCostUsd, 5.28)
        XCTAssertEqual(monitor.currentData?.contextWindow?.usedPercentage, 8)

        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertTrue(
            events.contains { $0.name == "statusline.payload.stale_recovered" },
            "Expected stale_recovered trace event")
        XCTAssertTrue(
            events.contains {
                $0.name == "statusline.payload.applied" && $0.attributes["reason"] == "freshness_recovery"
            },
            "Expected applied event with reason freshness_recovery")
    }

    func testI6FreshnessNoRecoveryWhenUpToDate() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        let payload = Data(
            """
            {"cost": {"total_cost_usd": 1.23}}
            """.utf8)
        try payload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "initial")
        TracingService.shared.resetForTesting()

        // Freshness check with no new writes — should be a no-op
        monitor.testCheckPayloadFreshness()

        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertFalse(
            events.contains { $0.name == "statusline.payload.stale_recovered" },
            "stale_recovered must not fire when already up to date")
    }

    // MARK: - I7: Integrity

    func testI7ValidPayloadRecordsApplied() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        let payload = Data(
            """
            {"cost": {"total_cost_usd": 2.50}, "context_window": {"used_percentage": 15}}
            """.utf8)
        try payload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "test")

        XCTAssertNotNil(monitor.currentData)
        XCTAssertEqual(monitor.currentData?.cost?.totalCostUsd, 2.50)

        let events = TracingService.shared.recordedEventsForTesting
        let applied = events.first { $0.name == "statusline.payload.applied" }
        XCTAssertNotNil(applied, "Expected payload.applied trace event")
        XCTAssertEqual(applied?.attributes["reason"], "test")
        XCTAssertEqual(applied?.attributes["cost_usd"], "2.5000")
        XCTAssertEqual(applied?.attributes["used_pct"], "15")
        XCTAssertFalse(events.contains { $0.name == "statusline.payload.decode_failed" })
    }

    func testI7MalformedPayloadRecordsDecodeFailedAndPreservesState() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        // Apply a good payload first so currentData has a known value
        let good = Data(
            """
            {"cost": {"total_cost_usd": 1.00}}
            """.utf8)
        try good.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "initial")
        TracingService.shared.resetForTesting()
        TracingService.shared.enableTestCapture()

        let bad = Data("NOT JSON AT ALL !!!".utf8)
        try bad.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "test")

        // currentData must be preserved from the last good payload
        XCTAssertEqual(monitor.currentData?.cost?.totalCostUsd, 1.00)

        let events = TracingService.shared.recordedEventsForTesting
        let failed = events.first { $0.name == "statusline.payload.decode_failed" }
        XCTAssertNotNil(failed, "Expected payload.decode_failed trace event")
        XCTAssertEqual(failed?.attributes["reason"], "test")
        XCTAssertEqual(failed?.attributes["decoding_error_kind"], "data_corrupted")
        XCTAssertFalse(events.contains { $0.name == "statusline.payload.applied" })
    }

    func testI7DecodingErrorNamesField() async throws {
        // A payload with a present but incomplete `repo` object causes keyNotFound on a required field.
        // Verifies that coding_path and missing_key are recorded in the trace.
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        let payload = Data(#"{"repo": {"host": "github.com"}}"#.utf8)
        try payload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "test")

        let events = TracingService.shared.recordedEventsForTesting
        let failed = events.first { $0.name == "statusline.payload.decode_failed" }
        XCTAssertNotNil(failed, "Expected decode_failed event")
        XCTAssertEqual(failed?.attributes["decoding_error_kind"], "key_not_found")
        XCTAssertNotNil(failed?.attributes["coding_path"])
        XCTAssertNotNil(failed?.attributes["missing_key"])
    }

    func testI7PayloadWithClaudePrBlockAppliesSuccessfully() async throws {
        // Claude sends pr:{number,url,review_state} — never title/state. Before the fix, this
        // caused keyNotFound on title/state and dropped the entire payload, freezing the status line.
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        let payload = Data(
            """
            {"model": {"id": "claude-sonnet-4-6"}, "pr": {"number": 42, "url": "https://github.com/org/repo/pull/42", "review_state": "draft"}}
            """.utf8)
        try payload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "test")

        XCTAssertEqual(monitor.currentData?.model?.id, "claude-sonnet-4-6")
        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertTrue(events.contains { $0.name == "statusline.payload.applied" })
        XCTAssertFalse(events.contains { $0.name == "statusline.payload.decode_failed" })
    }

    func testI7GhPrDataPreservedWhenClaudeSendsPrBlock() async throws {
        // After PRTrackingCoordinator (gh) seeds pr data, a Claude payload with a pr block
        // must not overwrite it — pr is owned by gh and set post-apply.
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        let ghPR = Data(
            """
            {"number": 7, "title": "My feature", "state": "open", "url": "https://github.com/org/repo/pull/7"}
            """.utf8)
        monitor.simulatePRUpdateForTesting(ghPR)

        let claudePayload = Data(
            """
            {"model": {"id": "claude-sonnet-4-6"}, "pr": {"number": 7, "url": "https://github.com/org/repo/pull/7", "review_state": "approved"}}
            """.utf8)
        try claudePayload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "test")

        XCTAssertEqual(monitor.currentData?.pr?.title, "My feature")
        XCTAssertEqual(monitor.currentData?.pr?.state, "open")
        XCTAssertEqual(monitor.currentData?.model?.id, "claude-sonnet-4-6")
    }

    func testI7EmptyFileSkippedWithoutClobbering() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        let good = Data(
            """
            {"cost": {"total_cost_usd": 3.75}}
            """.utf8)
        try good.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "initial")
        TracingService.shared.resetForTesting()

        try Data().write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "empty")

        XCTAssertEqual(monitor.currentData?.cost?.totalCostUsd, 3.75, "empty write must not clobber currentData")
        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertFalse(events.contains { $0.name == "statusline.payload.decode_failed" })
        XCTAssertFalse(events.contains { $0.name == "statusline.payload.applied" })
    }

    func testI7ContextWindowToleratesDoublePercentage() throws {
        // 14.000000000000002 is the real-world case from rate_limits; truncates to 14
        // 85.999999999999998 rounds to 86.0 in IEEE 754 double, so Int(86.0) == 86
        let json = Data(
            """
            {"context_window": {"used_percentage": 14.000000000000002, "remaining_percentage": 85.999999999999998, "total_input_tokens": 140000, "total_output_tokens": 5}}
            """.utf8)
        let parsed = try JSONDecoder().decode(StatusLineData.self, from: json)
        XCTAssertEqual(parsed.contextWindow?.usedPercentage, 14)
        XCTAssertEqual(parsed.contextWindow?.remainingPercentage, 86)
        XCTAssertEqual(parsed.contextWindow?.totalInputTokens, 140000)
        XCTAssertEqual(parsed.contextWindow?.totalOutputTokens, 5)
    }

    func testI3LinesMatchDoesNotLog() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(
            paneID: UUID(),
            workingDirectory: workDir,
            harness: .claude
        )
        monitor.testSetCachedGitStats((added: 3, removed: 1))

        let json = Data(
            """
            {"cost": {"total_cost_usd": 0.01, "total_duration_ms": 1000, "total_lines_added": 3, "total_lines_removed": 1}}
            """.utf8)
        let parsed = try JSONDecoder().decode(StatusLineData.self, from: json)
        var enforced = parsed

        monitor.testApplyI3Enforcement(to: &enforced)

        XCTAssertEqual(enforced.cost?.totalLinesAdded, 3)
        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertFalse(events.contains { $0.name == "statusline.lines.source_mismatch" })
    }

    // MARK: - I3: totalApiDurationMs preserved through enforcement

    func testI3PreservesTotalApiDurationMs() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)
        monitor.testSetCachedGitStats((added: 0, removed: 0))

        let json = Data(
            """
            {"cost": {"total_cost_usd": 0.05, "total_duration_ms": 2000, "total_api_duration_ms": 1234.5}}
            """.utf8)
        let parsed = try JSONDecoder().decode(StatusLineData.self, from: json)
        var enforced = parsed

        monitor.testApplyI3Enforcement(to: &enforced)

        XCTAssertEqual(enforced.cost?.totalApiDurationMs, 1234.5, "totalApiDurationMs must survive I3 enforcement")
        XCTAssertEqual(enforced.cost?.totalCostUsd, 0.05)
    }

    // MARK: - Repo identity injection

    func testRepoIdentityInjectedOnPayloadApply() throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)
        let repo = StatusLineData.Repo(host: "github.com", owner: "acme", name: "widget")
        monitor.testSetCachedRepoIdentity(repo)

        let payload = Data(#"{"cost": {"total_cost_usd": 0.0}}"#.utf8)
        try payload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "test")

        XCTAssertEqual(monitor.currentData?.repo?.owner, "acme")
        XCTAssertEqual(monitor.currentData?.repo?.name, "widget")
        XCTAssertEqual(monitor.currentData?.repo?.host, "github.com")
    }

    func testRepoIdentityNilWhenNotCached() throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)

        let payload = Data(#"{"cost": {"total_cost_usd": 0.0}}"#.utf8)
        try payload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "test")

        XCTAssertNil(monitor.currentData?.repo)
    }

    // MARK: - I8: Custom field merge points

    func testCustomFieldsMergedIntoCurrentDataOnClaudePayloadApply() throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)
        monitor.testSetCachedCustomFieldValues([
            "custom:abc": CustomFieldRenderValue(text: "hello", percent: nil, tint: nil, icon: nil)
        ])

        let payload = Data(#"{"cost": {"total_cost_usd": 1.0}}"#.utf8)
        try payload.write(to: URL(filePath: monitor.filePath))
        monitor.testApplyLatestPayload(reason: "test")

        XCTAssertEqual(monitor.currentData?.customFields?["custom:abc"]?.text, "hello")
    }

    func testCustomFieldsMergedIntoCurrentDataOnProviderSnapshot() throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .cursor)
        monitor.testSetCachedCustomFieldValues([
            "custom:xyz": CustomFieldRenderValue(text: nil, percent: 42, tint: .warning, icon: nil)
        ])

        monitor.testApplyProviderSnapshot(.empty())

        XCTAssertEqual(monitor.currentData?.customFields?["custom:xyz"]?.percent, 42)
        XCTAssertEqual(monitor.currentData?.customFields?["custom:xyz"]?.tint, .warning)
    }

    func testCustomFieldFailureRetainsPriorValueAndRecordsExecFailed() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        let field = CustomStatusLineField(id: "custom:b", label: "B", command: "exit 1")

        monitor.testApplyCustomFieldResult(
            field: field,
            result: .success(
                CustomFieldRenderValue(text: "good", percent: nil, tint: nil, icon: nil), outputKind: .text)
        )
        XCTAssertEqual(monitor.cachedCustomFieldValuesForTesting["custom:b"]?.text, "good")

        monitor.testApplyCustomFieldResult(field: field, result: .failure(.nonzeroExit))

        XCTAssertEqual(
            monitor.cachedCustomFieldValuesForTesting["custom:b"]?.text, "good",
            "a failed execution must never revert a previously-good value")

        let events = TracingService.shared.recordedEventsForTesting
        let failed = events.first { $0.name == "statusline.custom_field.exec_failed" }
        XCTAssertNotNil(failed)
        XCTAssertEqual(failed?.attributes["reason"], "nonzero_exit")
        XCTAssertEqual(failed?.attributes["retained_prior_value"], "true")
    }

    func testCustomFieldSuccessRecordsExecSucceeded() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        let field = CustomStatusLineField(id: "custom:c", label: "C", command: "echo hi")

        monitor.testApplyCustomFieldResult(
            field: field,
            result: .success(CustomFieldRenderValue(text: "hi", percent: nil, tint: nil, icon: nil), outputKind: .text)
        )

        let events = TracingService.shared.recordedEventsForTesting
        let succeeded = events.first { $0.name == "statusline.custom_field.exec_succeeded" }
        XCTAssertNotNil(succeeded)
        XCTAssertEqual(succeeded?.attributes["output_kind"], "text")
        XCTAssertEqual(succeeded?.attributes["field_id"], "custom:c")
    }

    func testSetCustomFieldsRemovesCachedValueWhenFieldRemoved() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        let field = CustomStatusLineField(id: "custom:a", label: "A", command: "echo hi")

        monitor.setCustomFields([field])
        monitor.testApplyCustomFieldResult(
            field: field,
            result: .success(CustomFieldRenderValue(text: "hi", percent: nil, tint: nil, icon: nil), outputKind: .text)
        )
        XCTAssertEqual(monitor.cachedCustomFieldValuesForTesting["custom:a"]?.text, "hi")

        monitor.setCustomFields([])

        XCTAssertNil(
            monitor.cachedCustomFieldValuesForTesting["custom:a"], "removing a field must drop its cached value")
    }

    func testProfileNameThreadedIntoCustomFieldEnvironment() async throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: workDir) }

        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: workDir, harness: .claude)
        monitor.profileName = "Backend"
        let field = CustomStatusLineField(
            id: "custom:profile", label: "Profile",
            command: "echo $AGENT_SESSION_MANAGER_PROFILE_NAME",
            refreshIntervalSeconds: 5, timeoutSeconds: 5)
        monitor.setCustomFields([field])

        let resolved = await Self.pollUntilTrue {
            monitor.cachedCustomFieldValuesForTesting["custom:profile"] != nil
        }
        let resolvedText = monitor.cachedCustomFieldValuesForTesting["custom:profile"]?.text
        monitor.stop()

        XCTAssertTrue(resolved, "expected the custom field to resolve within the timeout")
        XCTAssertEqual(resolvedText, "Backend")
    }

    private static func pollUntilTrue(timeout: TimeInterval = 3, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return condition()
    }
}
