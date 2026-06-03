import Foundation
import SQLite3

struct StatusProviderContext {
    let paneID: UUID
    let paneName: String
    let tabID: UUID
    let tabName: String
    let workingDirectory: String
    let harness: Harness
    let processStartTime: Date
    let launchArgs: [String]
    let environment: [String: String]
    let detectedHarnessVersion: String?
}

struct CodexThreadState: Equatable {
    let id: String
    let rolloutPath: String?
    let model: String?
    let cliVersion: String?
    let tokensUsed: Int?
    let gitBranch: String?
}

enum CodexVersionAdapter {
    static func supports(_ version: String?) -> Bool {
        guard let version else { return false }
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized =
            trimmed
            .replacingOccurrences(of: "codex-cli", with: "")
            .replacingOccurrences(of: "codex", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.hasPrefix("0.136.")
    }
}

final class CodexStateStore {
    let databaseURL: URL

    init(databaseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/state_5.sqlite")) {
        self.databaseURL = databaseURL
    }

    func selectThread(cwd: String, processStartTime: Date) throws -> CodexThreadState? {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &db, flags, nil) == SQLITE_OK, let db else {
            defer { if db != nil { sqlite3_close(db) } }
            throw CodexStateStoreError.openFailed(message: db.map { String(cString: sqlite3_errmsg($0)) } ?? "nil db")
        }
        defer { sqlite3_close(db) }

        let columns = try availableColumns(db: db)
        let required = Set(["id", "cwd"])
        guard required.isSubset(of: columns) else {
            throw CodexStateStoreError.schemaUnavailable
        }

