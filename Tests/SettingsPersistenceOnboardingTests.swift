import XCTest

@testable import AgentSessionManager

@MainActor
final class SettingsPersistenceOnboardingTests: XCTestCase {
    private let testDir = "agent-session-manager-test-onboarding-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        PersistenceHelpers.overrideAppSupportSubdirectory = testDir
    }

    override func tearDown() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: base.appending(path: testDir))
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        super.tearDown()
    }

    // MARK: - Shell settings

    func testSaveAndRestoreShellSettings() {
        let settings = AppSettings()
        settings.preferredShell = "/bin/bash"
        SettingsPersistence.saveShellSettings(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreShellSettings(into: restored)
        XCTAssertEqual(restored.preferredShell, "/bin/bash")
    }

    func testRestoreShellSettingsDefaultsToEmptyWhenMissing() {
        let settings = AppSettings()
        SettingsPersistence.restoreShellSettings(into: settings)
        XCTAssertEqual(settings.preferredShell, "")
    }

    func testSaveAndRestoreEmptyPreferredShell() {
        let settings = AppSettings()
        settings.preferredShell = ""
        SettingsPersistence.saveShellSettings(appSettings: settings)

        let restored = AppSettings()
        restored.preferredShell = "/was-set"
        SettingsPersistence.restoreShellSettings(into: restored)
        XCTAssertEqual(restored.preferredShell, "")
    }

    // MARK: - Onboarding settings

    func testSaveAndRestoreOnboardingCompleted() {
        let settings = AppSettings()
        settings.hasCompletedOnboarding = true
        SettingsPersistence.saveOnboarding(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreOnboarding(into: restored)
        XCTAssertTrue(restored.hasCompletedOnboarding)
    }

    func testRestoreOnboardingDefaultsToFalseWhenMissing() {
        let settings = AppSettings()
        SettingsPersistence.restoreOnboarding(into: settings)
        XCTAssertFalse(settings.hasCompletedOnboarding)
    }

    func testSaveAndRestoreOnboardingNotCompleted() {
        let settings = AppSettings()
        settings.hasCompletedOnboarding = false
        SettingsPersistence.saveOnboarding(appSettings: settings)

        let restored = AppSettings()
        restored.hasCompletedOnboarding = true
        SettingsPersistence.restoreOnboarding(into: restored)
        XCTAssertFalse(restored.hasCompletedOnboarding)
    }

    // MARK: - Wizard apply logic

    func testWizardApplyAddsCheckedTools() {
        let settings = AppSettings()
        settings.activeTools = [CLIType.claude.rawValue]

        // Simulate wizard finishing with codex detected and checked
        settings.setActive(.codex, true)
        XCTAssertTrue(settings.isActive(.claude))
        XCTAssertTrue(settings.isActive(.codex))
    }

    func testWizardApplyFallsBackToClaudeWhenEmpty() {
        let settings = AppSettings()
        settings.activeTools = []

        if settings.activeTools.isEmpty {
            settings.setActive(.claude, true)
        }
        XCTAssertTrue(settings.isActive(.claude))
    }

    func testWizardApplyIsAdditive() {
        let settings = AppSettings()
        settings.activeTools = [CLIType.claude.rawValue, CLIType.codex.rawValue]

        // Apply only opencode — existing tools must remain
        settings.setActive(.opencode, true)
        XCTAssertTrue(settings.isActive(.claude))
        XCTAssertTrue(settings.isActive(.codex))
        XCTAssertTrue(settings.isActive(.opencode))
    }
}
