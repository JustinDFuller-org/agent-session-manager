import Foundation
import MCP
import OSLog

struct AgentControlDiagnosticQuery: Codable, Sendable {
    var sinceEpochMs: Int64?
    var untilEpochMs: Int64?
    var limit: Int?

    init(sinceEpochMs: Int64? = nil, untilEpochMs: Int64? = nil, limit: Int? = nil) {
        self.sinceEpochMs = sinceEpochMs
        self.untilEpochMs = untilEpochMs
        self.limit = limit
    }

    func resolved(
        now: Date = Date(), defaultLimit: Int = 100, maximumLimit: Int = 200
    ) throws -> AgentControlResolvedDiagnosticQuery {
        let until = untilEpochMs ?? Int64(now.timeIntervalSince1970 * 1000)
        let since = sinceEpochMs ?? until - 3_600_000
        guard since <= until else {
            throw MCPError.invalidParams("Diagnostic query start must not be later than its end")
        }
        let resolvedLimit = min(max(limit ?? defaultLimit, 1), maximumLimit)
        return AgentControlResolvedDiagnosticQuery(
            sinceEpochMs: since, untilEpochMs: until, limit: resolvedLimit)
    }
}

struct AgentControlDiagnosticResourceQuery: Sendable {
    let sinceEpochMs: Int64?
    let untilEpochMs: Int64?
    let limit: Int?

    init(queryItems: [URLQueryItem]) throws {
        var sinceEpochMs: Int64?
        var untilEpochMs: Int64?
        var limit: Int?

        for item in queryItems {
            guard let value = item.value, !value.isEmpty else {
                throw MCPError.invalidParams("Diagnostic resource query value is missing")
            }
            switch item.name {
            case "sinceEpochMs":
                guard sinceEpochMs == nil, let parsed = Int64(value) else {
                    throw MCPError.invalidParams("Diagnostic resource sinceEpochMs is invalid or duplicated")
                }
                sinceEpochMs = parsed
            case "untilEpochMs":
                guard untilEpochMs == nil, let parsed = Int64(value) else {
                    throw MCPError.invalidParams("Diagnostic resource untilEpochMs is invalid or duplicated")
                }
                untilEpochMs = parsed
            case "limit":
                guard limit == nil, let parsed = Int(value) else {
                    throw MCPError.invalidParams("Diagnostic resource limit is invalid or duplicated")
                }
                limit = parsed
            default:
                throw MCPError.invalidParams("Unknown diagnostic resource query parameter: \(item.name)")
            }
        }

        self.sinceEpochMs = sinceEpochMs
        self.untilEpochMs = untilEpochMs
        self.limit = limit
    }
}

struct AgentControlTraceQueryArguments: Codable, Sendable {
    var sinceEpochMs: Int64?
    var untilEpochMs: Int64?
    var limit: Int?
    var tabID: String?
    var paneID: String?
    var eventNames: [String]?
}

struct AgentControlInvariantQueryArguments: Codable, Sendable {
    var sinceEpochMs: Int64?
    var untilEpochMs: Int64?
    var limit: Int?
    var tabID: String?
    var paneID: String?
    var invariantIDs: [String]?
    var integrations: [String]?
    var severities: [String]?
}

struct AgentControlLogQueryArguments: Codable, Sendable {
    var sinceEpochMs: Int64?
    var untilEpochMs: Int64?
    var limit: Int?
    var categories: [String]?
    var levels: [String]?
    var eventNames: [String]?
}

struct AgentControlDebugModeArguments: Codable, Sendable {
    let enabled: Bool
}

struct AgentControlResolvedDiagnosticQuery: Codable, Sendable {
    let sinceEpochMs: Int64
    let untilEpochMs: Int64
    let limit: Int
}

struct AgentControlDiagnosticAvailability: Codable, Sendable {
    let debugModeEnabled: Bool
    let tracesReadable: Bool
    let invariantsReadable: Bool
    let tracesCapturing: Bool
    let invariantsCapturing: Bool
    let unifiedLogsAlwaysOn: Bool
    let unscopedRecordsRequireGlobalScope: Bool
}

struct AgentControlDiagnosticFileInfo: Codable, Sendable {
    let logicalPath: String
    let exists: Bool
    let byteCount: Int64
}

struct AgentControlDiagnosticQueryMetadata: Codable, Sendable {
    let query: AgentControlResolvedDiagnosticQuery
    let returnedCount: Int
    let limitTruncated: Bool
    let sourceTruncated: Bool
    let malformedLines: Int
    let legacyFiles: [AgentControlDiagnosticFileInfo]
}

