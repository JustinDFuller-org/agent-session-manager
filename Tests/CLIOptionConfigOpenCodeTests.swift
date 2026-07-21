import XCTest

@testable import AgentSessionManager

final class CLIOptionConfigOpenCodeTests: XCTestCase {
    func testOpenCodeCatalogContainsExpectedFlags() {
        let ids = Set(CLIOptionConfig.opencodeAll.map(\.id))
        let expectedIDs: Set<String> = [
            "--continue",
            "--session",
            "--fork",
            "--prompt",
            "--model",
            "--agent",
            "--auto",
            "--cors",
        ]
        XCTAssertTrue(expectedIDs.isSubset(of: ids), "Missing expected OpenCode flags: \(expectedIDs.subtracting(ids))")
    }

    func testHarnessAwareDecodeResolvesOpenCodeTemplate() throws {
        let json = Data(#"{"id":"--agent","isAvailable":true,"isDefaultEnabled":false}"#.utf8)
        let decoder = JSONDecoder()
        decoder.userInfo[CLIOptionConfig.harnessUserInfoKey] = Harness.opencode
        let decoded = try decoder.decode(CLIOptionConfig.self, from: json)
        XCTAssertEqual(decoded.id, "--agent")
        XCTAssertEqual(decoded.label, "Agent")
        XCTAssertEqual(decoded.description, "Agent to use for the OpenCode session")
        XCTAssertFalse(decoded.isUserAdded)
    }

    func testHarnessAwareDecodeResolvesClaudeTemplate() throws {
        let json = Data(#"{"id":"--agent","isAvailable":true,"isDefaultEnabled":false}"#.utf8)
        let decoder = JSONDecoder()
        decoder.userInfo[CLIOptionConfig.harnessUserInfoKey] = Harness.claude
        let decoded = try decoder.decode(CLIOptionConfig.self, from: json)
        XCTAssertEqual(decoded.id, "--agent")
        XCTAssertEqual(decoded.label, "Agent")
        XCTAssertEqual(decoded.description, "Specify an agent for the current session")
        XCTAssertFalse(decoded.isUserAdded)
    }

    func testDecodeWithoutUserInfoFallsBackToClaudeTemplate() throws {
        let json = Data(#"{"id":"--agent","isAvailable":true,"isDefaultEnabled":false}"#.utf8)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CLIOptionConfig.self, from: json)
        XCTAssertEqual(decoded.id, "--agent")
        XCTAssertEqual(decoded.description, "Specify an agent for the current session")
        XCTAssertFalse(decoded.isUserAdded)
    }

    func testOpenCodeStringFlags() {
        let stringIDs: Set<String> = [
            "--session", "--prompt", "--model", "--agent", "--cors",
        ]
        let configsByID = Dictionary(uniqueKeysWithValues: CLIOptionConfig.opencodeAll.map { ($0.id, $0) })
        for id in stringIDs {
            guard let config = configsByID[id] else {
                XCTFail("Missing OpenCode flag \(id)")
                continue
            }
            guard case .string = config.optionType else {
                XCTFail("Expected \(id) to be a string option, got \(config.optionType)")
                continue
            }
        }
    }

    func testOpenCodeBooleanFlags() {
        let booleanIDs: Set<String> = ["--continue", "--fork", "--auto"]
        let configsByID = Dictionary(uniqueKeysWithValues: CLIOptionConfig.opencodeAll.map { ($0.id, $0) })
        for id in booleanIDs {
            guard let config = configsByID[id] else {
                XCTFail("Missing OpenCode flag \(id)")
                continue
            }
            guard case .boolean = config.optionType else {
                XCTFail("Expected \(id) to be a boolean option, got \(config.optionType)")
                continue
            }
        }
    }

    func testOpenCodeRecommendedDefaultsArePopulated() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .opencode)
        XCTAssertEqual(defaults.count, CLIOptionConfig.opencodeAll.count)

        let availableIDs = Set(defaults.filter(\.isAvailable).map(\.id))
        XCTAssertEqual(availableIDs, ["--model"], "Only --model should be recommended by default")

        let unavailable = defaults.filter(\.isAvailable)
        for option in unavailable {
            XCTAssertEqual(option.id, "--model", "Unexpected recommended flag: \(option.id)")
        }
    }

    func testOpenCodeCatalogEntriesAreNotDefaultEnabled() {
        for option in CLIOptionConfig.opencodeAll {
            XCTAssertFalse(option.isDefaultEnabled, "OpenCode flag \(option.id) should not be default-enabled")
        }
    }
}
