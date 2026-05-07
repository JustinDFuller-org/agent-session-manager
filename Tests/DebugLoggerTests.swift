import XCTest
@testable import AgentSessionManager

@MainActor
final class DebugLoggerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DebugLogger.shared.isEnabled = false
        DebugLogger.shared.clear()
    }

    override func tearDown() {
        DebugLogger.shared.isEnabled = false
        DebugLogger.shared.clear()
        super.tearDown()
    }

    func testNoEntriesWhenDisabled() {
        DebugLogger.shared.isEnabled = false
        DebugLogger.shared.log("test message")
        XCTAssertEqual(DebugLogger.shared.entries.count, 0)
    }

    func testEntriesRecordedWhenEnabled() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("test message")
        XCTAssertEqual(DebugLogger.shared.entries.count, 1)
        XCTAssertEqual(DebugLogger.shared.entries.first?.message, "test message")
    }

    func testClearRemovesAllEntries() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("msg 1")
        DebugLogger.shared.log("msg 2")
        XCTAssertEqual(DebugLogger.shared.entries.count, 2)
        DebugLogger.shared.clear()
        XCTAssertEqual(DebugLogger.shared.entries.count, 0)
    }

    func testEntriesHaveUniqueIDs() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("msg 1")
        DebugLogger.shared.log("msg 2")
        let ids = Set(DebugLogger.shared.entries.map(\.id))
        XCTAssertEqual(ids.count, 2)
    }

    func testEntriesHaveTimestamps() {
        DebugLogger.shared.isEnabled = true
        let before = Date()
        DebugLogger.shared.log("test")
        let after = Date()
        guard let entry = DebugLogger.shared.entries.first else {
            XCTFail("No entry recorded")
            return
        }
        XCTAssertGreaterThanOrEqual(entry.timestamp, before)
        XCTAssertLessThanOrEqual(entry.timestamp, after)
    }

    func testLogProcessStartRecordsDetails() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.logProcessStart(
            executable: "/bin/zsh",
            args: ["-l", "-i", "-c", "claude --settings /tmp/settings.json"],
            environment: ["HOME=/Users/test", "PATH=/usr/bin", "SECRET_KEY=abcdef123456"],
            currentDirectory: "/Users/test/project"
        )
        XCTAssertEqual(DebugLogger.shared.entries.count, 1)
        let msg = DebugLogger.shared.entries.first?.message ?? ""
        XCTAssertTrue(msg.contains("executable: /bin/zsh"))
        XCTAssertTrue(msg.contains("claude --settings /tmp/settings.json"))
        XCTAssertTrue(msg.contains("cwd: /Users/test/project"))
        XCTAssertTrue(msg.contains("HOME=/Users/test"))
        XCTAssertTrue(msg.contains("PATH=/usr/bin"))
        XCTAssertTrue(msg.contains("SECRET_KEY=abcdef123456"))
        XCTAssertTrue(msg.contains("environment (3 vars)"))
    }

    func testLogProcessStartWithoutEnvironment() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.logProcessStart(
            executable: "/bin/zsh",
            args: [],
            environment: nil,
            currentDirectory: nil
        )
        let msg = DebugLogger.shared.entries.first?.message ?? ""
        XCTAssertTrue(msg.contains("executable: /bin/zsh"))
        XCTAssertFalse(msg.contains("environment"))
    }

    func testLogProcessStartTruncatesLongValues() {
        DebugLogger.shared.isEnabled = true
        let longValue = String(repeating: "x", count: 300)
        DebugLogger.shared.logProcessStart(
            executable: "/bin/zsh",
            args: [],
            environment: ["LONGVAR=\(longValue)"],
            currentDirectory: nil
        )
        let msg = DebugLogger.shared.entries.first?.message ?? ""
        XCTAssertTrue(msg.contains("…"))
    }

    func testLogGitCommandRecordsDetails() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.logGitCommand(["worktree", "list", "--porcelain"], cwd: "/Users/test/repo")
        XCTAssertEqual(DebugLogger.shared.entries.count, 1)
        let msg = DebugLogger.shared.entries.first?.message ?? ""
        XCTAssertTrue(msg.contains("git worktree list --porcelain"))
        XCTAssertTrue(msg.contains("cwd: /Users/test/repo"))
    }

    func testLogSessionRestoreRecordsSummary() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.logSessionRestore(summary: "Restoring 3 tab(s)")
        XCTAssertEqual(DebugLogger.shared.entries.count, 1)
        let msg = DebugLogger.shared.entries.first?.message ?? ""
        XCTAssertTrue(msg.contains("Restoring 3 tab(s)"))
        XCTAssertTrue(msg.contains("Session Restore"))
    }

    func testLogWorktreeResolutionRecordsDetails() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.logWorktreeResolution(userRef: "feature-branch", result: "dir: /path/to/worktree, managed: true")
        XCTAssertEqual(DebugLogger.shared.entries.count, 1)
        let msg = DebugLogger.shared.entries.first?.message ?? ""
        XCTAssertTrue(msg.contains("ref: feature-branch"))
        XCTAssertTrue(msg.contains("result: dir: /path/to/worktree"))
        XCTAssertTrue(msg.contains("Worktree Resolution"))
    }

    func testDisabledLoggerDoesNotRecordAnyLogMethod() {
        DebugLogger.shared.isEnabled = false
        DebugLogger.shared.log("plain")
        DebugLogger.shared.logProcessStart(executable: "/bin/sh", args: [], environment: nil, currentDirectory: nil)
        DebugLogger.shared.logGitCommand(["status"], cwd: "/tmp")
        DebugLogger.shared.logSessionRestore(summary: "restore")
        DebugLogger.shared.logWorktreeResolution(userRef: "ref", result: "result")
        XCTAssertEqual(DebugLogger.shared.entries.count, 0)
    }

    func testLogProcessStartEnvironmentKeyWithoutValue() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.logProcessStart(
            executable: "/bin/zsh",
            args: [],
            environment: ["EMPTY_VAR="],
            currentDirectory: nil
        )
        let msg = DebugLogger.shared.entries.first?.message ?? ""
        XCTAssertTrue(msg.contains("EMPTY_VAR="))
    }

    func testDebugLoggingEnabledDefaultsFalse() {
        let settings = AppSettings()
        XCTAssertFalse(settings.debugLoggingEnabled)
    }

    func testDebugSettingsPersistRoundTrip() throws {
        let settings = AppSettings()
        settings.debugLoggingEnabled = true
        SettingsPersistence.saveDebugSettings(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreDebugSettings(into: restored)
        XCTAssertTrue(restored.debugLoggingEnabled)
    }

    func testDebugSettingsPersistFalse() throws {
        let settings = AppSettings()
        settings.debugLoggingEnabled = false
        SettingsPersistence.saveDebugSettings(appSettings: settings)

        let restored = AppSettings()
        restored.debugLoggingEnabled = true
        SettingsPersistence.restoreDebugSettings(into: restored)
        XCTAssertFalse(restored.debugLoggingEnabled)
    }

    func testClearPersistedDebugSettingsFile() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let file = support.appending(path: "agent-session-manager/debug-settings.json")
        try? FileManager.default.removeItem(at: file)

        let restored = AppSettings()
        restored.debugLoggingEnabled = true
        SettingsPersistence.restoreDebugSettings(into: restored)
        XCTAssertTrue(restored.debugLoggingEnabled)
    }
}