struct AgentControlTraceDiagnosticRecord: Codable, Sendable {
    let file: AgentControlTraceFileMetadata
    let name: String
    let traceID: String
    let spanID: String
    let parentSpanID: String?
    let startEpochMs: Int64
    let endEpochMs: Int64
    let durationMs: Int64
    let attributes: [String: String]
}

struct AgentControlTraceFileMetadata: Codable, Sendable, Equatable {
    let paneID: String
    let paneName: String
    let tabID: String
    let tabName: String
    let createdAt: String
}

struct AgentControlTraceQueryResult: Codable, Sendable {
    let availability: AgentControlDiagnosticAvailability
    let metadata: AgentControlDiagnosticQueryMetadata
    let files: [AgentControlTraceFileMetadata]
    let records: [AgentControlTraceDiagnosticRecord]
}

struct AgentControlInvariantDiagnosticRecord: Codable, Sendable {
    let id: UUID
    let invariantID: String
    let integration: String
    let severity: Invariant.Severity
    let description: String
    let timestamp: Date
    let context: [String: String]
}

struct AgentControlInvariantQueryResult: Codable, Sendable {
    let availability: AgentControlDiagnosticAvailability
    let metadata: AgentControlDiagnosticQueryMetadata
    let records: [AgentControlInvariantDiagnosticRecord]
}

struct AgentControlUnifiedLogDiagnosticRecord: Codable, Sendable {
    let timestamp: Date
    let subsystem: String
    let category: String
    let level: String
    let eventName: String?
}

struct AgentControlLogQueryResult: Codable, Sendable {
    let availability: AgentControlDiagnosticAvailability
    let metadata: AgentControlDiagnosticQueryMetadata
    let records: [AgentControlUnifiedLogDiagnosticRecord]
}

struct AgentControlDiagnosticSummary: Codable, Sendable {
    let appMode: String
    let bundleIdentifier: String
    let shortVersion: String
    let buildVersion: String
    let currentScope: AgentControlScope
    let globalOnlyResources: [String]
    let globalOnlyTools: [String]
    let availability: AgentControlDiagnosticAvailability
    let workspace: AgentControlWorkspaceSnapshot
    let legacyFiles: [AgentControlDiagnosticFileInfo]
}

struct AgentControlDebugModeResult: Codable, Sendable {
    let enabled: Bool
    let persisted: Bool
    let tracesCapturing: Bool
    let invariantsCapturing: Bool
}

private struct DiagnosticFileReadResult<Record> {
    var records: [Record] = []
    var files: [AgentControlTraceFileMetadata] = []
    var limitTruncated = false
    var sourceTruncated = false
    var malformedLines = 0
}

enum AgentControlDiagnosticRedactor {
    private static let blockedKeyFragments = [
        "token", "secret", "password", "authorization", "environment", "env", "command", "args",
        "path", "directory", "cwd", "working", "executable", "terminal", "output", "content",
        "prompt", "transcript", "payload", "error", "url", "value",
    ]

    static func redact(_ attributes: [String: String]) -> [String: String] {
        attributes.reduce(into: [:]) { result, item in
            let key = item.key.lowercased()
            guard !blockedKeyFragments.contains(where: key.contains), item.value.count <= 256 else { return }
            result[item.key] = item.value
        }
    }
}

@MainActor
final class AgentControlDiagnosticsRouter {
    private static let globalOnlyResources = ["agent-session-manager://harnesses"]
    private static let globalOnlyTools = [
        "tabs_create", "tabs_delete", "tabs_reorder", "profiles_create", "profiles_update",
        "profiles_delete", "profiles_reorder", "status_lines_update_global", "status_lines_update_profile",
        "status_lines_clear_profile_override", "harnesses_set_enabled", "harnesses_configure_cli_option",
        "diagnostics_query_logs", "debug_set_mode",
    ]

    private let appState: AppState
    private let appSettings: AppSettings

    init(appState: AppState, appSettings: AppSettings) {
        self.appState = appState
        self.appSettings = appSettings
    }

