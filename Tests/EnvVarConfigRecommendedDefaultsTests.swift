import XCTest

@testable import AgentSessionManager

final class EnvVarConfigRecommendedDefaultsTests: XCTestCase {
    func testRecommendedIDsAreAvailable() {
        let defaults = EnvVarConfig.recommendedDefaults()
        let recommendedIDs: Set<String> = ["ANTHROPIC_API_KEY", "ANTHROPIC_MODEL", "ANTHROPIC_BASE_URL"]
        for id in recommendedIDs {
            let envVar = defaults.first { $0.id == id }
            XCTAssertNotNil(envVar, "Expected recommended env var \(id) in defaults")
            XCTAssertTrue(envVar!.isAvailable, "\(id) should be available in recommended defaults")
        }
    }

    func testNonRecommendedIDsAreUnavailable() {
        let defaults = EnvVarConfig.recommendedDefaults()
        let recommendedIDs: Set<String> = ["ANTHROPIC_API_KEY", "ANTHROPIC_MODEL", "ANTHROPIC_BASE_URL"]
        for envVar in defaults where !recommendedIDs.contains(envVar.id) {
            XCTAssertFalse(envVar.isAvailable, "\(envVar.id) should not be available in recommended defaults")
        }
    }

    func testRecommendedIDsExistInCatalog() {
        let catalogIDs = Set(EnvVarConfig.all.map(\.id))
        let recommendedIDs: Set<String> = ["ANTHROPIC_API_KEY", "ANTHROPIC_MODEL", "ANTHROPIC_BASE_URL"]
        for id in recommendedIDs {
            XCTAssertTrue(catalogIDs.contains(id), "\(id) must exist in EnvVarConfig catalog")
        }
    }

    func testRecommendedDefaultsNotDefaultEnabled() {
        let defaults = EnvVarConfig.recommendedDefaults()
        let recommendedIDs: Set<String> = ["ANTHROPIC_API_KEY", "ANTHROPIC_MODEL", "ANTHROPIC_BASE_URL"]
        for envVar in defaults where recommendedIDs.contains(envVar.id) {
            XCTAssertFalse(envVar.isDefaultEnabled, "\(envVar.id) should not be default-enabled")
        }
    }

    func testRecommendedDefaultValuesAreEmpty() {
        let defaults = EnvVarConfig.recommendedDefaults()
        let recommendedIDs: Set<String> = ["ANTHROPIC_API_KEY", "ANTHROPIC_MODEL", "ANTHROPIC_BASE_URL"]
        for envVar in defaults where recommendedIDs.contains(envVar.id) {
            XCTAssertTrue(envVar.defaultValue.isEmpty, "\(envVar.id) should have empty defaultValue")
        }
    }

    func testRecommendedDefaultsCountMatchesCatalog() {
        let defaults = EnvVarConfig.recommendedDefaults()
        XCTAssertEqual(defaults.count, EnvVarConfig.all.count)
    }
}
