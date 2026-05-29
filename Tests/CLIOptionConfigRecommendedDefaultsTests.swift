import XCTest

@testable import AgentSessionManager

final class CLIOptionConfigRecommendedDefaultsTests: XCTestCase {
    func testClaudeRecommendedIDsAreAvailable() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .claude)
        let recommendedIDs: Set<String> = ["--continue", "--resume", "--model", "--permission-mode"]
        for id in recommendedIDs {
            let option = defaults.first { $0.id == id }
            XCTAssertNotNil(option, "Expected recommended option \(id) in Claude defaults")
            XCTAssertTrue(option!.isAvailable, "\(id) should be available in Claude recommended defaults")
        }
    }

    func testClaudeNonRecommendedIDsAreUnavailable() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .claude)
        let recommendedIDs: Set<String> = ["--continue", "--resume", "--model", "--permission-mode"]
        for option in defaults where !recommendedIDs.contains(option.id) {
            XCTAssertFalse(option.isAvailable, "\(option.id) should not be available in Claude recommended defaults")
        }
    }

    func testClaudeRecommendedIDsExistInCatalog() {
        let catalogIDs = Set(CLIOptionConfig.all.map(\.id))
        let recommendedIDs: Set<String> = ["--continue", "--resume", "--model", "--permission-mode"]
        for id in recommendedIDs {
            XCTAssertTrue(catalogIDs.contains(id), "\(id) must exist in Claude catalog")
        }
    }

    func testClaudeRecommendedDefaultsNotDefaultEnabled() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .claude)
        for option in defaults {
            XCTAssertFalse(option.isDefaultEnabled, "\(option.id) should not be default-enabled")
        }
    }

    func testClaudeRecommendedDefaultsCountMatchesCatalog() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .claude)
        XCTAssertEqual(defaults.count, CLIOptionConfig.all.count)
    }

    func testCodexRecommendedIDsAreAvailable() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .codex)
        let recommendedIDs: Set<String> = ["--model", "--ask-for-approval", "--sandbox", "--search"]
        for id in recommendedIDs {
            let option = defaults.first { $0.id == id }
            XCTAssertNotNil(option, "Expected recommended option \(id) in Codex defaults")
            XCTAssertTrue(option!.isAvailable, "\(id) should be available in Codex recommended defaults")
        }
    }

    func testCodexNonRecommendedIDsAreUnavailable() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .codex)
        let recommendedIDs: Set<String> = ["--model", "--ask-for-approval", "--sandbox", "--search"]
        for option in defaults where !recommendedIDs.contains(option.id) {
            XCTAssertFalse(option.isAvailable, "\(option.id) should not be available in Codex recommended defaults")
        }
    }

    func testCodexRecommendedDefaultsCountMatchesCatalog() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .codex)
        XCTAssertEqual(defaults.count, CLIOptionConfig.codexAll.count)
    }

    func testCursorRecommendedIDsAreAvailable() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .cursor)
        let recommendedIDs: Set<String> = ["--model", "--resume", "--mode"]
        for id in recommendedIDs {
            let option = defaults.first { $0.id == id }
            XCTAssertNotNil(option, "Expected recommended option \(id) in Cursor defaults")
            XCTAssertTrue(option!.isAvailable, "\(id) should be available in Cursor recommended defaults")
        }
    }

    func testCursorNonRecommendedIDsAreUnavailable() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .cursor)
        let recommendedIDs: Set<String> = ["--model", "--resume", "--mode"]
        for option in defaults where !recommendedIDs.contains(option.id) {
            XCTAssertFalse(option.isAvailable, "\(option.id) should not be available in Cursor recommended defaults")
        }
    }

    func testCursorRecommendedDefaultsCountMatchesCatalog() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .cursor)
        XCTAssertEqual(defaults.count, CLIOptionConfig.cursorAll.count)
    }

    func testOpenCodeRecommendedIDsAreAvailable() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .opencode)
        let recommendedIDs: Set<String> = ["--continue", "--model", "--agent", "--session"]
        for id in recommendedIDs {
            let option = defaults.first { $0.id == id }
            XCTAssertNotNil(option, "Expected recommended option \(id) in OpenCode defaults")
            XCTAssertTrue(option!.isAvailable, "\(id) should be available in OpenCode recommended defaults")
        }
    }

    func testOpenCodeNonRecommendedIDsAreUnavailable() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .opencode)
        let recommendedIDs: Set<String> = ["--continue", "--model", "--agent", "--session"]
        for option in defaults where !recommendedIDs.contains(option.id) {
            XCTAssertFalse(option.isAvailable, "\(option.id) should not be available in OpenCode recommended defaults")
        }
    }

    func testOpenCodeRecommendedDefaultsCountMatchesCatalog() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .opencode)
        XCTAssertEqual(defaults.count, CLIOptionConfig.opencodeAll.count)
    }

    func testShellReturnsEmpty() {
        let defaults = CLIOptionConfig.recommendedDefaults(for: .shell)
        XCTAssertTrue(defaults.isEmpty, "Shell CLI type should return empty recommended defaults")
    }
}
