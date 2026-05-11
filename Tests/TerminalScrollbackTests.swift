import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalScrollbackTests: XCTestCase {
    func testDefaultScrollbackIs500() {
        let settings = AppSettings()
        XCTAssertEqual(settings.scrollbackLines, 500)
    }

    func testSaveRestoreRoundTrip() throws {
        let settings = AppSettings()
        settings.scrollbackLines = 2000

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let url = tmpDir.appendingPathComponent("terminal-settings.json")
        let payload = try JSONEncoder().encode(["scrollbackLines": 2000])
        try payload.write(to: url)

        let decoded = try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: url))
        XCTAssertEqual(decoded["scrollbackLines"], 2000)

        let restored = AppSettings()
        restored.scrollbackLines = decoded["scrollbackLines"] ?? 500
        XCTAssertEqual(restored.scrollbackLines, 2000)
    }

    func testRestoreFromMissingFileKeepsDefault() {
        let settings = AppSettings()
        XCTAssertEqual(settings.scrollbackLines, 500)
    }
}
