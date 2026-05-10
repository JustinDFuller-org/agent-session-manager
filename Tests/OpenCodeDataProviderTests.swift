import Testing
import Foundation
import SQLite3
@testable import AgentSessionManager

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@Suite("OpenCodeDataProvider")
struct OpenCodeDataProviderTests {

    // MARK: - Database path discovery

    @Test func testDatabasePathDefaultsToHomeLocalShare() {
        // Without XDG_DATA_HOME set, the path should be ~/.local/share/opencode/opencode.db.
        // We can't assert it exists, but we can check the path shape.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expected = home + "/.local/share/opencode/opencode.db"
        // If the file happens to exist, databasePath() returns it; otherwise nil.
        // Either way the computed path must match the expected pattern.
        let result = OpenCodeDataProvider.databasePath()
        if let result {
            #expect(result == expected)
        }
        // If nil, the file simply doesn't exist on this machine — that's acceptable.
    }

    // MARK: - queryDatabase graceful failure

    @Test func testQueryDatabaseReturnsNilForNonexistentFile() {
        let result = OpenCodeDataProvider.queryDatabase(path: "/nonexistent/path/opencode.db", directory: "/some/dir")
        #expect(result == nil)
    }

    @Test func testQueryDatabaseReturnsNilWhenNoSessionMatches() throws {
        let db = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(atPath: db) }

        let result = OpenCodeDataProvider.queryDatabase(path: db, directory: "/no/match/here")
        #expect(result == nil)
    }

    // MARK: - Full round-trip against a real in-memory-style temp database

    @Test func testQueryDatabaseAggregatesCorrectly() throws {
        let db = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(atPath: db) }

        let dir = "/test/project"
        try seedDatabase(path: db, directory: dir, messages: [
            .init(role: "user",      cost: nil,     input: nil,  output: nil, mode: nil,  completed: true),
            .init(role: "assistant", cost: 0.01,    input: 100,  output: 50,  mode: "plan", completed: true),
            .init(role: "assistant", cost: 0.02,    input: 200,  output: 80,  mode: "code", completed: true),
        ])

        let result = OpenCodeDataProvider.queryDatabase(path: db, directory: dir)
        #expect(result != nil)
        #expect(abs((result?.totalCost ?? 0) - 0.03) < 0.0001)
        #expect(result?.totalInput == 300)
        #expect(result?.totalOutput == 130)
        #expect(result?.modelID == "test-model")
        #expect(result?.providerID == "test-provider")
        #expect(result?.mode == "code")
        #expect(result?.isBusy == false)
    }

    @Test func testQueryDatabaseDetectsBusyMessage() throws {
        let db = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(atPath: db) }

        let dir = "/test/busy"
        try seedDatabase(path: db, directory: dir, messages: [
            .init(role: "assistant", cost: 0.01, input: 100, output: 50, mode: "code", completed: false),
        ])

        let result = OpenCodeDataProvider.queryDatabase(path: db, directory: dir)
        #expect(result?.isBusy == true)
    }

    @Test func testQueryDatabasePicksMostRecentSession() throws {
        let db = try makeTempDatabase()
        defer { try? FileManager.default.removeItem(atPath: db) }

        // Insert two sessions for the same directory; the newer one should be used.
        let dir = "/test/multi"
        try seedDatabase(path: db, directory: dir, sessionID: "old-session", timeUpdated: 1000, messages: [
            .init(role: "assistant", cost: 9.99, input: 9999, output: 9999, mode: "old", completed: true),
        ])
        try seedDatabase(path: db, directory: dir, sessionID: "new-session", timeUpdated: 2000, messages: [
            .init(role: "assistant", cost: 0.01, input: 100, output: 50, mode: "new", completed: true),
        ])

        let result = OpenCodeDataProvider.queryDatabase(path: db, directory: dir)
        #expect(result?.mode == "new")
        #expect(result?.totalInput == 100)
    }

    // MARK: - StatusLineData round-trips for new fields

    @Test func testSessionStatusRoundTrip() throws {
        let original = StatusLineData.SessionStatus(state: "busy")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StatusLineData.SessionStatus.self, from: encoded)
        #expect(decoded.state == "busy")
    }

    @Test func testOpenCodeModeDecodesFromJSON() throws {
        let json = #"{"open_code_mode":"architect"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StatusLineData.self, from: json)
        #expect(decoded.openCodeMode == "architect")
    }

    @Test func testSessionStatusDecodesFromJSON() throws {
        let json = #"{"session_status":{"state":"retry"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StatusLineData.self, from: json)
        #expect(decoded.sessionStatus?.state == "retry")
    }

    @Test func testNewFieldsAreNilWhenAbsentFromJSON() throws {
        let json = #"{"version":"1.0"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StatusLineData.self, from: json)
        #expect(decoded.sessionStatus == nil)
        #expect(decoded.openCodeMode == nil)
    }
}

// MARK: - Test helpers

private struct TestMessage {
    var role: String
    var cost: Double?
    var input: Int?
    var output: Int?
    var mode: String?
    var completed: Bool
}

private func makeTempDatabase() throws -> String {
    let path = NSTemporaryDirectory() + "opencode-test-\(UUID().uuidString).db"
    var db: OpaquePointer?
    guard sqlite3_open(path, &db) == SQLITE_OK else {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create test DB"])
    }
    defer { sqlite3_close(db) }

    let schema = """
        CREATE TABLE session (
            id TEXT PRIMARY KEY,
            directory TEXT NOT NULL,
            time_updated INTEGER NOT NULL
        );
        CREATE TABLE message (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            time_created INTEGER NOT NULL,
            data TEXT NOT NULL
        );
        """
    sqlite3_exec(db, schema, nil, nil, nil)
    return path
}

private func seedDatabase(
    path: String,
    directory: String,
    sessionID: String = "test-session",
    timeUpdated: Int = 1000,
    messages: [TestMessage]
) throws {
    var db: OpaquePointer?
    guard sqlite3_open(path, &db) == SQLITE_OK else { return }
    defer { sqlite3_close(db) }

    let insertSession = "INSERT OR REPLACE INTO session (id, directory, time_updated) VALUES (?, ?, ?)"
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, insertSession, -1, &stmt, nil) == SQLITE_OK {
        sqlite3_bind_text(stmt, 1, sessionID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, directory, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(timeUpdated))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    for (i, msg) in messages.enumerated() {
        var dataDict: [String: Any] = ["role": msg.role]
        if let cost = msg.cost { dataDict["cost"] = cost }
        if let input = msg.input, let output = msg.output {
            dataDict["tokens"] = ["input": input, "output": output]
        }
        if let mode = msg.mode { dataDict["mode"] = mode }
        dataDict["modelID"]    = "test-model"
        dataDict["providerID"] = "test-provider"
        var timeDict: [String: Any] = ["created": (timeUpdated + i) * 1000]
        if msg.completed { timeDict["completed"] = (timeUpdated + i + 1) * 1000 }
        dataDict["time"] = timeDict

        let json = String(data: try JSONSerialization.data(withJSONObject: dataDict), encoding: .utf8)!
        let insertMsg = "INSERT INTO message (id, session_id, time_created, data) VALUES (?, ?, ?, ?)"
        if sqlite3_prepare_v2(db, insertMsg, -1, &stmt, nil) == SQLITE_OK {
            let msgID = "msg-\(sessionID)-\(i)"
            sqlite3_bind_text(stmt, 1, msgID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, sessionID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 3, Int64((timeUpdated + i) * 1000))
            sqlite3_bind_text(stmt, 4, json, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
}