        let selectedColumns = [
            "id",
            columns.contains("rollout_path") ? "rollout_path" : "NULL AS rollout_path",
            columns.contains("model") ? "model" : "NULL AS model",
            columns.contains("cli_version") ? "cli_version" : "NULL AS cli_version",
            columns.contains("tokens_used") ? "tokens_used" : "NULL AS tokens_used",
            columns.contains("git_branch") ? "git_branch" : "NULL AS git_branch",
            columns.contains("created_at_ms") ? "created_at_ms" : "0 AS created_at_ms",
            columns.contains("updated_at_ms") ? "updated_at_ms" : "0 AS updated_at_ms",
        ].joined(separator: ", ")
        let afterStartPredicate =
            columns.contains("created_at_ms") || columns.contains("updated_at_ms")
            ? "AND (created_at_ms >= ?2 OR updated_at_ms >= ?2)" : ""
        let sql = """
            SELECT \(selectedColumns)
            FROM threads
            WHERE cwd = ?1 \(afterStartPredicate)
            ORDER BY updated_at_ms DESC, created_at_ms DESC
            LIMIT 2
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CodexStateStoreError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, cwd, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if afterStartPredicate.isEmpty == false {
            sqlite3_bind_int64(statement, 2, Int64(processStartTime.timeIntervalSince1970 * 1000))
        }

        var rows: [CodexThreadState] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(
                CodexThreadState(
                    id: text(statement, 0) ?? "",
                    rolloutPath: text(statement, 1),
                    model: text(statement, 2),
                    cliVersion: text(statement, 3),
                    tokensUsed: optionalInt(statement, 4),
                    gitBranch: text(statement, 5)
                ))
        }
        if rows.count > 1 {
            throw CodexStateStoreError.ambiguousSession
        }
        return rows.first
    }

    private func availableColumns(db: OpaquePointer) throws -> Set<String> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(threads)", -1, &statement, nil) == SQLITE_OK,
            let statement
        else {
            throw CodexStateStoreError.schemaUnavailable
        }
        defer { sqlite3_finalize(statement) }
        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = text(statement, 1) {
                columns.insert(name)
            }
        }
        guard !columns.isEmpty else { throw CodexStateStoreError.schemaUnavailable }
        return columns
    }

    private func text(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let raw = sqlite3_column_text(statement, index) else { return nil }
        let value = String(cString: raw)
        return value.isEmpty ? nil : value
    }

    private func optionalInt(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, index))
    }
}

enum CodexStateStoreError: Error, Equatable {
    case openFailed(message: String)
    case schemaUnavailable
    case queryFailed(message: String)
    case ambiguousSession
}

struct CodexRolloutParser {
    static func parseLine(_ data: Data, expectedCWD: String) -> StatusLineData? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String
        else { return nil }

        if type == "session_meta" {
            let cwd = object["cwd"] as? String ?? object["workspace"] as? String
            guard cwd == nil || cwd == expectedCWD else { return nil }
            return StatusLineData(
                model: (object["model"] as? String).map { StatusLineData.Model(id: $0, displayName: $0) },
                cost: nil,
                contextWindow: nil,
                rateLimits: nil,
                worktree: nil,
                workspace: nil,
                effort: nil,
                thinking: nil,
                agent: nil,
                outputStyle: nil,
                vim: nil,
                sessionName: nil,
                version: object["cli_version"] as? String,
                exceeds200kTokens: nil,
                pr: nil,
                sessionStatus: nil
            )
        }

        guard type == "event_msg",
            let payload = object["payload"] as? [String: Any],
            payload["type"] as? String == "token_count"
        else { return nil }

        let usage = payload["total_token_usage"] as? [String: Any]
        let input = int(usage?["input_tokens"]) ?? int(usage?["total_input_tokens"])
        let output = int(usage?["output_tokens"]) ?? int(usage?["total_output_tokens"])
        let contextWindow = int(payload["model_context_window"]) ?? int(usage?["model_context_window"])
        let used = (input ?? 0) + (output ?? 0)
        let usedPct = contextWindow.flatMap { $0 > 0 ? Int((Double(used) / Double($0)) * 100) : nil }
        let remainingPct = usedPct.map { max(0, 100 - $0) }

        return StatusLineData(
            model: (payload["model"] as? String).map { StatusLineData.Model(id: $0, displayName: $0) },
            cost: nil,
            contextWindow: StatusLineData.ContextWindow(
                usedPercentage: usedPct,
                remainingPercentage: remainingPct,
                totalInputTokens: input,
                totalOutputTokens: output
            ),
            rateLimits: rateLimits(from: payload["rate_limits"] as? [String: Any]),
            worktree: nil,
            workspace: nil,
            effort: nil,
            thinking: nil,
            agent: nil,
            outputStyle: nil,
            vim: nil,
            sessionName: nil,
            version: nil,
            exceeds200kTokens: nil,
            pr: nil,
            sessionStatus: nil
        )
    }

    private static func rateLimits(from raw: [String: Any]?) -> StatusLineData.RateLimits? {
        guard let raw else { return nil }
        return StatusLineData.RateLimits(
            fiveHour: rate(raw["primary"] as? [String: Any], expectedWindowMinutes: 300),
            sevenDay: rate(raw["secondary"] as? [String: Any], expectedWindowMinutes: 10_080)
        )
    }

    private static func rate(_ raw: [String: Any]?, expectedWindowMinutes: Int) -> StatusLineData.RateLimit? {
        guard let raw, int(raw["window_minutes"]) == expectedWindowMinutes else { return nil }
        return StatusLineData.RateLimit(
            usedPercentage: double(raw["used_percentage"]),
            resetsAt: int(raw["resets_at"])
        )
    }

    private static func int(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        return nil
    }
}

final class CodexRolloutTailer {
    let rolloutPath: String
    let expectedCWD: String
    var onUpdate: ((StatusLineData) -> Void)?
    private var source: DispatchSourceFileSystemObject?
    private var offset: UInt64 = 0

    init(rolloutPath: String, expectedCWD: String) {
        self.rolloutPath = rolloutPath
        self.expectedCWD = expectedCWD
    }

    func start() {
        readNewLines()
        let fd = open(rolloutPath, O_EVTONLY)
        guard fd >= 0 else { return }
        let watcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        watcher.setEventHandler { [weak self] in
            self?.readNewLines()
        }
        watcher.setCancelHandler { close(fd) }
        watcher.resume()
        source = watcher
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func readNewLines() {
        guard let handle = FileHandle(forReadingAtPath: rolloutPath) else { return }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            offset += UInt64(data.count)
            for line in data.split(separator: UInt8(ascii: "\n")).prefix(200) {
                guard line.count <= 64 * 1024 else { continue }
                if let update = CodexRolloutParser.parseLine(Data(line), expectedCWD: expectedCWD) {
                    onUpdate?(update)
                }
            }
        } catch {}
    }
}

final class CodexStatusProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?
    var onAttention: ((PaneAttentionEvent) -> Void)?

    private let context: StatusProviderContext
    private let stateStore: CodexStateStore
    private let baseline: ToolAgnosticDataProvider
    private var tailer: CodexRolloutTailer?
    private var latestHarnessData: StatusLineData?
    private var latestBaselineData: StatusLineData?

    init(context: StatusProviderContext, stateStore: CodexStateStore = CodexStateStore()) {
        self.context = context
        self.stateStore = stateStore
        self.baseline = ToolAgnosticDataProvider(
            workingDirectory: context.workingDirectory,
            toolCommand: context.harness.commandDescription,
            processStartTime: context.processStartTime
        )
    }

    func start() {
        trace("statusline.provider.started", provider: "codex")
        baseline.onUpdate = { [weak self] data in
            guard let self else { return }
            self.latestBaselineData = data
            self.emitMerged()
        }
        baseline.start()
        Task { [weak self] in
            await self?.loadCodexState()
        }
    }

    func stop() {
        baseline.stop()
        tailer?.stop()
        tailer = nil
        trace("statusline.provider.stopped", provider: "codex")
    }

    private func loadCodexState() async {
        do {
            guard
                let thread = try stateStore.selectThread(
                    cwd: context.workingDirectory,
                    processStartTime: context.processStartTime
                )
            else { return }
            let stateData = StatusLineData(
                model: thread.model.map { StatusLineData.Model(id: $0, displayName: $0) },
                cost: nil,
                contextWindow: thread.tokensUsed.map {
                    StatusLineData.ContextWindow(
                        usedPercentage: nil,
                        remainingPercentage: nil,
                        totalInputTokens: $0,
                        totalOutputTokens: nil)
                },
                rateLimits: nil,
                worktree: nil,
                workspace: nil,
                effort: nil,
                thinking: nil,
                agent: nil,
                outputStyle: nil,
                vim: nil,
                sessionName: nil,
                version: thread.cliVersion ?? context.detectedHarnessVersion,
                exceeds200kTokens: nil,
                pr: nil,
                sessionStatus: nil
            )
            await MainActor.run {
                self.latestHarnessData = stateData
                self.emitMerged()
            }
            guard CodexVersionAdapter.supports(thread.cliVersion ?? context.detectedHarnessVersion) else {
                trace("statusline.codex.schema_unsupported", provider: "codex")
                return
            }
            guard let rolloutPath = thread.rolloutPath, FileManager.default.fileExists(atPath: rolloutPath) else {
                trace("statusline.codex.rollout_unavailable", provider: "codex")
                return
            }
            await MainActor.run {
                self.startTailer(path: rolloutPath)
            }
        } catch CodexStateStoreError.ambiguousSession {
            trace("statusline.provider.update_failed", provider: "codex")
            trace("statusline.codex.session_ambiguous", provider: "codex")
        } catch {
            trace("statusline.provider.update_failed", provider: "codex")
            trace("statusline.codex.state_unavailable", provider: "codex")
        }
    }

    private func startTailer(path: String) {
        tailer?.stop()
        let next = CodexRolloutTailer(rolloutPath: path, expectedCWD: context.workingDirectory)
        next.onUpdate = { [weak self] data in
            guard let self else { return }
            self.latestHarnessData = self.mergeHarnessData(data)
            self.emitMerged()
        }
        tailer = next
        next.start()
    }

    private func mergeHarnessData(_ update: StatusLineData) -> StatusLineData {
        var merged = latestHarnessData ?? update
        if let model = update.model { merged.model = model }
        if let contextWindow = update.contextWindow { merged.contextWindow = contextWindow }
        if let rateLimits = update.rateLimits { merged.rateLimits = rateLimits }
        if let version = update.version { merged.version = version }
        return merged
    }

    private func emitMerged() {
        guard var data = latestBaselineData else { return }
        if let harness = latestHarnessData {
            if harness.model != nil { data.model = harness.model }
            if let contextWindow = harness.contextWindow { data.contextWindow = contextWindow }
            if let rateLimits = harness.rateLimits { data.rateLimits = rateLimits }
            if let version = harness.version { data.version = version }
        }
        trace("statusline.provider.update_applied", provider: "codex")
        onUpdate?(data)
    }

    private func trace(_ name: String, provider: String) {
        TracingService.shared.record(
            name,
            attributes: [
                "provider": provider,
                "pane.name": context.paneName,
                "pane.id": context.paneID.uuidString,
                "tab.id": context.tabID.uuidString,
                "tab.name": context.tabName,
            ])
    }
}
