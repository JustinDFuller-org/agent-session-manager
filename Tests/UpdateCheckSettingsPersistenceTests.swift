import XCTest

@testable import AgentSessionManager

@MainActor
final class UpdateCheckSettingsPersistenceTests: XCTestCase {
    private let testDir = "agent-session-manager-test-update-check-\(UUID().uuidString)"

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

    func testSaveAndRestoreDisabledReminder() {
        let settings = AppSettings()
        settings.updateReminderEnabled = false
        SettingsPersistence.saveUpdateCheckSettings(appSettings: settings)

        XCTAssertFalse(SettingsPersistence.isUpdateReminderEnabled())
    }

    func testDefaultsToEnabledWhenMissing() {
        XCTAssertTrue(SettingsPersistence.isUpdateReminderEnabled())
    }

    func testSaveAndRestoreEnabledReminder() {
        let settings = AppSettings()
        settings.updateReminderEnabled = true
        SettingsPersistence.saveUpdateCheckSettings(appSettings: settings)

        XCTAssertTrue(SettingsPersistence.isUpdateReminderEnabled())
    }
}