    func resources() -> [Resource] {
        [
            Resource(
                name: "Agent Session Manager diagnostic summary",
                uri: AgentControlResourceURI.diagnosticSummary.rawValue,
                description: "Scoped app, build, capture, and session diagnostics.",
                mimeType: "application/json"),
            Resource(
                name: "Agent Session Manager traces",
                uri: AgentControlResourceURI.diagnosticTraces.rawValue,
                description:
                    "Recent scoped trace records with metadata, truncation state, and time-window query parameters.",
                mimeType: "application/json"),
            Resource(
                name: "Agent Session Manager invariants",
                uri: AgentControlResourceURI.diagnosticInvariants.rawValue,
                description: "Recent scoped invariant occurrences.",
                mimeType: "application/json"),
            Resource(
                name: "Agent Session Manager unified logs",
                uri: AgentControlResourceURI.diagnosticLogs.rawValue,
                description: "Recent bounded unified-log event metadata. Global scope required.",
                mimeType: "application/json"),
        ]
    }

    func tools() -> [Tool] {
        [
            Tool(
                name: "diagnostics_query_traces",
                description: "Query scoped trace records by time, IDs, and event names.",
                inputSchema: Self.querySchema(properties: [
                    "tabID": .string("Optional tab UUID"),
                    "paneID": .string("Optional pane UUID"),
                    "eventNames": .array("Exact event names to match", items: .string("Exact event name")),
                ])),
            Tool(
                name: "diagnostics_query_invariants",
                description: "Query scoped invariant occurrences with bounded context.",
                inputSchema: Self.querySchema(properties: [
                    "tabID": .string("Optional tab UUID"),
                    "paneID": .string("Optional pane UUID"),
                    "invariantIDs": .array("Invariant IDs to match", items: .string("Invariant ID")),
                    "integrations": .array("Integration names to match", items: .string("Integration name")),
                    "severities": .array(
                        "Severities to match", items: .string("Severity", enumValues: ["warning", "error"])),
                ])),
            Tool(
                name: "diagnostics_query_logs",
                description: "Query Global-scope unified-log event metadata.",
                inputSchema: Self.querySchema(properties: [
                    "categories": .array("Logger categories to match", items: .string("Logger category")),
                    "levels": .array("Log levels to match", items: .string("Log level")),
                    "eventNames": .array("Exact event names to match", items: .string("Exact event name")),
                ])),
            Tool(
                name: "debug_set_mode",
                description: "Enable or disable durable trace and invariant capture. Global scope required.",
                inputSchema: AgentControlToolSchema.inputSchema(
                    ["enabled": .boolean("Whether durable trace and invariant capture is enabled")],
                    required: ["enabled"])),
        ]
    }

    func read(
        uri: AgentControlResourceURI,
        source: AgentControlSource,
        resourceQuery: AgentControlDiagnosticResourceQuery? = nil
    ) async throws -> String {
        do {
            let data: Data
            switch uri {
            case .diagnosticSummary:
                data = try JSONEncoder().encode(summary(source: source))
            case .diagnosticTraces:
                data = try JSONEncoder().encode(
                    try await traceResult(source: source, arguments: nil, resourceQuery: resourceQuery))
            case .diagnosticInvariants:
                data = try JSONEncoder().encode(
                    try await invariantResult(source: source, arguments: nil, resourceQuery: resourceQuery))
            case .diagnosticLogs:
                data = try JSONEncoder().encode(
                    try await logResult(source: source, arguments: nil, resourceQuery: resourceQuery))
            default:
                throw MCPError.invalidParams("Not an Agent Session Manager diagnostic resource")
            }
            guard let value = String(data: data, encoding: .utf8) else {
                throw MCPError.internalError("Unable to encode diagnostic resource")
            }
            return value
        } catch is CancellationError {
            recordDiagnosticCancellation(name: "resource.read", source: source)
            throw CancellationError()
        }
    }

    func callTool(
        name: String, arguments: [String: Value]?, source: AgentControlSource
    ) async throws -> CallTool.Result {
        do {
            switch name {
            case "diagnostics_query_traces":
                let decoded = try decode(AgentControlTraceQueryArguments.self, arguments: arguments)
                return try result(try await traceResult(source: source, arguments: decoded))
            case "diagnostics_query_invariants":
                let decoded = try decode(AgentControlInvariantQueryArguments.self, arguments: arguments)
                return try result(try await invariantResult(source: source, arguments: decoded))
            case "diagnostics_query_logs":
                guard source.scope == .global else {
                    recordAuthorizationDenied(name: name, source: source)
                    throw MCPError.invalidRequest(scopeError(required: .global, current: source.scope))
                }
                let decoded = try decode(AgentControlLogQueryArguments.self, arguments: arguments)
                return try result(try await logResult(source: source, arguments: decoded))
            case "debug_set_mode":
                guard source.scope == .global else {
                    recordAuthorizationDenied(name: name, source: source)
                    throw MCPError.invalidRequest(scopeError(required: .global, current: source.scope))
                }
                let decoded = try decode(AgentControlDebugModeArguments.self, arguments: arguments)
                return try result(setDebugMode(decoded.enabled, source: source))
            default:
                throw MCPError.invalidParams("Unknown Agent Session Manager diagnostic tool")
            }
        } catch is CancellationError {
            recordDiagnosticCancellation(name: name, source: source)
            throw CancellationError()
        }
    }

