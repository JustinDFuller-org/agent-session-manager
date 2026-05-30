import XCTest

@testable import AgentSessionManager

@MainActor
final class InvariantTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appending(path: "invariant-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
    }

    override func tearDown() {
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
        try? FileManager.default.removeItem(at: directory)
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        super.tearDown()
    }

    func testReporterCapturesRepeatedViolationsWithDistinctOccurrences() {
        InvariantReporter.shared.enableTestCapture()
        InvariantReporter.shared.violated(.statusLineWorktreeName)
        InvariantReporter.shared.violated(.statusLineWorktreeName)

        let violations = InvariantReporter.shared.violationsForTesting
        XCTAssertEqual(violations.map(\.invariantID), ["statusline.worktree.name", "statusline.worktree.name"])
        XCTAssertNotEqual(violations[0].id, violations[1].id)
    }

    func testReporterRoutesLegacyTraceEventWhenFileOutputDisabled() {
        TracingService.shared.enableTestCapture()
        InvariantReporter.shared.violated(
            .statusLineWorktreeName,
            context: ["invariant.id": "caller-value", "field": "worktree.name"]
        )

        let event = TracingService.shared.recordedEventsForTesting.first
        XCTAssertEqual(event?.name, "statusline.worktree.name_mismatch")
        XCTAssertEqual(event?.attributes["invariant.id"], "statusline.worktree.name")
        XCTAssertEqual(event?.attributes["field"], "worktree.name")
    }

    func testWriterSynchronouslyAppendsMetadataAndViolation() throws {
        let writer = InvariantLogWriter(directory: directory, maxBytes: 10_000)
        try writer.append(InvariantViolation(invariant: .statusLineLinesSource, context: ["key": "value"]))

        let content = try String(contentsOf: writer.fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("\"_type\":\"metadata\""))
        XCTAssertTrue(content.contains("\"invariantID\":\"statusline.lines.source\""))
    }

    func testWriterTrimsWithInvariantMarker() throws {
        let writer = InvariantLogWriter(directory: directory, maxBytes: 500)
        for index in 0..<20 {
            try writer.append(
                InvariantViolation(
                    invariant: .statusLineLinesSource,
                    context: ["payload": String(repeating: "\(index)", count: 80)]
                )
            )
        }
        let content = try String(contentsOf: writer.fileURL, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix(InvariantLogWriter.truncationMarker))
    }

    func testReporterStoresWriteError() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocked = directory.appending(path: "blocked")
        try Data("file".utf8).write(to: blocked)
        InvariantReporter.shared.setWriterForTesting(InvariantLogWriter(directory: blocked, maxBytes: 10_000))

        InvariantReporter.shared.violated(.statusLineWorktreeName)

        XCTAssertNotNil(InvariantReporter.shared.latestWriterError)
    }

    func testRepositoryParsingSkipsMetadataMarkerAndMalformedLines() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let older = InvariantViolation(
            invariant: .statusLineWorktreeName, context: [:], timestamp: Date(timeIntervalSince1970: 1))
        let newer = InvariantViolation(
            invariant: .statusLineWorktreeName, context: [:], timestamp: Date(timeIntervalSince1970: 2))
        let content = [
            "{\"_type\":\"metadata\",\"schemaVersion\":1}",
            InvariantLogWriter.truncationMarker,
            "bad-json",
            String(decoding: try encoder.encode(older), as: UTF8.self),
            String(decoding: try encoder.encode(newer), as: UTF8.self),
        ].joined(separator: "\n")

        let parsed = InvariantRepository.parse(content)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(Set(parsed.map(\.invariantID)), ["statusline.worktree.name"])
        XCTAssertNotEqual(parsed[0].id, parsed[1].id)
    }

    func testDebugSettingsPersistenceUsesVersionedSchemaAndRejectsLegacySchema() throws {
        let subdirectory = "debug-settings-tests-\(UUID().uuidString)"
        PersistenceHelpers.overrideAppSupportSubdirectory = subdirectory
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: subdirectory)
        defer { try? FileManager.default.removeItem(at: support) }

        let settings = AppSettings()
        settings.debugModeEnabled = true
        SettingsPersistence.saveDebugSettings(appSettings: settings)
        settings.debugModeEnabled = false
        SettingsPersistence.restoreDebugSettings(into: settings)
        XCTAssertTrue(settings.debugModeEnabled)

        try Data("{\"enabled\":false}".utf8).write(to: support.appending(path: "debug-settings.json"))
        settings.debugModeEnabled = true
        SettingsPersistence.restoreDebugSettings(into: settings)
        XCTAssertTrue(settings.debugModeEnabled, "Legacy schema must be ignored")
    }
}
