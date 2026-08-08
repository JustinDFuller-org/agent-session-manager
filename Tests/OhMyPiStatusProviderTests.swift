import XCTest

@testable import AgentSessionManager

@MainActor
final class OhMyPiStatusProviderTests: XCTestCase {
    nonisolated(unsafe) private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-omp-status-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testProviderBindsPersistentSessionAndReportsWorkingFromWatcher() {
        let statusURL = directory.appending(path: "status.json")
        try? Data().write(to: statusURL)
        let context = StatusProviderContext(
            paneID: UUID(), paneName: "pane", tabID: UUID(), tabName: "tab",
            workingDirectory: directory.path, harness: .omp, processStartTime: Date(),
            launchArgs: [], environment: [:], detectedHarnessVersion: nil,
            codexHookRecordPath: nil, opencodePort: nil, opencodeSessionID: nil,
            ohMyPiStatusFilePath: statusURL.path, expectedOhMyPiSessionID: "session-1")
        let provider = OhMyPiStatusProvider(context: context)
        let bound = expectation(description: "session bound")
        let working = expectation(description: "working")
        provider.onSessionBound = { id in
            XCTAssertEqual(id, "session-1")
            bound.fulfill()
        }
        provider.onWorkingChanged = { value in
            if value { working.fulfill() }
        }
        provider.start()
        defer { provider.stop() }

        writeSnapshot(to: statusURL, sequence: 1, sessionID: "session-1", working: true)

        wait(for: [bound, working], timeout: 2)
    }

    func testProviderEmitsPermissionAttentionOncePerAttentionSequence() {
        let statusURL = directory.appending(path: "status.json")
        try? Data().write(to: statusURL)
        let context = StatusProviderContext(
            paneID: UUID(), paneName: "pane", tabID: UUID(), tabName: "tab",
            workingDirectory: directory.path, harness: .omp, processStartTime: Date(),
            launchArgs: [], environment: [:], detectedHarnessVersion: nil,
            codexHookRecordPath: nil, opencodePort: nil, opencodeSessionID: nil,
            ohMyPiStatusFilePath: statusURL.path)
        let provider = OhMyPiStatusProvider(context: context)
        let attention = expectation(description: "permission attention")
        provider.onAttention = { event in
            XCTAssertEqual(event.source, .ohMyPiPermissionRequest)
            XCTAssertEqual(event.reason, "write: approval requested")
            attention.fulfill()
        }
        provider.start()
        defer { provider.stop() }

        writeSnapshot(to: statusURL, sequence: 1, attentionSequence: 1, attentionKind: "permission")
        wait(for: [attention], timeout: 2)
        writeSnapshot(to: statusURL, sequence: 2, attentionSequence: 1, attentionKind: "permission")
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    private func writeSnapshot(
        to url: URL,
        sequence: Int,
        sessionID: String? = nil,
        working: Bool = false,
        attentionSequence: Int? = nil,
        attentionKind: String? = nil,
        event: String = "agent_start"
    ) {
        var snapshot: [String: Any] = [
            "schema_version": 1,
            "event_sequence": sequence,
            "event": event,
            "session_id": sessionID ?? NSNull(),
            "session_persistent": sessionID != nil,
            "session_name": "tab/pane",
            "model_id": "model",
            "model_display_name": "Model",
            "thinking_level": "medium",
            "usage": ["input": 100, "output": 25, "cost": 0.5],
            "latest_request_usage": ["input": 10, "output": 5, "cache_read": 2, "cache_write": 1],
            "context": ["tokens": 125, "context_window": 1_000, "percent": 12.5],
            "is_working": working,
            "attention": NSNull(),
        ]
        if let attentionSequence, let attentionKind {
            snapshot["attention"] = [
                "sequence": attentionSequence,
                "kind": attentionKind,
                "reason": "write: approval requested",
            ]
        }
        let data = try! JSONSerialization.data(withJSONObject: snapshot)
        try! data.write(to: url, options: .atomic)
    }
}