    func summary(source: AgentControlSource) -> AgentControlDiagnosticSummary {
        let bundle = Bundle.main
        return AgentControlDiagnosticSummary(
            appMode: PersistenceHelpers.appSupportSubdirectory,
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            shortVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildVersion: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            currentScope: source.scope,
            globalOnlyResources: Self.globalOnlyResources,
            globalOnlyTools: Self.globalOnlyTools,
            availability: availability(),
            workspace: AgentControlResourceRouter(appState: appState, appSettings: appSettings)
                .workspaceSnapshot(source: source),
            legacyFiles: legacyFiles())
    }

    private func traceResult(
        source: AgentControlSource,
        arguments: AgentControlTraceQueryArguments?,
        resourceQuery: AgentControlDiagnosticResourceQuery? = nil
    ) async throws -> AgentControlTraceQueryResult {
        let query = try AgentControlDiagnosticQuery(
            sinceEpochMs: arguments?.sinceEpochMs ?? resourceQuery?.sinceEpochMs,
            untilEpochMs: arguments?.untilEpochMs ?? resourceQuery?.untilEpochMs,
            limit: arguments?.limit ?? resourceQuery?.limit
        ).resolved(
            defaultLimit: resourceQuery == nil ? 100 : 20,
            maximumLimit: resourceQuery == nil ? 200 : 50)
        try validateSelectors(tabID: arguments?.tabID, paneID: arguments?.paneID, source: source)
        let eventNames = Set(arguments?.eventNames ?? [])
        let result = try await readTraces(
            query: query, source: source, tabID: arguments?.tabID, paneID: arguments?.paneID,
            eventNames: eventNames)
        let records = result.records
        let limited = Array(records.suffix(query.limit))
        let metadata = AgentControlDiagnosticQueryMetadata(
            query: query,
            returnedCount: limited.count,
            limitTruncated: result.limitTruncated || records.count > limited.count,
            sourceTruncated: result.sourceTruncated,
            malformedLines: result.malformedLines,
            legacyFiles: legacyFiles())
        recordQuery(name: "traces", source: source, metadata: metadata)
        return AgentControlTraceQueryResult(
            availability: availability(), metadata: metadata, files: result.files, records: limited)
    }

    private func invariantResult(
        source: AgentControlSource,
        arguments: AgentControlInvariantQueryArguments?,
        resourceQuery: AgentControlDiagnosticResourceQuery? = nil
    ) async throws -> AgentControlInvariantQueryResult {
        let query = try AgentControlDiagnosticQuery(
            sinceEpochMs: arguments?.sinceEpochMs ?? resourceQuery?.sinceEpochMs,
            untilEpochMs: arguments?.untilEpochMs ?? resourceQuery?.untilEpochMs,
            limit: arguments?.limit ?? resourceQuery?.limit
        ).resolved(
            defaultLimit: resourceQuery == nil ? 100 : 20,
            maximumLimit: resourceQuery == nil ? 200 : 50)
        try validateSelectors(tabID: arguments?.tabID, paneID: arguments?.paneID, source: source)
        let result = try await readInvariants(
            query: query, source: source, tabID: arguments?.tabID, paneID: arguments?.paneID,
            invariantIDs: Set(arguments?.invariantIDs ?? []), integrations: Set(arguments?.integrations ?? []),
            severities: Set(arguments?.severities ?? []))
        let limited = Array(result.records.suffix(query.limit))
        let metadata = AgentControlDiagnosticQueryMetadata(
            query: query,
            returnedCount: limited.count,
            limitTruncated: result.limitTruncated || result.records.count > limited.count,
            sourceTruncated: result.sourceTruncated,
            malformedLines: result.malformedLines,
            legacyFiles: legacyFiles())
        recordQuery(name: "invariants", source: source, metadata: metadata)
        return AgentControlInvariantQueryResult(availability: availability(), metadata: metadata, records: limited)
    }

