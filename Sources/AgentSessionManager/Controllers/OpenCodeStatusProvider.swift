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
    let status: String?
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

// MARK: - Server events

enum OpenCodeEvent: Sendable {
    case sessionIdle(sessionID: String)
    case permissionAsked(sessionID: String, permission: String, patterns: [String])
    case permissionReplied(sessionID: String, permission: String)
    case sessionBusy(sessionID: String)
    case sessionUpdated(sessionID: String)
    case heartbeat
    case other(type: String)
}

// MARK: - Server client protocol

protocol OpenCodeServerClient: Sendable {
    func health() async throws -> (healthy: Bool, version: String?)
    func listSessions() async throws -> [OpenCodeSession]
    func session(_ id: String) async throws -> OpenCodeSession
    func rename(_ id: String, title: String) async throws -> OpenCodeSession
    func events() -> AsyncThrowingStream<OpenCodeEvent, Error>
}

enum OpenCodeServerClientError: Error {
    case missingPort
    case invalidURL
    case unexpectedStatus(Int)
    case decodingFailed(underlying: Error)
    case forbiddenTUIEndpoint(path: String)
}

// MARK: - URLSession client

final class URLSessionOpenCodeClient: OpenCodeServerClient, @unchecked Sendable {
    private let port: Int?
    private let serverUsername: String?
    private let serverPassword: String?
    private let session: URLSession

    init(port: Int?, environment: [String: String] = [:], session: URLSession? = nil) {
        self.port = port
        serverPassword = environment["OPENCODE_SERVER_PASSWORD"]
        serverUsername = environment["OPENCODE_SERVER_USERNAME"] ?? "opencode"
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.httpShouldSetCookies = false
            let delegate = OpenCodeURLSessionDelegate()
            self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        }
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

    func events() -> AsyncThrowingStream<OpenCodeEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(path: "/event", method: "GET", body: nil, timeout: 90)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                        (200..<300).contains(httpResponse.statusCode)
                    else {
                        throw OpenCodeServerClientError.unexpectedStatus(
                            (response as? HTTPURLResponse)?.statusCode ?? 0)
                    }

