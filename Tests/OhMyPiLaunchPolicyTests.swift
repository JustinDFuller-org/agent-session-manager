import XCTest

@testable import AgentSessionManager

final class OhMyPiLaunchPolicyTests: XCTestCase {
    func testPersistedSessionAppendsExplicitResume() {
        let policy = OhMyPiLaunchPolicy.resolve(
            userArguments: ["--model", "fast"], sessionID: "session-123", continueWhenMissing: true)

        XCTAssertEqual(policy.arguments, ["--model", "fast", "--resume", "session-123"])
        XCTAssertEqual(policy.expectedSessionID, "session-123")
    }

    func testExplicitSessionChoiceIsPreserved() {
        let policy = OhMyPiLaunchPolicy.resolve(
            userArguments: ["--resume", "chosen-session"], sessionID: "saved-session", continueWhenMissing: true)

        XCTAssertEqual(policy.arguments, ["--resume", "chosen-session"])
        XCTAssertNil(policy.expectedSessionID)
    }

    func testContinueIsUsedOnlyWhenNoSessionExists() {
        let policy = OhMyPiLaunchPolicy.resolve(
            userArguments: ["--model", "fast"], sessionID: nil, continueWhenMissing: true)

        XCTAssertEqual(policy.arguments, ["--model", "fast", "--continue"])
        XCTAssertNil(policy.expectedSessionID)
    }

    func testRuntimeExtensionCommandIsAppendedAfterUserArguments() {
        let directory = URL(filePath: "/private/tmp/agent-session-manager-omp-11111111-1111-1111-1111-111111111111")

        XCTAssertEqual(
            Tab.buildOhMyPiCommand(extensionDirectory: directory, extraArgs: ["--model", "fast"]),
            ["omp", "--model", "fast", "--extension", directory.path])
    }

    func testOhMyPiStatusFactsAreAvailableOnlyWhereSupported() {
        XCTAssertTrue(StatusLineConfig.allHarnesses.contains(.omp))
        XCTAssertTrue(StatusLineConfig.itemCapabilities["cost"]!.supportedHarnesses.contains(.omp))
        XCTAssertTrue(StatusLineConfig.itemCapabilities["cacheRead"]!.supportedHarnesses.contains(.omp))
        XCTAssertFalse(StatusLineConfig.itemCapabilities["rate5h"]!.supportedHarnesses.contains(.omp))
    }
}
