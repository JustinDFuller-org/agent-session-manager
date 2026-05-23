import XCTest

@testable import AgentSessionManager

final class EnvVarConfigTests: XCTestCase {
    private var predefined: [EnvVarConfig] {
        EnvVarConfig.all.filter { !$0.isUserAdded }
    }

    func testNoDuplicateIDs() {
        let ids = predefined.map(\.id)
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "Duplicate env var IDs detected")
    }

    func testAllHaveNonEmptyLabelsAndDescriptions() {
        for envVar in predefined {
            XCTAssertFalse(envVar.label.isEmpty, "\(envVar.id) has empty label")
            XCTAssertFalse(envVar.description.isEmpty, "\(envVar.id) has empty description")
        }
    }

    func testDeprecatedVarsExcluded() {
        let ids = Set(predefined.map(\.id))
        XCTAssertFalse(ids.contains("ANTHROPIC_SMALL_FAST_MODEL"), "Deprecated var should not be included")
    }

    func testAutoSetVarsExcluded() {
        let ids = Set(predefined.map(\.id))
        XCTAssertFalse(ids.contains("CLAUDECODE"), "Auto-set var should not be included")
    }

    func testDefaultsAreNotEnabledOrAvailable() {
        for envVar in predefined {
            XCTAssertFalse(envVar.isAvailable, "\(envVar.id) should not be available by default")
            XCTAssertFalse(envVar.isDefaultEnabled, "\(envVar.id) should not be default-enabled")
        }
    }

    func testDefaultValueIsEmpty() {
        for envVar in predefined {
            XCTAssertTrue(envVar.defaultValue.isEmpty, "\(envVar.id) should have empty defaultValue")
        }
    }

    func testUserAddedFactory() {
        let envVar = EnvVarConfig.makeUserAdded(id: "MY_CUSTOM_VAR")
        XCTAssertTrue(envVar.isUserAdded)
        XCTAssertEqual(envVar.id, "MY_CUSTOM_VAR")
        XCTAssertEqual(envVar.label, "MY_CUSTOM_VAR")
        XCTAssertTrue(envVar.isAvailable)
        XCTAssertFalse(envVar.isDefaultEnabled)
        XCTAssertTrue(envVar.defaultValue.isEmpty)
    }

    func testPredefinedCodingRoundTrip() throws {
        var original = predefined.first!
        original.isAvailable = true
        original.isDefaultEnabled = true
        original.defaultValue = "test-value"

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EnvVarConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertFalse(decoded.isUserAdded)
        XCTAssertTrue(decoded.isAvailable)
        XCTAssertTrue(decoded.isDefaultEnabled)
        XCTAssertEqual(decoded.defaultValue, "test-value")
        XCTAssertEqual(decoded.label, original.label)
        XCTAssertEqual(decoded.description, original.description)
    }

    func testUserAddedCodingRoundTrip() throws {
        var original = EnvVarConfig.makeUserAdded(id: "TEST_ENV_VAR")
        original.isDefaultEnabled = true
        original.defaultValue = "some-value"

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EnvVarConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, "TEST_ENV_VAR")
        XCTAssertTrue(decoded.isUserAdded)
        XCTAssertTrue(decoded.isAvailable)
        XCTAssertTrue(decoded.isDefaultEnabled)
        XCTAssertEqual(decoded.defaultValue, "some-value")
    }

    func testPredefinedDoesNotEncodeUserAddedField() throws {
        let envVar = predefined.first!
        let encoded = try JSONEncoder().encode(envVar)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertNil(json["isUserAdded"], "Predefined env vars should not encode isUserAdded")
    }

    func testEmptyDefaultValueNotEncoded() throws {
        let envVar = predefined.first!
        let encoded = try JSONEncoder().encode(envVar)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertNil(json["defaultValue"], "Empty defaultValue should not be encoded")
    }

    func testNonEmptyDefaultValueEncoded() throws {
        var envVar = predefined.first!
        envVar.defaultValue = "test"
        let encoded = try JSONEncoder().encode(envVar)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertEqual(json["defaultValue"] as? String, "test")
    }
}

@MainActor
final class EnvVarSettingsPersistenceTests: XCTestCase {
    func testEnvVarOptionsDefaultCount() {
        let settings = AppSettings()
        XCTAssertEqual(settings.envVarOptions.count, EnvVarConfig.all.count)
    }

    func testSaveAndRestoreEnvVarOptions() {
        let settings = AppSettings()
        if let index = settings.envVarOptions.firstIndex(where: { $0.id == "ANTHROPIC_API_KEY" }) {
            settings.envVarOptions[index].isAvailable = true
            settings.envVarOptions[index].isDefaultEnabled = true
            settings.envVarOptions[index].defaultValue = "sk-test-key"
        }
        SettingsPersistence.saveEnvVarOptions(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreEnvVarOptions(into: restored)

        let restoredOption = restored.envVarOptions.first { $0.id == "ANTHROPIC_API_KEY" }
        XCTAssertNotNil(restoredOption)
        XCTAssertTrue(restoredOption!.isAvailable)
        XCTAssertTrue(restoredOption!.isDefaultEnabled)
        XCTAssertEqual(restoredOption!.defaultValue, "sk-test-key")
    }

    func testRestorePreservesNewPredefinedVars() {
        let settings = AppSettings()
        SettingsPersistence.saveEnvVarOptions(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreEnvVarOptions(into: restored)

        XCTAssertEqual(restored.envVarOptions.count, EnvVarConfig.all.count)
    }

    func testRestorePreservesUserAddedVars() {
        let settings = AppSettings()
        settings.envVarOptions.append(EnvVarConfig.makeUserAdded(id: "MY_CUSTOM_VAR"))
        SettingsPersistence.saveEnvVarOptions(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreEnvVarOptions(into: restored)

        let custom = restored.envVarOptions.first { $0.id == "MY_CUSTOM_VAR" }
        XCTAssertNotNil(custom)
        XCTAssertTrue(custom!.isUserAdded)
    }
}
