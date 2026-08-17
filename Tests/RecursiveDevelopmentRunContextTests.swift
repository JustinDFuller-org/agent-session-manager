import XCTest

@testable import AgentSessionManager

final class RecursiveDevelopmentRunContextTests: XCTestCase {
    func testParsesCanonicalUUIDAndDerivesNestedDevDirectory() throws {
        let run = try XCTUnwrap(
            RecursiveDevelopmentRunContext.parse(arguments: [
                "AgentSessionManagerDev", "--recursive-development-run-id", "d2719b4b-3d1f-4f11-a9bb-3b3bfc8c9d24",
            ]))
        XCTAssertEqual(run.idString, "d2719b4b-3d1f-4f11-a9bb-3b3bfc8c9d24")
        XCTAssertEqual(
            run.persistenceSubdirectory,
            "agent-session-manager-recursive-runs/d2719b4b-3d1f-4f11-a9bb-3b3bfc8c9d24/agent-session-manager.dev")
    }

    func testMissingMalformedAndDuplicateRunIDsFail() {
        XCTAssertThrowsError(
            try RecursiveDevelopmentRunContext.parse(arguments: ["app", "--recursive-development-run-id"])
        ) {
            XCTAssertEqual($0 as? RecursiveDevelopmentRunContext.LaunchError, .missingRunID)
        }
        XCTAssertThrowsError(
            try RecursiveDevelopmentRunContext.parse(arguments: ["app", "--recursive-development-run-id", "../../prod"])
        ) {
            XCTAssertEqual($0 as? RecursiveDevelopmentRunContext.LaunchError, .malformedRunID)
        }
        XCTAssertThrowsError(
            try RecursiveDevelopmentRunContext.parse(arguments: [
                "app", "--recursive-development-run-id", UUID().uuidString, "--recursive-development-run-id",
                UUID().uuidString,
            ])
        ) {
            XCTAssertEqual($0 as? RecursiveDevelopmentRunContext.LaunchError, .duplicateRunID)
        }
    }

    func testNormalLaunchHasNoRun() throws {
        XCTAssertNil(try RecursiveDevelopmentRunContext.parse(arguments: ["AgentSessionManagerDev"]))
    }

    func testProductionRejectsRecursiveArgumentBeforePersistenceCanResolve() {
        XCTAssertThrowsError(
            try RecursiveDevelopmentRunContext.validatedRun(
                arguments: ["AgentSessionManager", "--recursive-development-run-id", UUID().uuidString],
                isDevBuild: false)
        ) { error in
            XCTAssertEqual(error as? RecursiveDevelopmentRunContext.LaunchError, .unsupportedInProduction)
        }
    }
}
