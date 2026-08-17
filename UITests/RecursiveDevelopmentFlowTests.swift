import XCTest

final class RecursiveDevelopmentFlowTests: BaseTestCase {
    private let runID = "d2719b4b-3d1f-4f11-a9bb-3b3bfc8c9d24"

    override var additionalLaunchArguments: [String] {
        ["--recursive-development-run-id", runID]
    }

    override func tearDown() {
        super.tearDown()
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(
            at:
                base
                .appending(path: "agent-session-manager-recursive-runs")
                .appending(path: runID))
    }

    func testIsolatedRunShowsValidationTitleCreatesTabAndWritesReadyManifest() throws {
        let title = "Agent Session Manager (Dev · d2719b4b)"
        waitFor(app.windows[title], timeout: 15)
        createTab(named: "recursive-validation")

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let manifestURL =
            base
            .appending(path: "agent-session-manager-recursive-runs")
            .appending(path: runID)
            .appending(path: "agent-session-manager.dev")
            .appending(path: "recursive-development-runtime.json")
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(manifest?["runID"] as? String, runID)
        XCTAssertEqual(manifest?["state"] as? String, "ready")
        XCTAssertEqual(manifest?["windowTitle"] as? String, title)
        let runSupport =
            base
            .appending(path: "agent-session-manager-recursive-runs")
            .appending(path: runID)
            .appending(path: "agent-session-manager.dev")
        let sessionData = try Data(contentsOf: runSupport.appending(path: "sessions.json"))
        let session = try XCTUnwrap(JSONSerialization.jsonObject(with: sessionData) as? [String: Any])
        let tabs = try XCTUnwrap(session["tabs"] as? [[String: Any]])
        XCTAssertTrue(tabs.contains { $0["name"] as? String == "recursive-validation" })
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: UITestAppSupport.directory.appending(path: "sessions.json").path))
    }
}
