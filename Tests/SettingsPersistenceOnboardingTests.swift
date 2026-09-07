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

    private func restoreShellSettings(into settings: AppSettings) {
        guard let config = SettingsPersistence.load(SettingsPersistence.ShellSettings.self, from: "shell-settings.json")
        else { return }
        settings.preferredShell = config.preferredShell
    }

    private func restoreOnboarding(into settings: AppSettings) {
        guard
            let config = SettingsPersistence.load(
                SettingsPersistence.OnboardingSettings.self, from: "onboarding-settings.json")
        else { return }
        settings.hasCompletedOnboarding = config.completed
    }

    func testSaveAndRestoreShellSettings() {
        let settings = AppSettings()
        settings.preferredShell = "/bin/bash"
        SettingsPersistence.saveShellSettings(appSettings: settings)

        let restored = AppSettings()
        restoreShellSettings(into: restored)
        XCTAssertEqual(restored.preferredShell, "/bin/bash")
    }

    func testRestoreShellSettingsDefaultsToEmptyWhenMissing() {
        let settings = AppSettings()
        restoreShellSettings(into: settings)
        XCTAssertEqual(settings.preferredShell, "")
    }

    func testSaveAndRestoreEmptyPreferredShell() {
        let settings = AppSettings()
        settings.preferredShell = ""
        SettingsPersistence.saveShellSettings(appSettings: settings)

        let restored = AppSettings()
        restored.preferredShell = "/was-set"
        restoreShellSettings(into: restored)
        XCTAssertEqual(restored.preferredShell, "")
    }

    func testSaveAndRestoreOnboardingCompleted() {
        let settings = AppSettings()
        settings.hasCompletedOnboarding = true
        SettingsPersistence.save(
            SettingsPersistence.OnboardingSettings(completed: settings.hasCompletedOnboarding),
            to: "onboarding-settings.json")

        let restored = AppSettings()
        restoreOnboarding(into: restored)
        XCTAssertTrue(restored.hasCompletedOnboarding)
    }

    func testRestoreOnboardingDefaultsToFalseWhenMissing() {
        let settings = AppSettings()
        restoreOnboarding(into: settings)
        XCTAssertFalse(settings.hasCompletedOnboarding)
    }

    func testSaveAndRestoreOnboardingNotCompleted() {
        let settings = AppSettings()
        settings.hasCompletedOnboarding = false
        SettingsPersistence.save(
            SettingsPersistence.OnboardingSettings(completed: settings.hasCompletedOnboarding),
            to: "onboarding-settings.json")

        let restored = AppSettings()
        restored.hasCompletedOnboarding = true
        restoreOnboarding(into: restored)
        XCTAssertFalse(restored.hasCompletedOnboarding)
    }

    func testWizardApplyAddsCheckedTools() {
        let settings = AppSettings()
        settings.activeTools = [Harness.claude.rawValue]

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
        settings.activeTools = [Harness.claude.rawValue, Harness.codex.rawValue]

        settings.setActive(.cursor, true)
        XCTAssertTrue(settings.isActive(.claude))
        XCTAssertTrue(settings.isActive(.codex))
        XCTAssertTrue(settings.isActive(.cursor))
    }
}
