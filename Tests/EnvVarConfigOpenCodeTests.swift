import XCTest

@testable import AgentSessionManager

final class EnvVarConfigOpenCodeTests: XCTestCase {
    func testOpenCodeCatalogContainsExpectedVars() {
        let ids = Set(EnvVarConfig.opencodeAll.map(\.id))
        let expectedIDs: Set<String> = [
            "OPENCODE_CONFIG_CONTENT",
            "OPENCODE_PERMISSION",
            "OPENCODE_CONFIG",
            "OPENCODE_CONFIG_DIR",
            "OPENCODE_TUI_CONFIG",
            "OPENCODE_SERVER_PASSWORD",
            "OPENCODE_SERVER_USERNAME",
            "OPENCODE_AUTO_SHARE",
            "OPENCODE_DISABLE_AUTOUPDATE",
            "OPENCODE_DISABLE_TERMINAL_TITLE",
            "OPENCODE_DISABLE_AUTOCOMPACT",
            "OPENCODE_DISABLE_MOUSE",
            "OPENCODE_DISABLE_CLAUDE_CODE",
            "OPENCODE_DISABLE_CLAUDE_CODE_PROMPT",
            "OPENCODE_DISABLE_CLAUDE_CODE_SKILLS",
            "OPENCODE_DISABLE_MODELS_FETCH",
            "OPENCODE_MODELS_URL",
            "OPENCODE_DISABLE_LSP_DOWNLOAD",
            "OPENCODE_DISABLE_DEFAULT_PLUGINS",
            "OPENCODE_DISABLE_PRUNE",
            "OPENCODE_CLIENT",
            "OPENCODE_FAKE_VCS",
            "OPENCODE_EXPERIMENTAL",
            "OPENCODE_EXPERIMENTAL_EVENT_SYSTEM",
            "OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS",
            "OPENCODE_ENABLE_EXPERIMENTAL_MODELS",
        ]
        XCTAssertTrue(
            expectedIDs.isSubset(of: ids), "Missing expected OpenCode env vars: \(expectedIDs.subtracting(ids))")
    }

    func testOpenCodeCatalogMarksAppControlledVars() {
        let appControlled = EnvVarConfig.opencodeAll.filter(\.isAppControlled).map(\.id)
        let expectedAppControlled: Set<String> = [
            "OPENCODE_CONFIG_CONTENT",
            "OPENCODE_PERMISSION",
            "OPENCODE_EXPERIMENTAL_EVENT_SYSTEM",
            "OPENCODE_DISABLE_PRUNE",
        ]
        let appControlledSet = Set(appControlled)
        XCTAssertTrue(
            expectedAppControlled.isSubset(of: appControlledSet),
            "Missing app-controlled markers: \(expectedAppControlled.subtracting(appControlledSet))")
        XCTAssertTrue(
            EnvVarConfig.opencodeAll.first { $0.id == "OPENCODE_CONFIG_CONTENT" }?.isAppControlled == true)
        XCTAssertTrue(
            EnvVarConfig.opencodeAll.first { $0.id == "OPENCODE_PERMISSION" }?.isAppControlled == true)
    }

    func testRecommendedDefaultsForOpenCodeSurfacesSafeDefaults() {
        let defaults = EnvVarConfig.recommendedDefaults(for: .opencode)
        var recommendedIDs: Set<String> = [
            "OPENCODE_AUTO_SHARE", "OPENCODE_DISABLE_AUTOUPDATE", "OPENCODE_CLIENT",
            "OPENCODE_CONFIG_CONTENT", "OPENCODE_PERMISSION",
            "OPENCODE_EXPERIMENTAL_EVENT_SYSTEM", "OPENCODE_DISABLE_PRUNE",
        ]
        #if DEV_BUILD
        recommendedIDs.insert("OPENCODE_DISABLE_DEFAULT_PLUGINS")
        #endif
        for id in recommendedIDs {
            let envVar = defaults.first { $0.id == id }
            XCTAssertNotNil(envVar, "Expected recommended env var \(id) in OpenCode defaults")
            XCTAssertTrue(envVar!.isAvailable, "\(id) should be available in OpenCode recommended defaults")
        }

        for envVar in defaults where !recommendedIDs.contains(envVar.id) {
            XCTAssertFalse(envVar.isAvailable, "\(envVar.id) should not be available in OpenCode recommended defaults")
        }
    }

    func testRecommendedDefaultsForOpenCodeDoesNotEnableUserControlledByDefault() {
        let defaults = EnvVarConfig.recommendedDefaults(for: .opencode)
        for envVar in defaults where envVar.isAvailable && !envVar.isAppControlled {
            XCTAssertFalse(envVar.isDefaultEnabled, "\(envVar.id) should not be default-enabled")
        }
    }

    func testRecommendedDefaultsForOpenCodeEnablesAppControlledByDefault() {
        let defaults = EnvVarConfig.recommendedDefaults(for: .opencode)
        for envVar in defaults where envVar.isAppControlled {
            XCTAssertTrue(envVar.isDefaultEnabled, "\(envVar.id) should be default-enabled to show it is active")
        }
    }

    func testRecommendedDefaultsForSwitchIsExhaustive() {
        XCTAssertEqual(
            EnvVarConfig.recommendedDefaults(for: .claude).count, EnvVarConfig.all.count,
            "Claude defaults must cover the full catalog")
        XCTAssertEqual(
            EnvVarConfig.recommendedDefaults(for: .opencode).count, EnvVarConfig.opencodeAll.count,
            "OpenCode defaults must cover the full catalog")
        XCTAssertTrue(EnvVarConfig.recommendedDefaults(for: .codex).isEmpty, "Codex has no env-var catalog yet")
        XCTAssertTrue(EnvVarConfig.recommendedDefaults(for: .cursor).isEmpty, "Cursor has no env-var catalog yet")
        XCTAssertTrue(EnvVarConfig.recommendedDefaults(for: .shell).isEmpty, "Shell has no env-var catalog")
    }
}