                    var eventType: String?
                    var dataBuffer = ""
                    let maxEventBytes = 1_048_576

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }

                        if line.isEmpty {
                            if let type = eventType, !dataBuffer.isEmpty {
                                if let event = Self.parseEvent(type: type, data: dataBuffer) {
                                    continuation.yield(event)
                                }
                            }
                            eventType = nil
                            dataBuffer = ""
                            continue
                        }

                        if line.hasPrefix("event:") {
                            eventType = String(line.dropFirst("event:".count)).trimmingCharacters(
                                in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let payload = String(line.dropFirst("data:".count)).trimmingCharacters(
                                in: .whitespaces)
                            if dataBuffer.utf8.count + payload.utf8.count > maxEventBytes {
                                continuation.finish(throwing: OpenCodeServerClientError.unexpectedStatus(0))
                                return
                            }
                            if !dataBuffer.isEmpty { dataBuffer += "\n" }
                            dataBuffer += payload
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func parseEvent(type: String, data: String) -> OpenCodeEvent? {
        switch type {
        case "server.heartbeat":
            return .heartbeat
        default:
            break
        }

        guard let json = data.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(EventEnvelope.self, from: json)
        else {
            return .other(type: type)
        }

        let response = decoded.payload ?? EventResponse(type: decoded.type, properties: decoded.properties)
        let eventName = response.type ?? type
        switch eventName {
        case "session.idle":
            guard let sessionID = response.properties?.sessionID else { return .other(type: type) }
            return .sessionIdle(sessionID: sessionID)
        case "session.status":
            guard let sessionID = response.properties?.sessionID else { return .other(type: type) }
            if response.properties?.status?.value.lowercased() == "busy"
                || response.properties?.status?.value.lowercased() == "retry"
            {
                return .sessionBusy(sessionID: sessionID)
            }
            if response.properties?.status?.value.lowercased() == "idle" {
                return .sessionIdle(sessionID: sessionID)
            }
            return .other(type: eventName)
        case "session.updated":
            guard let sessionID = response.properties?.sessionID ?? response.properties?.info?.id else {
                return .other(type: eventName)
            }
            if response.properties?.status?.value.lowercased() == "busy"
                || response.properties?.status?.value.lowercased() == "retry"
            {
                return .sessionBusy(sessionID: sessionID)
            }
            return .sessionUpdated(sessionID: sessionID)
        case "permission.asked", "permission.updated":
            guard let sessionID = response.properties?.sessionID else { return .other(type: type) }
            return .permissionAsked(
                sessionID: sessionID,
                permission: response.properties?.permission ?? "unknown",
                patterns: response.properties?.patterns ?? []
            )
        case "permission.replied":
            guard let sessionID = response.properties?.sessionID else { return .other(type: type) }
            return .permissionReplied(
                sessionID: sessionID,
                permission: response.properties?.permission ?? "unknown"
            )
        default:
            return .other(type: type)
        }
    }

    private func get(path: String) async throws -> Data {
        let request = try makeRequest(path: path, method: "GET", body: nil)
        return try await perform(request: request)
    }

    private func patch(path: String, body: Data) async throws -> Data {
        let request = try makeRequest(path: path, method: "PATCH", body: body)
        return try await perform(request: request)
    }

    func makeRequest(path: String, method: String, body: Data?, timeout: TimeInterval = 15) throws -> URLRequest {
        guard let port else { throw OpenCodeServerClientError.missingPort }

        let normalizedPath =
            path
            .lowercased()
            .replacingOccurrences(of: "//", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalizedPath.hasPrefix("tui/") || normalizedPath == "tui" {
            InvariantReporter.shared.violated(
                .opencodeTUIEndpointsUnused,
                context: [
                    "path": path,
                    "method": method,
                ])
            throw OpenCodeServerClientError.forbiddenTUIEndpoint(path: path)
        }
        guard !path.contains("?") && !path.contains("#") && !path.contains("\\") else {
            throw OpenCodeServerClientError.invalidURL
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = port
        components.path = path
        guard let url = components.url else {
            throw OpenCodeServerClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let serverPassword {
            let credentials = "\(serverUsername ?? "opencode"):\(serverPassword)"
            let encoded = Data(credentials.utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func perform(request: URLRequest) async throws -> Data {
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

    /// Rejects any HTTP redirect so the OpenCode client cannot be tricked into
    /// leaving the localhost trust boundary.
    private final class OpenCodeURLSessionDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }

    private struct EventEnvelope: Decodable {
        let type: String?
        let properties: EventProperties?
        let payload: EventResponse?
    }

    private struct EventResponse: Decodable {
        let type: String?
        let properties: EventProperties?
    }

    private struct EventProperties: Decodable {
        let sessionID: String?
        let permission: String?
        let patterns: [String]?
        let status: EventStatus?
        let info: SessionInfo?
    }

    private struct SessionInfo: Decodable {
        let id: String?
    }

    private enum EventStatus: Decodable {
        case string(String)
        case object(String)

        var value: String {
            switch self {
            case .string(let value), .object(let value): return value
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self = .string(value)
                return
            }
            let object = try container.decode(StatusObject.self)
            self = .object(object.type)
        }

        private struct StatusObject: Decodable {
            let type: String
        }
    }

    private struct SessionResponse: Decodable {
        let id: String
        let title: String?
        let directory: String?
        let parentID: String?
        let status: String?
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
                case providerID
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
                status: status,
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

@MainActor
final class OpenCodeStatusProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?
    var onAttention: ((PaneAttentionEvent) -> Void)?
    var onOpencodeStopped: (() -> Void)?
    var onActivityChanged: ((Bool) -> Void)?
    var onSessionBound: ((String) -> Void)?
    var onPermissionReplied: (() -> Void)?
    var onPortRaceLost: (() -> Void)?

    private enum Lifecycle: String { case unknown, working, idle }

    private let context: StatusProviderContext
    private let client: any OpenCodeServerClient
    private let startupRetryInterval: TimeInterval
    private let startupTimeout: TimeInterval
    private let pollInterval: TimeInterval
    private let timeWindowMs: Int64
    private let appDirectory: String
    private let baseline: ToolAgnosticDataProvider
    private var stateTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var pollTimer: DispatchSourceTimer?
    private var latestHarnessData: StatusLineData?
    private var latestBaselineData: StatusLineData?
    private var boundSessionID: String?
    private var detectedVersion: String?
    private var lifecycle: Lifecycle = .unknown

    init(
        context: StatusProviderContext,
        client: (any OpenCodeServerClient)? = nil,
        startupRetryInterval: TimeInterval = 0.5,
        startupTimeout: TimeInterval = 15,
        pollInterval: TimeInterval = 15,
        timeWindowMs: Int64 = 60_000
    ) {
        self.context = context
        self.client =
            client
            ?? URLSessionOpenCodeClient(
                port: context.opencodePort,
                environment: context.opencodeEnvironment
            )
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
            Task { @MainActor in
                guard let self else { return }
                self.latestBaselineData = data
                self.emitMerged()
            }
        }
        baseline.start()
        stateTask = Task { [weak self] in
            await self?.bindSession()
        }
    }

    func stop() {
        stateTask?.cancel()
        stateTask = nil
        eventTask?.cancel()
        eventTask = nil
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
            return
        }

        let deadline = Date().addingTimeInterval(startupTimeout)
        var attempt = 0
        var didTraceServerWaiting = false

        while !Task.isCancelled {
            attempt += 1
            let lateBound = Date() > deadline
            var attemptError: Error?

            do {
                let (healthy, version) = try await client.health()
                if healthy {
                    detectedVersion = OpenCodeVersionAdapter.normalize(version)
                    if detectedVersion == nil {
                        trace(
                            "statusline.opencode.version.drift",
                            attributes: [
                                "reason": "health_version_missing",
                                "raw_version": version ?? "nil",
                            ])
                    }
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
                        onSessionBound?(session.id)
                        let sessionIDPrefix = String(session.id.prefix(12))
                        trace(
                            "statusline.opencode.session.bound",
                            attributes: [
                                "session_id_prefix": sessionIDPrefix,
                                "retry_attempt": "\(attempt)",
                                "late_bound": lateBound ? "true" : "false",
                            ])

                        if let expectedSessionID = context.opencodeSessionID, session.id != expectedSessionID {
                            InvariantReporter.shared.violated(
                                .opencodeSessionRebindable,
                                context: [
                                    "pane.id": context.paneID.uuidString,
                                    "pane.name": context.paneName,
                                    "tab.id": context.tabID.uuidString,
                                    "tab.name": context.tabName,
                                    "expected_session_id_prefix": String(expectedSessionID.prefix(12)),
                                    "bound_session_id_prefix": sessionIDPrefix,
                                ])
                        }

                        await renameSessionIfNeeded(session)
                        startEventStream()
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
                attemptError = error
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
                if let error = attemptError, let port = context.opencodePort {
                    trace(
                        "opencode.port_allocation.failed",
                        attributes: [
                            "reason": "race_lost",
                            "port": String(port),
                            "error": String(describing: error),
                            "late_bound": "true",
                            "retry_attempt": "\(attempt)",
                        ])
                    onPortRaceLost?()
                }
                trace(
                    "statusline.opencode.session.unbindable",
                    attributes: [
                        "retry_attempt": "\(attempt)",
                        "reason": "startup_timeout",
                        "app_directory": appDirectory,
                    ])
                InvariantReporter.shared.violated(
                    .opencodeSessionRebindable,
                    context: [
                        "pane.id": context.paneID.uuidString,
                        "pane.name": context.paneName,
                        "tab.id": context.tabID.uuidString,
                        "tab.name": context.tabName,
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
            guard session.parentID == nil else { return false }
            guard let directory = session.directory else { return false }
            return URL(filePath: directory).resolvingSymlinksInPath().path == appDirectory
        }

        let processStartMs = Int64(context.processStartTime.timeIntervalSince1970 * 1000)

        if let expectedSessionID = context.opencodeSessionID,
            let expected = matching.first(where: { $0.id == expectedSessionID })
        {
            return expected
        }

        if let expectedSessionID = context.opencodeSessionID {
            trace(
                "statusline.opencode.session.expected_missing",
                attributes: [
                    "expected_session_id_prefix": String(expectedSessionID.prefix(12)),
                    "matching_session_count": "\(matching.count)",
                ])
        }

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
            "statusline.opencode.session.waiting_for_create",
            attributes: [
                "reason": context.opencodeSessionID == nil ? "no_in_window" : "expected_missing",
                "matching_count": "\(matching.count)",
                "time_window_ms": "\(timeWindowMs)",
            ])
        return nil
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
            updateLifecycleFromSession(session)
            trace(
                "statusline.opencode.poll.success",
                attributes: [
                    "session_id_prefix": String(boundSessionID.prefix(12)),
                    "has_model": session.model != nil ? "true" : "false",
                    "has_cost": session.cost != nil ? "true" : "false",
                    "has_tokens": session.tokens != nil ? "true" : "false",
                    "status": session.status ?? "unknown",
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

    // MARK: - Events

    private func startEventStream() {
        eventTask = Task { [weak self] in
            await self?.consumeEvents()
        }
    }

    private func consumeEvents() async {
        guard let boundSessionID else { return }
        var attempt = 0
        let maxBackoff: TimeInterval = 60

        while !Task.isCancelled {
            attempt += 1
            trace(
                "statusline.opencode.sse.connecting",
                attributes: [
                    "session_id_prefix": String(boundSessionID.prefix(12)),
                    "attempt": "\(attempt)",
                ])

            do {
                let stream = client.events()
                trace(
                    "statusline.opencode.sse.connected",
                    attributes: [
                        "session_id_prefix": String(boundSessionID.prefix(12)),
                        "attempt": "\(attempt)",
                    ])

                for try await event in stream {
                    guard !Task.isCancelled else { return }
                    // Reset retry budget after a successfully delivered event; only genuine
                    // transport failures should back off.
                    if attempt > 1 { attempt = 1 }
                    await handleEvent(event)
                }
            } catch {
                trace(
                    "statusline.opencode.sse.disconnected",
                    attributes: [
                        "session_id_prefix": String(boundSessionID.prefix(12)),
                        "attempt": "\(attempt)",
                        "error": String(describing: error),
                    ])
            }

            guard !Task.isCancelled else { break }
            let backoff = min(0.5 * Double(attempt), maxBackoff)
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
        }
    }

    private func handleEvent(_ event: OpenCodeEvent) async {
        guard let boundSessionID else { return }

        switch event {
        case .heartbeat:
            break
        case .other:
            break
        case .sessionIdle(let sessionID):
            guard sessionID == boundSessionID else { return }
            trace(
                "statusline.opencode.sse.session_idle",
                attributes: [
                    "session_id_prefix": String(sessionID.prefix(12)),
                    "lifecycle": lifecycle.rawValue,
                ])
            transitionLifecycle(to: .idle)
        case .sessionBusy(let sessionID):
            guard sessionID == boundSessionID else { return }
            trace(
                "statusline.opencode.sse.session_busy",
                attributes: [
                    "session_id_prefix": String(sessionID.prefix(12)),
                    "lifecycle": lifecycle.rawValue,
                ])
            transitionLifecycle(to: .working)
        case .sessionUpdated(let sessionID):
            guard sessionID == boundSessionID else { return }
            await refreshSession()
        case .permissionAsked(let sessionID, let permission, let patterns):
            guard sessionID == boundSessionID else { return }

            let patternCount = patterns.count
            let reason =
                patternCount == 0
                ? "Permission needed for \(permission)"
                : "Permission needed for \(permission) (\(patternCount) requested paths)"
            trace(
                "statusline.opencode.permission.fired",
                attributes: [
                    "session_id_prefix": String(sessionID.prefix(12)),
                    "permission": permission,
                    "patterns": "\(patterns.count)",
                ])
            onAttention?(PaneAttentionEvent(source: .opencodePermissionRequest, reason: reason))
        case .permissionReplied(let sessionID, let permission):
            guard sessionID == boundSessionID else { return }
            trace(
                "statusline.opencode.permission.replied",
                attributes: [
                    "session_id_prefix": String(sessionID.prefix(12)),
                    "permission": permission,
                ])
            onPermissionReplied?()
        }
    }

    private func transitionLifecycle(to newLifecycle: Lifecycle) {
        if newLifecycle == .idle, lifecycle == .working {
            trace(
                "statusline.opencode.stop.fired",
                attributes: [
                    "session_id_prefix": boundSessionID.map { String($0.prefix(12)) } ?? "unknown",
                    "previous_lifecycle": lifecycle.rawValue,
                ])
            onOpencodeStopped?()
        }
        lifecycle = newLifecycle
        onActivityChanged?(newLifecycle == .working)
    }

    private func updateLifecycleFromSession(_ session: OpenCodeSession) {
        let status = session.status?.lowercased() ?? ""
        if status == "idle" {
            transitionLifecycle(to: .idle)
        } else if status == "busy" {
            transitionLifecycle(to: .working)
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
