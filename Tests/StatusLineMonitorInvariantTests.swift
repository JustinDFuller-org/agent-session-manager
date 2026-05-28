import XCTest

@testable import AgentSessionManager

@MainActor
final class StatusLineMonitorInvariantTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TracingService.shared.enableTestCapture()
    }

    override func tearDown() {
        super.tearDown()
        TracingService.shared.resetForTesting()
    }

    // MARK: - I2 Migration

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
                "chipLabelStyle": "labelOnly",
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
            cliType: .claude
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
            cliType: .claude
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
            cliType: .claude
        )

        let json = Data(
            """
            {"workspace": {"git_worktree": "/some/completely/different-name"}}
            """.utf8)
        let parsed = try JSONDecoder().decode(StatusLineData.self, from: json)
        var enforced = parsed

        monitor.testApplyI1Enforcement(to: &enforced)

        let events = TracingService.shared.recordedEventsForTesting
        let mismatch = events.first { $0.name == "statusline.worktree.name_mismatch" && $0.attributes["field"] == "workspace.git_worktree" }
        XCTAssertNotNil(mismatch, "Expected workspace.git_worktree mismatch event")
        XCTAssertEqual(mismatch?.attributes["computed"], "right-name")
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
            cliType: .claude
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
        XCTAssertEqual(mismatch?.attributes["computed_added"], "5")
        XCTAssertEqual(mismatch?.attributes["reported_added"], "999")
        XCTAssertEqual(mismatch?.attributes["computed_removed"], "0")
        XCTAssertEqual(mismatch?.attributes["reported_removed"], "0")
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
            cliType: .claude
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
}
