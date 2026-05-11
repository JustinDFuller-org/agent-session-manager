import Foundation
import SQLite3

// sqlite3_destructor_type constant required when binding Swift strings to SQLite3 statements.
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class OpenCodeDataProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?

    private let workingDirectory: String
    private let processStartTime: Date
    private var refreshTimer: Timer?

    init(workingDirectory: String, processStartTime: Date) {
        self.workingDirectory = workingDirectory
        self.processStartTime = processStartTime
    }

    func start() {
        Task { [weak self] in await self?.refreshNow() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refreshNow() }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    var currentDurationMs: Double {
        max(0, Date().timeIntervalSince(processStartTime)) * 1000
    }

    // MARK: - Refresh

    private func refreshNow() async {
        let branch = await runShell("git branch --show-current 2>/dev/null")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let wd = workingDirectory

        var modelInfo: StatusLineData.Model?
        var contextWindow: StatusLineData.ContextWindow?
        var costInfo: StatusLineData.Cost?
        var sessionStatus: StatusLineData.SessionStatus?
        var openCodeMode: String?

        if let dbPath = Self.databasePath(),
            let result = Self.queryDatabase(path: dbPath, directory: wd)
        {
            if result.totalInput > 0 || result.totalOutput > 0 {
                contextWindow = StatusLineData.ContextWindow(
                    usedPercentage: nil,
                    remainingPercentage: nil,
                    totalInputTokens: result.totalInput,
                    totalOutputTokens: result.totalOutput
                )
            }
            if result.totalCost > 0 {
                costInfo = StatusLineData.Cost(
                    totalCostUsd: result.totalCost,
                    totalDurationMs: currentDurationMs,
                    totalLinesAdded: nil,
                    totalLinesRemoved: nil
                )
            }
            if let modelID = result.modelID {
                let parts = [result.providerID, modelID].compactMap { $0 }
                let id = parts.joined(separator: "/")
                modelInfo = StatusLineData.Model(id: id, displayName: id)
            }
            sessionStatus = StatusLineData.SessionStatus(state: result.isBusy ? "busy" : "idle")
            openCodeMode = result.mode
        }

        let data = StatusLineData(
            model: modelInfo,
            cost: costInfo
                ?? StatusLineData.Cost(
                    totalCostUsd: nil,
                    totalDurationMs: currentDurationMs,
                    totalLinesAdded: nil,
                    totalLinesRemoved: nil
                ),
            contextWindow: contextWindow,
            rateLimits: nil,
            worktree: StatusLineData.Worktree(
                name: URL(filePath: wd).lastPathComponent,
                branch: branch
            ),
            workspace: StatusLineData.Workspace(gitWorktree: wd),
            effort: nil,
            thinking: nil,
            agent: nil,
            outputStyle: nil,
            vim: nil,
            sessionName: nil,
            version: nil,
            exceeds200kTokens: nil,
            sessionStatus: sessionStatus,
            openCodeMode: openCodeMode,
            pr: nil
        )

        await MainActor.run { [weak self] in
            self?.onUpdate?(data)
        }
    }

    // MARK: - Database Path

    /// Returns the path to the OpenCode SQLite database if it exists.
    static func databasePath() -> String? {
        let base: String
        if let xdg = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], !xdg.isEmpty {
            base = xdg
        } else {
            base =
                FileManager.default.homeDirectoryForCurrentUser
                .appending(path: ".local/share")
                .path
        }
        let path = base + "/opencode/opencode.db"
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    // MARK: - SQLite Query Result

    struct QueryResult {
        var totalCost: Double
        var totalInput: Int
        var totalOutput: Int
        var modelID: String?
        var providerID: String?
        var mode: String?
        var isBusy: Bool
    }

    // MARK: - SQLite Queries (synchronous, called from async context)

    /// Queries the OpenCode database for the latest session matching `directory`
    /// and returns aggregated message data. Returns nil if the database cannot
    /// be opened or no session exists for the given directory.
    static func queryDatabase(path: String, directory: String) -> QueryResult? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        guard let sessionID = querySessionID(db: db, directory: directory) else { return nil }
        return queryMessages(db: db, sessionID: sessionID)
    }

    private static func querySessionID(db: OpaquePointer?, directory: String) -> String? {
        let sql = "SELECT id FROM session WHERE directory = ? ORDER BY time_updated DESC LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, directory, -1, sqliteTransient)
        guard sqlite3_step(stmt) == SQLITE_ROW,
            let ptr = sqlite3_column_text(stmt, 0)
        else { return nil }
        return String(cString: ptr)
    }

    private static func queryMessages(db: OpaquePointer?, sessionID: String) -> QueryResult {
        var totalCost = 0.0
        var totalInput = 0
        var totalOutput = 0

        let aggSQL = """
            SELECT
              COALESCE(SUM(json_extract(data,'$.cost')), 0),
              COALESCE(SUM(json_extract(data,'$.tokens.input')), 0),
              COALESCE(SUM(json_extract(data,'$.tokens.output')), 0)
            FROM message
            WHERE session_id = ? AND json_extract(data,'$.role') = 'assistant'
            """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, aggSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionID, -1, sqliteTransient)
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalCost = sqlite3_column_double(stmt, 0)
                totalInput = Int(sqlite3_column_int64(stmt, 1))
                totalOutput = Int(sqlite3_column_int64(stmt, 2))
            }
            sqlite3_finalize(stmt)
        }

        var modelID: String?
        var providerID: String?
        var mode: String?
        var isBusy = false

        let latestSQL = """
            SELECT
              json_extract(data,'$.modelID'),
              json_extract(data,'$.providerID'),
              json_extract(data,'$.mode'),
              json_extract(data,'$.time.completed') IS NULL
            FROM message
            WHERE session_id = ? AND json_extract(data,'$.role') = 'assistant'
            ORDER BY time_created DESC
            LIMIT 1
            """
        if sqlite3_prepare_v2(db, latestSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionID, -1, sqliteTransient)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) { modelID = String(cString: ptr) }
                if let ptr = sqlite3_column_text(stmt, 1) { providerID = String(cString: ptr) }
                if let ptr = sqlite3_column_text(stmt, 2) { mode = String(cString: ptr) }
                isBusy = sqlite3_column_int(stmt, 3) != 0
            }
            sqlite3_finalize(stmt)
        }

        return QueryResult(
            totalCost: totalCost,
            totalInput: totalInput,
            totalOutput: totalOutput,
            modelID: modelID,
            providerID: providerID,
            mode: mode,
            isBusy: isBusy
        )
    }

    // MARK: - Shell Helper

    private func runShell(_ command: String) async -> String? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            task.executableURL = URL(filePath: "/bin/zsh")
            task.arguments = ["-c", command]
            task.currentDirectoryURL = URL(filePath: workingDirectory)
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { process in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0, !data.isEmpty {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
