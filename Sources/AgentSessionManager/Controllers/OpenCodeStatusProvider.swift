import Foundation

// MARK: - Version adapter

enum OpenCodeVersionAdapter {
    static func normalize(_ version: String?) -> String? {
        guard let version else { return nil }
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized =
            trimmed
            .replacingOccurrences(of: "opencode ", with: "")
            .replacingOccurrences(of: "opencode", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

}

// MARK: - Server models

struct OpenCodeSession: Sendable {
    let id: String
    let title: String?
    let directory: String?
    let parentID: String?
    let cost: Double?
    let tokens: OpenCodeSessionTokens?
    let model: OpenCodeSessionModel?
    let version: String?
    let time: OpenCodeSessionTime?
}

struct OpenCodeSessionModel: Sendable {
    let id: String?
    let providerID: String?
    let variant: String?
}

struct OpenCodeSessionTokens: Sendable {
    let input: Int?
    let output: Int?
    let reasoning: Int?
    let cacheRead: Int?
    let cacheWrite: Int?
}

struct OpenCodeSessionTime: Sendable {
    let created: Int64?
    let updated: Int64?
}

// MARK: - Server client protocol

protocol OpenCodeServerClient: Sendable {
    func health() async throws -> (healthy: Bool, version: String?)
    func listSessions() async throws -> [OpenCodeSession]
    func session(_ id: String) async throws -> OpenCodeSession
    func rename(_ id: String, title: String) async throws -> OpenCodeSession
}

enum OpenCodeServerClientError: Error {
    case missingPort
    case invalidURL
    case unexpectedStatus(Int)
    case decodingFailed(underlying: Error)
}

// MARK: - URLSession client

final class URLSessionOpenCodeClient: OpenCodeServerClient {
    private let port: Int?
    private let session: URLSession

    init(port: Int?, session: URLSession = .shared) {
        self.port = port
        self.session = session
    }

    func health() async throws -> (healthy: Bool, version: String?) {
        let data = try await get(path: "/global/health")
        let decoded = try JSONDecoder().decode(HealthResponse.self, from: data)
        return (decoded.healthy, decoded.version)
    }

    func listSessions() async throws -> [OpenCodeSession] {
        let data = try await get(path: "/session")
        let decoded = try JSONDecoder().decode([SessionResponse].self, from: data)
        return decoded.map { $0.toModel() }
    }

    func session(_ id: String) async throws -> OpenCodeSession {
        let data = try await get(path: "/session/\(id)")
        let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
        return decoded.toModel()
    }

    func rename(_ id: String, title: String) async throws -> OpenCodeSession {
        let body: [String: Any] = ["title": title]
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        let responseData = try await patch(path: "/session/\(id)", body: data)
        let decoded = try JSONDecoder().decode(SessionResponse.self, from: responseData)
        return decoded.toModel()
    }

    private func get(path: String) async throws -> Data {
        let request = try makeRequest(path: path, method: "GET", body: nil)
        return try await perform(request: request)
    }

    private func patch(path: String, body: Data) async throws -> Data {
        let request = try makeRequest(path: path, method: "PATCH", body: body)
        return try await perform(request: request)
    }

    private func makeRequest(path: String, method: String, body: Data?) throws -> URLRequest {
        guard let port else { throw OpenCodeServerClientError.missingPort }
        guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else {
            throw OpenCodeServerClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenCodeServerClientError.unexpectedStatus(0)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenCodeServerClientError.unexpectedStatus(httpResponse.statusCode)
        }
        return data
    }

    private struct HealthResponse: Decodable {
        let healthy: Bool
        let version: String?
    }

    private struct SessionResponse: Decodable {
        let id: String
        let title: String?
        let directory: String?
        let parentID: String?
        let cost: Double?
        let tokens: TokensResponse?
        let model: ModelResponse?
        let version: String?
        let time: TimeResponse?

        struct TokensResponse: Decodable {
            let input: Int?
            let output: Int?
            let reasoning: Int?
            let cache: CacheResponse?

            struct CacheResponse: Decodable {
                let read: Int?
                let write: Int?
            }
        }

        struct ModelResponse: Decodable {
            let id: String?
            let providerID: String?
            let variant: String?

            enum CodingKeys: String, CodingKey {
                case id
                case providerID = "providerID"
                case variant
            }
        }

        struct TimeResponse: Decodable {
            let created: Int64?
            let updated: Int64?
        }

        func toModel() -> OpenCodeSession {
            OpenCodeSession(
                id: id,
                title: title,
                directory: directory,
                parentID: parentID,
                cost: cost,
                tokens: tokens.map {
                    OpenCodeSessionTokens(
                        input: $0.input,
                        output: $0.output,
                        reasoning: $0.reasoning,
                        cacheRead: $0.cache?.read,
                        cacheWrite: $0.cache?.write
                    )
                },
                model: model.map {
                    OpenCodeSessionModel(
                        id: $0.id,
                        providerID: $0.providerID,
                        variant: $0.variant
                    )
                },
                version: version,
                time: time.map { OpenCodeSessionTime(created: $0.created, updated: $0.updated) }
            )
        }
    }
}

// MARK: - Status provider

final class OpenCodeStatusProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?
    var onAttention: ((PaneAttentionEvent) -> Void)?

    private let context: StatusProviderContext
    private let client: any OpenCodeServerClient
    private let startupRetryInterval: TimeInterval
    private let startupTimeout: TimeInterval
    private let pollInterval: TimeInterval
    private let timeWindowMs: Int64
    private let appDirectory: String
    private let baseline: ToolAgnosticDataProvider
    private var stateTask: Task<Void, Never>?
    private var pollTimer: DispatchSourceTimer?
    private var latestHarnessData: StatusLineData?
    private var latestBaselineData: StatusLineData?
    private var boundSessionID: String?
    private var detectedVersion: String?

    init(
        context: StatusProviderContext,
        client: (any OpenCodeServerClient)? = nil,
        startupRetryInterval: TimeInterval = 0.5,
        startupTimeout: TimeInterval = 15,
        pollInterval: TimeInterval = 15,
        timeWindowMs: Int64 = 60_000
    ) {
        self.context = context
        self.client = client ?? URLSessionOpenCodeClient(port: context.opencodePort)
        self.startupRetryInterval = startupRetryInterval
        self.startupTimeout = startupTimeout
        self.pollInterval = pollInterval
        self.timeWindowMs = timeWindowMs
        self.appDirectory = URL(filePath: context.workingDirectory).resolvingSymlinksInPath().path
        self.baseline = ToolAgnosticDataProvider(
            workingDirectory: context.workingDirectory,
            toolCommand: context.harness.commandDescription,
            processStartTime: context.processStartTime
        )
    }

    func start() {
        baseline.onUpdate = { [weak self] data in
            guard let self else { return }
            self.latestBaselineData = data
            self.emitMerged()
        }
        baseline.start()
        stateTask = Task { [weak self] in
            await self?.bindSession()
        }
    }

    func stop() {
        stateTask?.cancel()
        stateTask = nil
        pollTimer?.cancel()
        pollTimer = nil
        baseline.stop()
    }

    // MARK: - Binding

    private func bindSession() async {
        guard context.opencodePort != nil else {
            InvariantReporter.shared.violated(
                .opencodePortMissing,
                context: [
                    "pane.id": context.paneID.uuidString,
                    "pane.name": context.paneName,
                    "tab.id": context.tabID.uuidString,
                    "tab.name": context.tabName,
                ])
            trace("statusline.opencode.port_missing")
            return
        }

        let deadline = Date().addingTimeInterval(startupTimeout)
        var attempt = 0
        var didTraceServerWaiting = false

        while !Task.isCancelled {
            attempt += 1
            let lateBound = Date() > deadline

            do {
                let (healthy, version) = try await client.health()
                if healthy {
                    detectedVersion = OpenCodeVersionAdapter.normalize(version)
                    if !didTraceServerWaiting {
                        trace(
                            "statusline.opencode.server.bound",
                            attributes: [
                                "version": detectedVersion ?? "unknown",
                                "retry_attempt": "\(attempt)",
                                "late_bound": lateBound ? "true" : "false",
                            ])
                        didTraceServerWaiting = true
                    }

                    if let session = try await selectSession() {
                        boundSessionID = session.id
                        let sessionIDPrefix = String(session.id.prefix(12))
                        trace(
                            "statusline.opencode.session.bound",
                            attributes: [
                                "session_id_prefix": sessionIDPrefix,
                                "retry_attempt": "\(attempt)",
                                "late_bound": lateBound ? "true" : "false",
                            ])

                        await renameSessionIfNeeded(session)
                        await refreshSession()
                        startPollTimer()
                        return
                    }

                    if !lateBound {
                        trace(
                            "statusline.opencode.session.waiting",
                            attributes: [
                                "retry_attempt": "\(attempt)",
                                "reason": "no_session_for_directory",
                            ])
                    }
                }
            } catch {
                if !didTraceServerWaiting {
                    trace(
                        "statusline.opencode.server.waiting",
                        attributes: [
                            "retry_attempt": "\(attempt)",
                            "error": String(describing: error),
                        ])
                    didTraceServerWaiting = true
                }
            }

            if lateBound {
                trace(
                    "statusline.opencode.session.unbindable",
                    attributes: [
                        "retry_attempt": "\(attempt)",
                        "reason": "startup_timeout",
                        "app_directory": appDirectory,
                    ])
                return
            }

            _ = await sleepUntilNextRetry(deadline: deadline)
        }
    }

    private func selectSession() async throws -> OpenCodeSession? {
        let sessions = try await client.listSessions()
        let matching = sessions.filter { session in
            guard let directory = session.directory else { return false }
            return URL(filePath: directory).resolvingSymlinksInPath().path == appDirectory
        }

        guard !matching.isEmpty else { return nil }

        let processStartMs = Int64(context.processStartTime.timeIntervalSince1970 * 1000)

        if let withinWindow = matching.min(by: { lhs, rhs in
            let lhsDelta = abs((lhs.time?.created ?? 0) - processStartMs)
            let rhsDelta = abs((rhs.time?.created ?? 0) - processStartMs)
            if lhsDelta == rhsDelta {
                return (lhs.time?.created ?? 0) > (rhs.time?.created ?? 0)
            }
            return lhsDelta < rhsDelta
        }), abs((withinWindow.time?.created ?? 0) - processStartMs) <= timeWindowMs {
            return withinWindow
        }

        trace(
            "statusline.opencode.session.fallback_to_newest",
            attributes: [
                "session_count": "\(matching.count)",
                "process_start_ms": "\(processStartMs)",
                "closest_created_ms":
                    "\(matching.compactMap { $0.time?.created }.min { abs($0 - processStartMs) < abs($1 - processStartMs) } ?? 0)",
            ])
        return matching.max { ($0.time?.created ?? 0) < ($1.time?.created ?? 0) }
    }

    private func renameSessionIfNeeded(_ session: OpenCodeSession) async {
        let desiredTitle = "\(context.tabName)/\(context.paneName)"
        guard session.title != desiredTitle else { return }
        do {
            _ = try await client.rename(session.id, title: desiredTitle)
            trace(
                "statusline.opencode.session.named",
                attributes: [
                    "session_id_prefix": String(session.id.prefix(12)),
                    "title": desiredTitle,
                ])
        } catch {
            trace(
                "statusline.opencode.session.rename_failed",
                attributes: [
                    "session_id_prefix": String(session.id.prefix(12)),
                    "error": String(describing: error),
                ])
        }
    }

    // MARK: - Polling

    private func startPollTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                await self?.refreshSession()
            }
        }
        timer.resume()
        pollTimer = timer
    }

    private func refreshSession() async {
        guard let boundSessionID else { return }
        do {
            let session = try await client.session(boundSessionID)
            mergeHarnessData(session)
            trace(
                "statusline.opencode.poll.success",
                attributes: [
                    "session_id_prefix": String(boundSessionID.prefix(12)),
                    "has_model": session.model != nil ? "true" : "false",
                    "has_cost": session.cost != nil ? "true" : "false",
                    "has_tokens": session.tokens != nil ? "true" : "false",
                ])
        } catch {
            trace(
                "statusline.opencode.poll.failed",
                attributes: [
                    "session_id_prefix": String(boundSessionID.prefix(12)),
                    "error": String(describing: error),
                ])
        }
    }

    // MARK: - Merge

    private func mergeHarnessData(_ session: OpenCodeSession) {
        let model: StatusLineData.Model? = session.model.map { sessionModel in
            let displayName: String? = {
                guard let providerID = sessionModel.providerID, let id = sessionModel.id else {
                    return sessionModel.id ?? sessionModel.variant
                }
                return "\(providerID)/\(id)"
            }()
            return StatusLineData.Model(id: sessionModel.id, displayName: displayName)
        }

        let cost: StatusLineData.Cost? = session.cost.map {
            StatusLineData.Cost(
                totalCostUsd: $0,
                totalDurationMs: nil,
                totalLinesAdded: nil,
                totalLinesRemoved: nil
            )
        }

        let contextWindow: StatusLineData.ContextWindow? = session.tokens.map {
            StatusLineData.ContextWindow(
                usedPercentage: nil,
                remainingPercentage: nil,
                totalInputTokens: $0.input,
                totalOutputTokens: $0.output,
                contextWindowSize: nil,
                currentUsage: nil
            )
        }

        latestHarnessData = StatusLineData(
            model: model,
            cost: cost,
            contextWindow: contextWindow,
            rateLimits: nil,
            worktree: nil,
            workspace: nil,
            effort: nil,
            thinking: nil,
            agent: nil,
            outputStyle: nil,
            vim: nil,
            sessionName: session.title,
            version: session.version ?? detectedVersion,
            exceeds200kTokens: nil,
            pr: nil,
            sessionStatus: nil,
            repo: nil
        )
        emitMerged()
    }

    private func emitMerged() {
        guard var data = latestBaselineData else { return }
        if let harness = latestHarnessData {
            if harness.model != nil { data.model = harness.model }
            if harness.cost != nil { data.cost = harness.cost }
            if harness.contextWindow != nil { data.contextWindow = harness.contextWindow }
            if harness.version != nil { data.version = harness.version }
            if harness.sessionName != nil { data.sessionName = harness.sessionName }
        }
        onUpdate?(data)
    }

    // MARK: - Retry helpers

    private func sleepUntilNextRetry(deadline: Date) async -> Bool {
        let remaining = deadline.timeIntervalSince(Date())
        let interval = min(startupRetryInterval, max(0, remaining))
        if interval > 0 {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        return Task.isCancelled
    }

    // MARK: - Tracing

    private func trace(_ name: String, attributes extraAttributes: [String: String] = [:]) {
        var attributes = [
            "provider": "opencode",
            "pane.name": context.paneName,
            "pane.id": context.paneID.uuidString,
            "tab.id": context.tabID.uuidString,
            "tab.name": context.tabName,
        ]
        for (key, value) in extraAttributes { attributes[key] = value }
        TracingService.shared.record(name, attributes: attributes)
    }
}
