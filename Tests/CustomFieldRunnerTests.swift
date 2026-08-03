import XCTest

@testable import AgentSessionManager

final class CustomFieldRunnerTests: XCTestCase {
    private func makeContext(
        currentData: StatusLineData? = nil, profileName: String? = "TestProfile"
    )
        -> CustomFieldExecutionContext
    {
        CustomFieldExecutionContext(
            currentData: currentData,
            paneID: UUID(),
            paneName: "test-pane",
            tabID: UUID(),
            tabName: "test-tab",
            harness: .claude,
            workingDirectory: NSTemporaryDirectory(),
            profileName: profileName
        )
    }

    // MARK: - Execution: success paths

    func testPlainTextEchoSucceeds() async {
        let field = CustomStatusLineField(label: "Echo", command: "echo hello")
        let result = await CustomFieldRunner.run(field: field, context: makeContext())
        guard case .success(let value, let kind) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertEqual(value.text, "hello")
        XCTAssertEqual(kind, .text)
    }

    func testPercentScriptOutputRemainsExactPlainText() async {
        let field = CustomStatusLineField(label: "Percent", command: "printf '7.3%%'")
        let result = await CustomFieldRunner.run(field: field, context: makeContext())
        guard case .success(let value, let kind) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }

        XCTAssertEqual(value.text, "7.3%")
        XCTAssertNil(value.percent)
        XCTAssertEqual(kind, .text)
    }

    func testStructuredJSONOutputParsesAsStructured() async {
        let field = CustomStatusLineField(label: "Pct", command: #"echo '{"percent": 42, "tint": "warning"}'"#)
        let result = await CustomFieldRunner.run(field: field, context: makeContext())
        guard case .success(let value, let kind) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertEqual(value.percent, 42)
        XCTAssertEqual(value.tint, .warning)
        XCTAssertEqual(kind, .structured)
    }

    func testRunReceivesStdinContextPayload() async throws {
        // Mirrors asm-model-short.sh's consumption pattern: read stdin JSON, extract model.display_name.
        let json = Data(#"{"model": {"display_name": "Sonnet"}}"#.utf8)
        let currentData = try JSONDecoder().decode(StatusLineData.self, from: json)
        let field = CustomStatusLineField(
            label: "Model",
            command: #"python3 -c "import json, sys; print(json.load(sys.stdin)['model']['display_name'])""#)
        let result = await CustomFieldRunner.run(field: field, context: makeContext(currentData: currentData))
        guard case .success(let value, _) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertEqual(value.text, "Sonnet")
    }

    // MARK: - Execution: failure paths

    func testNonzeroExitReportsFailure() async {
        let field = CustomStatusLineField(label: "Fail", command: "exit 1")
        let result = await CustomFieldRunner.run(field: field, context: makeContext())
        guard case .failure(let reason) = result else {
            XCTFail("Expected failure, got \(result)")
            return
        }
        XCTAssertEqual(reason, .nonzeroExit)
    }

    func testEmptyOutputReportsFailure() async {
        let field = CustomStatusLineField(label: "Empty", command: "true")
        let result = await CustomFieldRunner.run(field: field, context: makeContext())
        guard case .failure(let reason) = result else {
            XCTFail("Expected failure, got \(result)")
            return
        }
        XCTAssertEqual(reason, .emptyOutput)
    }

    func testTimeoutTerminatesLongRunningCommand() async {
        let field = CustomStatusLineField(label: "Slow", command: "sleep 5", timeoutSeconds: 1)
        let startedAt = Date()
        let result = await CustomFieldRunner.run(field: field, context: makeContext())
        let elapsed = Date().timeIntervalSince(startedAt)
        guard case .failure(let reason) = result else {
            XCTFail("Expected failure, got \(result)")
            return
        }
        XCTAssertEqual(reason, .timeout)
        XCTAssertLessThan(elapsed, 4, "should be killed near the 1s timeout, not run the full 5s sleep")
    }

    // MARK: - Output parsing

    func testANSIEscapeSequencesAreStripped() {
        let input = "\u{1B}[31mHello\u{1B}[0m World"
        XCTAssertEqual(CustomFieldRunner.stripANSI(input), "Hello World")
    }

    func testOutputTruncatedAtCharacterLimit() {
        let long = String(repeating: "x", count: 500)
        let (value, kind) = CustomFieldRunner.parse(long)
        XCTAssertEqual(value.text?.count, CustomFieldRunner.outputCharacterLimit)
        XCTAssertEqual(kind, .text)
    }

    func testMultilineOutputUsesFirstLineOnly() {
        let (value, _) = CustomFieldRunner.parse("first line\nsecond line")
        XCTAssertEqual(value.text, "first line")
    }

    func testAllNilStructuredOutputFallsBackToPlainText() {
        // {} decodes to a CustomFieldRenderValue with every field nil — not useful as structured
        // output, so it must fall back to the plain-text path instead of an empty fact.
        let (value, kind) = CustomFieldRunner.parse("{}")
        XCTAssertEqual(kind, .text)
        XCTAssertEqual(value.text, "{}")
    }

    func testPlainTextThatIsNotJSONFallsBackToText() {
        let (value, kind) = CustomFieldRunner.parse("24.6%")
        XCTAssertEqual(kind, .text)
        XCTAssertEqual(value.text, "24.6%")
    }

    // MARK: - buildContextPayload

    func testBuildContextPayloadIncludesPaneTabHarnessProfileAndWorkingDirectory() throws {
        let context = makeContext()
        let data = CustomFieldRunner.buildContextPayload(context: context)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let pane = obj?["pane"] as? [String: Any]
        XCTAssertEqual(pane?["name"] as? String, "test-pane")
        let tab = obj?["tab"] as? [String: Any]
        XCTAssertEqual(tab?["name"] as? String, "test-tab")
        XCTAssertEqual(obj?["harness"] as? String, "claude")
        XCTAssertEqual(obj?["profile_name"] as? String, "TestProfile")
        XCTAssertEqual(obj?["working_directory"] as? String, NSTemporaryDirectory())
    }

    func testBuildContextPayloadOmitsProfileNameWhenNil() throws {
        let context = makeContext(profileName: nil)
        let data = CustomFieldRunner.buildContextPayload(context: context)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNil(obj?["profile_name"])
    }

    func testBuildContextPayloadMergesCurrentData() throws {
        let json = Data(#"{"model": {"id": "claude-sonnet-4-6"}}"#.utf8)
        let currentData = try JSONDecoder().decode(StatusLineData.self, from: json)
        let context = makeContext(currentData: currentData)
        let data = CustomFieldRunner.buildContextPayload(context: context)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let model = obj?["model"] as? [String: Any]
        XCTAssertEqual(model?["id"] as? String, "claude-sonnet-4-6")
    }

    // MARK: - buildEnvironment

    func testBuildEnvironmentIncludesCuratedKeys() {
        let env = CustomFieldRunner.buildEnvironment(context: makeContext())
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_PANE_NAME"], "test-pane")
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_TAB_NAME"], "test-tab")
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_HARNESS"], "claude")
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_PROFILE_NAME"], "TestProfile")
    }

    func testBuildEnvironmentIncludesCostAndWorktreeFromCurrentData() throws {
        let json = Data(
            """
            {"worktree": {"name": "my-worktree", "branch": "main"}, "cost": {"total_cost_usd": 1.5, "total_duration_ms": 2000, "total_lines_added": 3, "total_lines_removed": 1}}
            """.utf8)
        let currentData = try JSONDecoder().decode(StatusLineData.self, from: json)
        let env = CustomFieldRunner.buildEnvironment(context: makeContext(currentData: currentData))
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_WORKTREE_NAME"], "my-worktree")
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_WORKTREE_BRANCH"], "main")
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_COST_USD"], "1.5")
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_LINES_ADDED"], "3")
        XCTAssertEqual(env["AGENT_SESSION_MANAGER_LINES_REMOVED"], "1")
    }
}