    private func logResult(
        source: AgentControlSource,
        arguments: AgentControlLogQueryArguments?,
        resourceQuery: AgentControlDiagnosticResourceQuery? = nil
    ) async throws -> AgentControlLogQueryResult {
        guard source.scope == .global else {
            recordAuthorizationDenied(name: "diagnostics.logs", source: source)
            throw MCPError.invalidRequest(scopeError(required: .global, current: source.scope))
        }
        let query = try AgentControlDiagnosticQuery(
            sinceEpochMs: arguments?.sinceEpochMs ?? resourceQuery?.sinceEpochMs,
            untilEpochMs: arguments?.untilEpochMs ?? resourceQuery?.untilEpochMs,
            limit: arguments?.limit ?? resourceQuery?.limit
        ).resolved(
            defaultLimit: resourceQuery == nil ? 100 : 20,
            maximumLimit: resourceQuery == nil ? 200 : 50)
        let categoryFilter = Set(arguments?.categories ?? [])
        let levelFilter = Set(arguments?.levels ?? [])
        let eventFilter = Set(arguments?.eventNames ?? [])
        let result = try await readLogs(
            query: query, categoryFilter: categoryFilter, levelFilter: levelFilter, eventFilter: eventFilter)
        let limited = Array(result.records.suffix(query.limit))
        let metadata = AgentControlDiagnosticQueryMetadata(
            query: query,
            returnedCount: limited.count,
            limitTruncated: result.limitTruncated || result.records.count > limited.count,
            sourceTruncated: false,
            malformedLines: result.malformedLines,
            legacyFiles: legacyFiles())
        recordQuery(name: "logs", source: source, metadata: metadata)
        return AgentControlLogQueryResult(availability: availability(), metadata: metadata, records: limited)
    }

    private func setDebugMode(_ enabled: Bool, source: AgentControlSource) throws -> AgentControlDebugModeResult {
        guard SettingsPersistence.saveDebugSettings(enabled: enabled) else {
            var attributes = sourceAttributes(source)
            attributes["enabled"] = String(enabled)
            attributes["result"] = "persist_failed"
            TracingService.shared.record("agent_control.debug_mode.changed", attributes: attributes)
            throw MCPError.internalError("Unable to persist Debug Mode")
        }
        appSettings.debugModeEnabled = enabled
        TracingService.shared.configure(from: appSettings)
        InvariantReporter.shared.configure(from: appSettings)
        let attributes = sourceAttributes(source).merging(
            ["enabled": String(enabled), "result": "updated"], uniquingKeysWith: { _, new in new })
        TracingService.shared.record("agent_control.debug_mode.changed", attributes: attributes)
        return AgentControlDebugModeResult(
            enabled: enabled,
            persisted: true,
            tracesCapturing: TracingService.shared.isEnabled,
            invariantsCapturing: enabled)
    }

