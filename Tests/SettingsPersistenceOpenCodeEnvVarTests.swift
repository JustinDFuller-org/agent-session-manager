import XCTest

@testable import AgentSessionManager

@MainActor
final class SettingsPersistenceOpenCodeEnvVarTests: XCTestCase {
    func testMergeEnvVarOptionsAppliesAvailabilityAndDefaultValue() {
        let defaults = [
            EnvVarConfig(id: "OPENCODE_CLIENT", label: "Client", description: "Client id"),
            EnvVarConfig(id: "OPENCODE_AUTO_SHARE", label: "Auto Share", description: "Auto share"),
        ]
        var saved = defaults
        saved[0].isAvailable = true
        saved[0].defaultValue = "agent-session-manager"
        saved[1].isDefaultEnabled = true
        saved[1].defaultValue = "manual"

        let merged = SettingsPersistence.mergeEnvVarOptions(saved, into: defaults)

        XCTAssertEqual(merged.count, 2)
        let client = merged.first { $0.id == "OPENCODE_CLIENT" }
        XCTAssertTrue(client?.isAvailable ?? false)
        XCTAssertEqual(client?.defaultValue, "agent-session-manager")
        let autoShare = merged.first { $0.id == "OPENCODE_AUTO_SHARE" }
        XCTAssertTrue(autoShare?.isDefaultEnabled ?? false)
        XCTAssertEqual(autoShare?.defaultValue, "manual")
    }

    func testMergeEnvVarOptionsAppendsUserAddedEntries() {
        let defaults = [EnvVarConfig(id: "OPENCODE_CLIENT", label: "Client", description: "Client id")]
        let userAdded = EnvVarConfig(
            id: "OPENCODE_CUSTOM", label: "OPENCODE_CUSTOM", description: "User-defined environment variable",
            isUserAdded: true)

        let merged = SettingsPersistence.mergeEnvVarOptions([userAdded], into: defaults)

        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(merged.contains(where: { $0.id == "OPENCODE_CUSTOM" && $0.isUserAdded }))
    }

    func testOpenCodeEnvVarCodingRoundTrip() throws {
        let original = EnvVarConfig.opencodeAll.first { $0.id == "OPENCODE_CLIENT" }!
        var mutable = original
        mutable.isAvailable = true
        mutable.defaultValue = "agent-session-manager"

        let encoded = try JSONEncoder().encode(mutable)
        let decoded = try JSONDecoder().decode(EnvVarConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, "OPENCODE_CLIENT")
        XCTAssertEqual(decoded.label, original.label)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertTrue(decoded.isAvailable)
        XCTAssertEqual(decoded.defaultValue, "agent-session-manager")
        XCTAssertFalse(decoded.isUserAdded)
    }

    func testAppSettingsDefaultsToOpencodeEnvVarCatalog() {
        let settings = AppSettings()
        XCTAssertEqual(settings.opencodeEnvVarOptions.map(\.id), EnvVarConfig.opencodeAll.map(\.id))
    }
}
