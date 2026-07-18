import XCTest

@testable import AgentSessionManager

@MainActor
final class OpenCodeStatusProviderInvariantTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-opencode-invariant-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
        TracingService.shared.enableTestCapture()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
        super.tearDown()
    }

    private func makeContext(
        workingDirectory: String? = nil,
        processStartTime: Date = Date(),
        opencodePort: Int? = 41617,
        opencodeSessionID: String? = nil
    ) -> StatusProviderContext {
        StatusProviderContext(
            paneID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            paneName: "opencode-pane",
            tabID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            tabName: "repo",
            workingDirectory: workingDirectory ?? tempDir.path,
            harness: .opencode,
            processStartTime: processStartTime,
            launchArgs: [],
            environment: [:],
            detectedHarnessVersion: nil,
            codexHookRecordPath: nil,
            opencodePort: opencodePort,
            opencodeSessionID: opencodeSessionID
        )
    }

    private func makeSession(
        id: String = "ses_test",
        directory: String? = nil,
        title: String? = nil,
        created: Int64,
        status: String? = nil,
        cost: Double? = 0.42,
        tokens: OpenCodeSessionTokens? = nil,
        model: OpenCodeSessionModel? = nil,
        version: String? = "1.17.20"
    ) -> OpenCodeSession {
        OpenCodeSession(
            id: id,
            title: title,
            directory: directory,
            parentID: nil,
            status: status,
            cost: cost,
            tokens: tokens ?? OpenCodeSessionTokens(input: 100, output: 50, reasoning: 10, cacheRead: 5, cacheWrite: 2),
            model: model ?? OpenCodeSessionModel(id: "k2.7", providerID: "openai", variant: nil),
            version: version,
            time: OpenCodeSessionTime(created: created, updated: created)
        )
    }

    private final class FakeClient: OpenCodeServerClient, @unchecked Sendable {
        nonisolated(unsafe) var healthResult: Result<(healthy: Bool, version: String?), Error> = .success(
            (true, "1.17.20"))
        nonisolated(unsafe) var sessions: [OpenCodeSession] = []
        nonisolated(unsafe) var sessionsByID: [String: OpenCodeSession] = [:]
        nonisolated(unsafe) var eventStream: Result<AsyncThrowingStream<OpenCodeEvent, Error>, Error>?

        func health() async throws -> (healthy: Bool, version: String?) {
            try healthResult.get()
        }

        func listSessions() async throws -> [OpenCodeSession] {
            sessions
        }

        func session(_ id: String) async throws -> OpenCodeSession {
            guard let session = sessionsByID[id] else {
                throw OpenCodeServerClientError.unexpectedStatus(404)
            }
            return session
        }

        func rename(_ id: String, title: String) async throws -> OpenCodeSession {
            let original = try await session(id)
            return OpenCodeSession(
                id: original.id,
                title: title,
                directory: original.directory,
                parentID: original.parentID,
                status: original.status,
                cost: original.cost,
                tokens: original.tokens,
                model: original.model,
                version: original.version,
                time: original.time
            )
        }

        func events() -> AsyncThrowingStream<OpenCodeEvent, Error> {
            guard let eventStream else {
                return AsyncThrowingStream { continuation in
                    continuation.finish(throwing: OpenCodeServerClientError.unexpectedStatus(0))
                }
            }
            do {
                return try eventStream.get()
            } catch {
                return AsyncThrowingStream { continuation in
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func testProviderReportsSessionRebindableWhenExpectedIDDiffers() throws {
        let processStart = Date()
        let processStartMs = Int64(processStart.timeIntervalSince1970 * 1000)
        let client = FakeClient()
        let session = makeSession(id: "ses_actual", directory: tempDir.path, created: processStartMs)
        client.sessions = [session]
        client.sessionsByID[session.id] = session

        InvariantReporter.shared.enableTestCapture()
        let provider = OpenCodeStatusProvider(
            context: makeContext(processStartTime: processStart, opencodeSessionID: "ses_expected"),
            client: client,
            startupRetryInterval: 0.01,
            pollInterval: 60
        )

        let expectation = XCTestExpectation(description: "provider binds")
        provider.onUpdate = { data in
            if data.model != nil { expectation.fulfill() }
        }

        provider.start()
        wait(for: [expectation], timeout: 3)
        provider.stop()

        let violation = InvariantReporter.shared.violationsForTesting.first
        XCTAssertEqual(violation?.invariantID, "opencode.session.rebindable")
        XCTAssertEqual(violation?.context["expected_session_id_prefix"], "ses_expected")
        XCTAssertEqual(violation?.context["bound_session_id_prefix"], "ses_actual")
    }

    func testProviderReportsSessionRebindableWhenUnbindable() {
        let client = FakeClient()
        client.sessions = []

        InvariantReporter.shared.enableTestCapture()
        let provider = OpenCodeStatusProvider(
            context: makeContext(),
            client: client,
            startupRetryInterval: 0.01,
            startupTimeout: 0.1,
            pollInterval: 60
        )

        provider.start()
        let expectation = XCTestExpectation(description: "provider gives up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
        provider.stop()

        let violation = InvariantReporter.shared.violationsForTesting.first
        XCTAssertEqual(violation?.invariantID, "opencode.session.rebindable")
        XCTAssertEqual(violation?.context["reason"], "startup_timeout")
    }

    func testTUIEndpointGuardThrowsAndReportsInvariant() {
        InvariantReporter.shared.enableTestCapture()
        let client = URLSessionOpenCodeClient(port: 12345)

        XCTAssertThrowsError(
            try client.makeRequest(path: "/tui/submit-prompt", method: "POST", body: nil)
        ) { error in
            guard case OpenCodeServerClientError.forbiddenTUIEndpoint(let path) = error else {
                return XCTFail("Expected forbiddenTUIEndpoint error, got \(error)")
            }
            XCTAssertEqual(path, "/tui/submit-prompt")
        }

        let violation = InvariantReporter.shared.violationsForTesting.first
        XCTAssertEqual(violation?.invariantID, "opencode.tui.endpoints_unused")
        XCTAssertEqual(violation?.context["path"], "/tui/submit-prompt")
    }

    func testProviderEmitsVersionDriftWhenHealthVersionMissing() throws {
        let processStart = Date()
        let processStartMs = Int64(processStart.timeIntervalSince1970 * 1000)
        let client = FakeClient()
        client.healthResult = .success((true, nil))
        let session = makeSession(id: "ses_drift", directory: tempDir.path, created: processStartMs)
        client.sessions = [session]
        client.sessionsByID[session.id] = session

        let provider = OpenCodeStatusProvider(
            context: makeContext(processStartTime: processStart),
            client: client,
            startupRetryInterval: 0.01,
            pollInterval: 60
        )

        let expectation = XCTestExpectation(description: "provider binds")
        provider.onUpdate = { data in
            if data.model != nil { expectation.fulfill() }
        }

        provider.start()
        wait(for: [expectation], timeout: 3)
        provider.stop()

        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertTrue(events.contains { $0.name == "statusline.opencode.version.drift" })
    }
}