    private func readTraces(
        query: AgentControlResolvedDiagnosticQuery,
        source: AgentControlSource,
        tabID: String?,
        paneID: String?,
        eventNames: Set<String>
    ) async throws -> DiagnosticFileReadResult<AgentControlTraceDiagnosticRecord> {
        var result = DiagnosticFileReadResult<AgentControlTraceDiagnosticRecord>()
        let directory = appSettings.resolvedTracingDirectoryURL
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return result
        }
        var lineNumber = 0
        while let url = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            await Task.yield()
            guard url.pathExtension == "jsonl" else { continue }
            guard let content = try? boundedUTF8Contents(at: url) else { continue }
            let lines = content.split(whereSeparator: \.isNewline).map(String.init)
            guard let first = lines.first, let metadata = traceMetadata(first) else {
                result.malformedLines += lines.isEmpty ? 0 : 1
                continue
            }
            guard traceFileAllowed(metadata, source: source, tabID: tabID, paneID: paneID) else { continue }
            result.files.append(metadata)
            for line in lines.dropFirst() {
                lineNumber += 1
                if lineNumber.isMultiple(of: 64) {
                    try Task.checkCancellation()
                    await Task.yield()
                }
                if line == "--- [truncated older trace entries] ---" {
                    result.sourceTruncated = true
                    continue
                }
                guard let object = jsonObject(line), let name = object["name"] as? String,
                    let traceID = object["traceId"] as? String, let spanID = object["spanId"] as? String,
                    let start = integer(object["startEpochMs"]), let end = integer(object["endEpochMs"])
                else {
                    result.malformedLines += 1
                    continue
                }
                guard start >= query.sinceEpochMs && start <= query.untilEpochMs else { continue }
                guard eventNames.isEmpty || eventNames.contains(name) else { continue }
                let attributes = AgentControlDiagnosticRedactor.redact(object["attributes"] as? [String: String] ?? [:])
                result.records.append(
                    AgentControlTraceDiagnosticRecord(
                        file: metadata,
                        name: name,
                        traceID: traceID,
                        spanID: spanID,
                        parentSpanID: object["parentSpanId"] as? String,
                        startEpochMs: start,
                        endEpochMs: end,
                        durationMs: integer(object["durationMs"]) ?? end - start,
                        attributes: attributes))
                if result.records.count > query.limit {
                    result.records.removeFirst()
                    result.limitTruncated = true
                }
            }
        }
        result.records.sort { $0.startEpochMs < $1.startEpochMs }
        return result
    }

    private func readInvariants(
        query: AgentControlResolvedDiagnosticQuery,
        source: AgentControlSource,
        tabID: String?,
        paneID: String?,
        invariantIDs: Set<String>,
        integrations: Set<String>,
        severities: Set<String>
    ) async throws -> DiagnosticFileReadResult<AgentControlInvariantDiagnosticRecord> {
        var result = DiagnosticFileReadResult<AgentControlInvariantDiagnosticRecord>()
        let url = appSettings.resolvedInvariantDirectoryURL.appending(path: "invariants.jsonl")
        guard let content = try? boundedUTF8Contents(at: url) else { return result }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for (index, line) in content.split(whereSeparator: \.isNewline).map(String.init).enumerated() {
            if index.isMultiple(of: 64) {
                try Task.checkCancellation()
                await Task.yield()
            }
            if line == InvariantLogWriter.truncationMarker {
                result.sourceTruncated = true
                continue
            }
            guard let data = line.data(using: .utf8),
                let violation = try? decoder.decode(InvariantViolation.self, from: data)
            else {
                if !(line.contains("\"_type\":\"metadata\"") || line.isEmpty) { result.malformedLines += 1 }
                continue
            }
            guard violation.timestamp.timeIntervalSince1970 * 1000 >= Double(query.sinceEpochMs),
                violation.timestamp.timeIntervalSince1970 * 1000 <= Double(query.untilEpochMs),
                invariantIDs.isEmpty || invariantIDs.contains(violation.invariantID),
                integrations.isEmpty || integrations.contains(violation.integration),
                severities.isEmpty || severities.contains(violation.severity.rawValue),
                invariantAllowed(violation, source: source, tabID: tabID, paneID: paneID)
            else { continue }
            result.records.append(
                AgentControlInvariantDiagnosticRecord(
                    id: violation.id,
                    invariantID: violation.invariantID,
                    integration: violation.integration,
                    severity: violation.severity,
                    description: violation.description,
                    timestamp: violation.timestamp,
                    context: AgentControlDiagnosticRedactor.redact(violation.context)))
            if result.records.count > query.limit {
                result.records.removeFirst()
                result.limitTruncated = true
            }
        }
        result.records.sort { $0.timestamp < $1.timestamp }
        return result
    }

    private func readLogs(
        query: AgentControlResolvedDiagnosticQuery,
        categoryFilter: Set<String>,
        levelFilter: Set<String>,
        eventFilter: Set<String>
    ) async throws -> DiagnosticFileReadResult<AgentControlUnifiedLogDiagnosticRecord> {
        var result = DiagnosticFileReadResult<AgentControlUnifiedLogDiagnosticRecord>()
        guard let store = try? OSLogStore.local() else { return result }
        let start = Date(timeIntervalSince1970: Double(query.sinceEpochMs) / 1000)
        let subsystem = Bundle.main.bundleIdentifier ?? "com.justinfuller.agent-session-manager"
        let predicate = NSPredicate(
            format: "subsystem == %@ AND processIdentifier == %d", subsystem, getpid())
        guard let entries = try? store.getEntries(with: [], at: store.position(date: start), matching: predicate)
        else { return result }
        for (index, entry) in entries.enumerated() {
            if index.isMultiple(of: 64) {
                try Task.checkCancellation()
                await Task.yield()
            }
            guard let log = entry as? OSLogEntryLog, log.date.timeIntervalSince1970 * 1000 <= Double(query.untilEpochMs)
            else { continue }
            let eventName = log.composedMessage.split(separator: " ").first.map(String.init)
            guard categoryFilter.isEmpty || categoryFilter.contains(log.category),
                levelFilter.isEmpty || levelFilter.contains(String(describing: log.level)),
                eventFilter.isEmpty || (eventName.map(eventFilter.contains) ?? false)
            else { continue }
            result.records.append(
                AgentControlUnifiedLogDiagnosticRecord(
                    timestamp: log.date,
                    subsystem: subsystem,
                    category: log.category,
                    level: String(describing: log.level),
                    eventName: eventName))
            if result.records.count > query.limit {
                result.records.removeFirst()
                result.limitTruncated = true
            }
        }
        result.records.sort { $0.timestamp < $1.timestamp }
        return result
    }

    private func validateSelectors(tabID: String?, paneID: String?, source: AgentControlSource) throws {
        if let tabID, UUID(uuidString: tabID) == nil {
            throw MCPError.invalidParams("Diagnostic tab selector is not a UUID")
        }
        if let paneID, UUID(uuidString: paneID) == nil {
            throw MCPError.invalidParams("Diagnostic pane selector is not a UUID")
        }
        if source.scope == .pane {
            guard tabID == nil || tabID?.caseInsensitiveCompare(source.tabID.uuidString) == .orderedSame,
                paneID == nil || paneID?.caseInsensitiveCompare(source.paneID.uuidString) == .orderedSame
            else { throw MCPError.invalidRequest("Diagnostic selector is outside pane scope") }
        } else if source.scope == .tab {
            guard tabID == nil || tabID?.caseInsensitiveCompare(source.tabID.uuidString) == .orderedSame else {
                throw MCPError.invalidRequest("Diagnostic selector is outside tab scope")
            }
            if let paneID,
                !appState.tabs.contains(where: {
                    $0.id == source.tabID
                        && $0.panes.contains { $0.id.uuidString.caseInsensitiveCompare(paneID) == .orderedSame }
                })
            {
                throw MCPError.invalidRequest("Diagnostic selector is outside tab scope")
            }
        }
    }

    private func traceFileAllowed(
        _ metadata: AgentControlTraceFileMetadata, source: AgentControlSource, tabID: String?, paneID: String?
    ) -> Bool {
        if metadata.paneID == "_global" { return source.scope == .global }
        if let tabID, metadata.tabID.caseInsensitiveCompare(tabID) != .orderedSame { return false }
        if let paneID, metadata.paneID.caseInsensitiveCompare(paneID) != .orderedSame { return false }
        switch source.scope {
        case .global: return true
        case .tab: return metadata.tabID.caseInsensitiveCompare(source.tabID.uuidString) == .orderedSame
        case .pane: return metadata.paneID.caseInsensitiveCompare(source.paneID.uuidString) == .orderedSame
        }
    }

    private func invariantAllowed(
        _ violation: InvariantViolation, source: AgentControlSource, tabID: String?, paneID: String?
    ) -> Bool {
        let contextPane = violation.context["pane.id"]
        let contextTab = violation.context["tab.id"]
        if let paneID, contextPane?.caseInsensitiveCompare(paneID) != .orderedSame { return false }
        if let tabID, contextTab?.caseInsensitiveCompare(tabID) != .orderedSame { return false }
        guard let contextPane else { return source.scope == .global }
        switch source.scope {
        case .global: return true
        case .pane: return contextPane.caseInsensitiveCompare(source.paneID.uuidString) == .orderedSame
        case .tab:
            return appState.tabs.contains {
                $0.id == source.tabID
                    && $0.panes.contains { $0.id.uuidString.caseInsensitiveCompare(contextPane) == .orderedSame }
            }
        }
    }

    private func availability() -> AgentControlDiagnosticAvailability {
        AgentControlDiagnosticAvailability(
            debugModeEnabled: appSettings.debugModeEnabled,
            tracesReadable: true,
            invariantsReadable: true,
            tracesCapturing: TracingService.shared.isEnabled,
            invariantsCapturing: appSettings.debugModeEnabled,
            unifiedLogsAlwaysOn: true,
            unscopedRecordsRequireGlobalScope: true)
    }

    private func scopeError(required: AgentControlScope, current: AgentControlScope) -> String {
        "\(required.displayName) scope is required; current scope is \(current.displayName)"
    }

    private func legacyFiles() -> [AgentControlDiagnosticFileInfo] {
        let support = appSettings.resolvedTracingDirectoryURL.deletingLastPathComponent()
        return ["debug-trace.log", "traces.jsonl"].map { name in
            let url = support.appending(path: name)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return AgentControlDiagnosticFileInfo(
                logicalPath: name, exists: FileManager.default.fileExists(atPath: url.path), byteCount: size)
        }
    }

    private func traceMetadata(_ line: String) -> AgentControlTraceFileMetadata? {
        guard let object = jsonObject(line), object["_type"] as? String == "metadata",
            let paneID = object["paneId"] as? String, let paneName = object["paneName"] as? String,
            let tabID = object["tabId"] as? String, let tabName = object["tabName"] as? String,
            let createdAt = object["createdAt"] as? String
        else { return nil }
        return AgentControlTraceFileMetadata(
            paneID: paneID, paneName: paneName, tabID: tabID, tabName: tabName, createdAt: createdAt)
    }

    private func jsonObject(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func integer(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }

    private func sourceAttributes(_ source: AgentControlSource) -> [String: String] {
        [
            "pane.id": source.paneID.uuidString,
            "pane.name": source.paneName,
            "tab.id": source.tabID.uuidString,
            "tab.name": source.tabName,
            "scope": source.scope.rawValue,
        ]
    }

    private func recordQuery(name: String, source: AgentControlSource, metadata: AgentControlDiagnosticQueryMetadata) {
        var attributes = sourceAttributes(source)
        attributes["query.kind"] = name
        attributes["result.count"] = String(metadata.returnedCount)
        attributes["result.truncated"] = String(metadata.limitTruncated || metadata.sourceTruncated)
        attributes["result"] = "success"
        TracingService.shared.record("agent_control.diagnostic.query", attributes: attributes)
    }

    private func recordDiagnosticCancellation(name: String, source: AgentControlSource) {
        var attributes = sourceAttributes(source)
        attributes["query.kind"] = name
        attributes["result"] = "cancelled"
        TracingService.shared.record("agent_control.diagnostic.query", attributes: attributes)
    }

    private func recordAuthorizationDenied(name: String, source: AgentControlSource) {
        var attributes = sourceAttributes(source)
        attributes["tool"] = name
        attributes["result"] = "scope_denied"
        TracingService.shared.record("agent_control.tool.authorization_denied", attributes: attributes)
    }

    private func decode<T: Decodable>(_ type: T.Type, arguments: [String: Value]?) throws -> T {
        let data = try JSONEncoder().encode(arguments ?? [:])
        guard data.count <= 64 * 1024 else {
            throw MCPError.invalidParams("Diagnostic query arguments are too large")
        }
        return try JSONDecoder().decode(type, from: data)
    }

    private func boundedUTF8Contents(at url: URL) throws -> String {
        let maxBytes = 8 * 1024 * 1024
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard fileSize > maxBytes else {
            return String(decoding: try handle.readToEnd() ?? Data(), as: UTF8.self)
        }

        let prefixSize = 4096
        let suffixSize = maxBytes - prefixSize
        let prefix = try handle.read(upToCount: prefixSize) ?? Data()
        try handle.seek(toOffset: UInt64(fileSize - suffixSize))
        let suffix = try handle.read(upToCount: suffixSize) ?? Data()
        var bounded = Data()
        bounded.append(prefix)
        bounded.append(Data("\n".utf8))
        bounded.append(suffix)
        return String(decoding: bounded, as: UTF8.self)
    }

    private func result<T: Codable>(_ value: T) throws -> CallTool.Result {
        let data = try JSONEncoder().encode(value)
        let text = String(decoding: data, as: UTF8.self)
        return try CallTool.Result(
            content: [.text(text: text, annotations: nil, _meta: nil)],
            structuredContent: value)
    }

    private static func querySchema(properties: [String: AgentControlToolSchema]) -> Value {
        var fields: [String: AgentControlToolSchema] = [
            "sinceEpochMs": .integer("Start of the time window, in epoch milliseconds"),
            "untilEpochMs": .integer("End of the time window, in epoch milliseconds"),
            "limit": .integer("Maximum number of records to return", maximum: 200),
        ]
        fields.merge(properties, uniquingKeysWith: { _, new in new })
        return AgentControlToolSchema.inputSchema(fields)
    }
}
