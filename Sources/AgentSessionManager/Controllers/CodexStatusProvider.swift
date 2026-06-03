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
    let createdAtMs: Int64?
    let updatedAtMs: Int64?
    let isArchived: Bool
    let candidateCount: Int
}

struct CodexThreadSelection: Equatable {
    let thread: CodexThreadState?
    let candidateCount: Int
}

private struct CodexThreadRank {
    let row: CodexThreadState
    let distance: Int64
    let beforeStart: Bool
    let updated: Int64
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

    func selectThread(cwd: String, processStartTime: Date) throws -> CodexThreadSelection {
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
            columns.contains("created_at_ms") ? "created_at_ms" : "NULL AS created_at_ms",
            columns.contains("updated_at_ms") ? "updated_at_ms" : "NULL AS updated_at_ms",
            columns.contains("is_archived")
                ? "is_archived" : columns.contains("archived") ? "archived" : "0 AS archived",
            columns.contains("archived_at_ms") ? "archived_at_ms" : "NULL AS archived_at_ms",
            columns.contains("archived_at") ? "archived_at" : "NULL AS archived_at",
        ].joined(separator: ", ")
        let sql = """
            SELECT \(selectedColumns)
            FROM threads
            WHERE cwd = ?1
            ORDER BY updated_at_ms DESC, created_at_ms DESC
            LIMIT 25
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CodexStateStoreError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, cwd, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        var rows: [CodexThreadState] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let archivedValue = optionalInt(statement, 8) ?? 0
            let archivedText = text(statement, 8)?.lowercased()
            let archivedAtMs = optionalInt64(statement, 9)
            let archivedAt = text(statement, 10)
            let isArchived =
                archivedValue != 0
                || archivedText == "true"
                || archivedText == "yes"
                || (archivedAtMs ?? 0) > 0
                || archivedAt != nil
            rows.append(
                CodexThreadState(
                    id: text(statement, 0) ?? "",
                    rolloutPath: text(statement, 1),
                    model: text(statement, 2),
                    cliVersion: text(statement, 3),
                    tokensUsed: optionalInt(statement, 4),
                    gitBranch: text(statement, 5),
                    createdAtMs: optionalInt64(statement, 6),
                    updatedAtMs: optionalInt64(statement, 7),
                    isArchived: isArchived,
                    candidateCount: 0
                ))
        }
        guard !rows.isEmpty else {
            return CodexThreadSelection(thread: nil, candidateCount: 0)
        }

        let processStartMs = Int64(processStartTime.timeIntervalSince1970 * 1000)
        let hasActiveRows = rows.contains { $0.isArchived == false }
        let candidates = hasActiveRows ? rows.filter { $0.isArchived == false } : rows
        let ranked = candidates.map {
            row -> CodexThreadRank in
            let timestamp = row.createdAtMs ?? row.updatedAtMs
            let distance = timestamp.map { abs($0 - processStartMs) } ?? Int64.max
            let beforeStart = timestamp.map { $0 < processStartMs } ?? true
            return CodexThreadRank(
                row: row,
                distance: distance,
                beforeStart: beforeStart,
                updated: row.updatedAtMs ?? row.createdAtMs ?? 0)
        }.sorted { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            if lhs.beforeStart != rhs.beforeStart { return rhs.beforeStart }
            return lhs.updated > rhs.updated
        }

        guard let best = ranked.first else {
            return CodexThreadSelection(thread: nil, candidateCount: rows.count)
        }
        if ranked.count > 1 {
            let next = ranked[1]
            if best.distance == next.distance, best.beforeStart == next.beforeStart, best.updated == next.updated {
                throw CodexStateStoreError.ambiguousSession
            }
        }
        let selected = CodexThreadState(
            id: best.row.id,
            rolloutPath: best.row.rolloutPath,
            model: best.row.model,
            cliVersion: best.row.cliVersion,
            tokensUsed: best.row.tokensUsed,
            gitBranch: best.row.gitBranch,
            createdAtMs: best.row.createdAtMs,
            updatedAtMs: best.row.updatedAtMs,
            isArchived: best.row.isArchived,
            candidateCount: rows.count
        )
        return CodexThreadSelection(thread: selected, candidateCount: rows.count)
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

    private func optionalInt64(_ statement: OpaquePointer, _ index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(statement, index)
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
            let payload = object["payload"] as? [String: Any]
            let cwd = payload?["cwd"] as? String ?? object["cwd"] as? String ?? object["workspace"] as? String
            guard cwd == nil || cwd == expectedCWD else { return nil }
            let model = payload?["model"] as? String ?? object["model"] as? String
            return StatusLineData(
                model: model.map { StatusLineData.Model(id: $0, displayName: $0) },
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
                version: payload?["cli_version"] as? String ?? object["cli_version"] as? String,
                exceeds200kTokens: nil,
                pr: nil,
                sessionStatus: nil
            )
        }

        guard type == "event_msg",
            let payload = object["payload"] as? [String: Any],
            payload["type"] as? String == "token_count"
        else { return nil }

        let info = payload["info"] as? [String: Any]
        let usage = info?["total_token_usage"] as? [String: Any] ?? payload["total_token_usage"] as? [String: Any]
        let input = int(usage?["input_tokens"]) ?? int(usage?["total_input_tokens"])
        let output = int(usage?["output_tokens"]) ?? int(usage?["total_output_tokens"])
        let contextWindow =
            int(info?["model_context_window"]) ?? int(payload["model_context_window"])
            ?? int(usage?["model_context_window"])
        let used = (input ?? 0) + (output ?? 0)
        let usedPct = contextWindow.flatMap { $0 > 0 ? Int((Double(used) / Double($0)) * 100) : nil }
        let remainingPct = usedPct.map { max(0, 100 - $0) }
        let model = payload["model"] as? String ?? info?["model"] as? String

        return StatusLineData(
            model: model.map { StatusLineData.Model(id: $0, displayName: $0) },
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
            usedPercentage: double(raw["used_percentage"]) ?? double(raw["used_percent"]),
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
    var onTrace: ((String, [String: String]) -> Void)?
    private var source: DispatchSourceFileSystemObject?
    private var offset: UInt64 = 0

    init(rolloutPath: String, expectedCWD: String) {
        self.rolloutPath = rolloutPath
        self.expectedCWD = expectedCWD
    }

    func start() {
        onTrace?("statusline.codex.tailer_started", [:])
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
            var lineCount = 0
            var updateCount = 0
            for line in data.split(separator: UInt8(ascii: "\n")).prefix(200) {
                lineCount += 1
                guard line.count <= 64 * 1024 else { continue }
                if let update = CodexRolloutParser.parseLine(Data(line), expectedCWD: expectedCWD) {
                    updateCount += 1
                    onUpdate?(update)
                }
            }
            onTrace?(
                "statusline.codex.tailer_read",
                ["line_count": "\(lineCount)", "update_count": "\(updateCount)"])
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
        trace("statusline.provider.started")
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
        trace("statusline.provider.stopped")
    }

    private func loadCodexState() async {
        do {
            let selection = try stateStore.selectThread(
                cwd: context.workingDirectory,
                processStartTime: context.processStartTime
            )
            trace(
                "statusline.codex.state_read",
                attributes: ["candidate_count": "\(selection.candidateCount)"])
            guard let thread = selection.thread else {
                trace(
                    "statusline.codex.selection_failed",
                    attributes: ["reason": "no_match", "candidate_count": "\(selection.candidateCount)"])
                return
            }
            trace(
                "statusline.codex.thread_selected",
                attributes: [
                    "thread_id_prefix": String(thread.id.prefix(12)),
                    "created_at_ms": thread.createdAtMs.map(String.init) ?? "",
                    "updated_at_ms": thread.updatedAtMs.map(String.init) ?? "",
                    "cli_version": thread.cliVersion ?? context.detectedHarnessVersion ?? "",
                    "candidate_count": "\(thread.candidateCount)",
                ])
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
                trace("statusline.codex.schema_unsupported")
                return
            }
            guard let rolloutPath = thread.rolloutPath, FileManager.default.fileExists(atPath: rolloutPath) else {
                trace("statusline.codex.rollout_unavailable")
                return
            }
            await MainActor.run {
                self.startTailer(path: rolloutPath)
            }
        } catch CodexStateStoreError.ambiguousSession {
            trace("statusline.provider.update_failed")
            trace("statusline.codex.selection_failed", attributes: ["reason": "ambiguous_after_scoring"])
            trace("statusline.codex.session_ambiguous")
        } catch CodexStateStoreError.schemaUnavailable {
            trace("statusline.provider.update_failed")
            trace("statusline.codex.selection_failed", attributes: ["reason": "schema_unavailable"])
            trace("statusline.codex.state_unavailable")
        } catch CodexStateStoreError.openFailed {
            trace("statusline.provider.update_failed")
            trace("statusline.codex.selection_failed", attributes: ["reason": "open_failed"])
            trace("statusline.codex.state_unavailable")
        } catch CodexStateStoreError.queryFailed {
            trace("statusline.provider.update_failed")
            trace("statusline.codex.selection_failed", attributes: ["reason": "query_failed"])
            trace("statusline.codex.state_unavailable")
        } catch {
            trace("statusline.provider.update_failed")
            trace("statusline.codex.selection_failed", attributes: ["reason": "unknown"])
            trace("statusline.codex.state_unavailable")
        }
    }

    private func startTailer(path: String) {
        tailer?.stop()
        let next = CodexRolloutTailer(rolloutPath: path, expectedCWD: context.workingDirectory)
        next.onTrace = { [weak self] name, attributes in
            self?.trace(name, attributes: attributes)
        }
        next.onUpdate = { [weak self] data in
            guard let self else { return }
            self.trace(
                "statusline.codex.parsed_update",
                attributes: [
                    "has_model": data.model == nil ? "false" : "true",
                    "has_tokens": data.contextWindow?.totalInputTokens == nil
                        && data.contextWindow?.totalOutputTokens == nil ? "false" : "true",
                    "has_context": data.contextWindow?.usedPercentage == nil ? "false" : "true",
                    "has_rate_limits": data.rateLimits == nil ? "false" : "true",
                ])
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
        trace("statusline.provider.update_applied")
        onUpdate?(data)
    }

    private func trace(_ name: String, attributes extraAttributes: [String: String] = [:]) {
        var attributes = [
            "provider": "codex",
            "pane.name": context.paneName,
            "pane.id": context.paneID.uuidString,
            "tab.id": context.tabID.uuidString,
            "tab.name": context.tabName,
        ]
        for (key, value) in extraAttributes {
            attributes[key] = value
        }
        TracingService.shared.record(name, attributes: attributes)
    }
}
