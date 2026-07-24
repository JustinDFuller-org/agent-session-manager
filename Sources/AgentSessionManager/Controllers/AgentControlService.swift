import CryptoKit
import Foundation
import MCP
import Security

struct AgentControlLimits: Sendable, Equatable {
    let maxRequestBodyBytes: Int
    let maxResponseBodyBytes: Int
    let maxConcurrentRequestsPerCredential: Int
    let requestTimeout: Duration
    let maxRegisteredCredentials: Int
    let maxSessionsPerCredential: Int

    init(
        maxRequestBodyBytes: Int,
        maxResponseBodyBytes: Int,
        maxConcurrentRequestsPerCredential: Int,
        requestTimeout: Duration,
        maxRegisteredCredentials: Int,
        maxSessionsPerCredential: Int = 8
    ) {
        self.maxRequestBodyBytes = maxRequestBodyBytes
        self.maxResponseBodyBytes = maxResponseBodyBytes
        self.maxConcurrentRequestsPerCredential = maxConcurrentRequestsPerCredential
        self.requestTimeout = requestTimeout
        self.maxRegisteredCredentials = maxRegisteredCredentials
        self.maxSessionsPerCredential = maxSessionsPerCredential
    }

    static let `default` = AgentControlLimits(
        maxRequestBodyBytes: 1_048_576,
        maxResponseBodyBytes: 1_048_576,
        maxConcurrentRequestsPerCredential: 4,
        requestTimeout: .seconds(30),
        maxRegisteredCredentials: 256,
        maxSessionsPerCredential: 8
    )
}

struct AgentControlSource: Sendable, Equatable {
    let paneID: UUID
    let paneName: String
    let tabID: UUID
    let tabName: String
    var scope: AgentControlScope
}

struct AgentControlCredential: Sendable, Equatable {
    let endpoint: URL
    let bearerToken: String
    let source: AgentControlSource

    var redactedDescription: String {
        "AgentControlCredential(endpoint: \(endpoint.absoluteString), token: <redacted>)"
    }
}

enum AgentControlServerState: Sendable, Equatable {
    case stopped
    case starting
    case ready(endpoint: URL)
    case failed(String)
}

enum AgentControlAuthorizationFailure: Error, Sendable, Equatable {
    case missingToken
    case malformedToken
    case invalidToken
    case revokedToken
    case unknownSession
    case sessionTokenMismatch
    case invalidHost
    case invalidOrigin
    case requestTooLarge
    case tooManyRequests

    var statusCode: Int {
        switch self {
        case .missingToken, .malformedToken, .invalidToken, .revokedToken, .unknownSession,
            .sessionTokenMismatch:
            return 401
        case .invalidHost, .invalidOrigin:
            return 403
        case .requestTooLarge:
            return 413
        case .tooManyRequests:
            return 429
        }
    }

    var message: String {
        switch self {
        case .missingToken: return "Missing bearer token"
        case .malformedToken: return "Malformed bearer token"
        case .invalidToken: return "Invalid bearer token"
        case .revokedToken: return "Revoked bearer token"
        case .unknownSession: return "Unknown MCP session"
        case .sessionTokenMismatch: return "MCP session is not authorized for this token"
        case .invalidHost: return "Host is not allowed"
        case .invalidOrigin: return "Origin is not allowed"
        case .requestTooLarge: return "Request body exceeds the configured limit"
        case .tooManyRequests: return "Too many concurrent requests"
        }
    }
}

private struct AgentControlTokenRegistration: Sendable {
    let tokenHash: Data
    var source: AgentControlSource
    var activeRequests = 0
    var sessionIDs: Set<String> = []
}

/// Thread-safe runtime-only credential and MCP-session authorization store.
final class AgentControlTokenStore: @unchecked Sendable {
    private let lock = NSLock()
    private var registrations: [UUID: AgentControlTokenRegistration] = [:]
    private var tokenToPane: [Data: UUID] = [:]
    private var sessionToPane: [String: UUID] = [:]

    func register(source: AgentControlSource, limits: AgentControlLimits) throws -> AgentControlCredential {
        let token = Self.randomToken()
        let tokenHash = Self.hash(token)
        let credential = AgentControlCredential(
            endpoint: URL(string: "http://127.0.0.1:0/mcp")!,
            bearerToken: token,
            source: source
        )

        try lock.withLock {
            if registrations[source.paneID] == nil && registrations.count >= limits.maxRegisteredCredentials {
                throw AgentControlAuthorizationFailure.tooManyRequests
            }
            if let previous = registrations.removeValue(forKey: source.paneID) {
                tokenToPane.removeValue(forKey: previous.tokenHash)
                for sessionID in previous.sessionIDs {
                    sessionToPane.removeValue(forKey: sessionID)
                }
            }
            registrations[source.paneID] = AgentControlTokenRegistration(
                tokenHash: tokenHash,
                source: source
            )
            tokenToPane[tokenHash] = source.paneID
        }
        return credential
    }

    func tokenHash(forPaneID paneID: UUID) -> Data? {
        lock.withLock { registrations[paneID]?.tokenHash }
    }

    func tokenHash(for token: String) -> Data {
        Self.hash(token)
    }

    func source(
        for token: String,
        sessionID: String?,
        limits: AgentControlLimits,
        tracksConcurrency: Bool = true
    ) -> Result<AgentControlSource, AgentControlAuthorizationFailure> {
        let tokenHash = Self.hash(token)
        return lock.withLock {
            guard let paneID = tokenToPane[tokenHash], var registration = registrations[paneID] else {
                return .failure(.invalidToken)
            }
            guard registration.activeRequests < limits.maxConcurrentRequestsPerCredential else {
                return .failure(.tooManyRequests)
            }
            if let sessionID {
                guard sessionToPane[sessionID] != nil else { return .failure(.unknownSession) }
                guard sessionToPane[sessionID] == paneID, registration.sessionIDs.contains(sessionID) else {
                    return .failure(.sessionTokenMismatch)
                }
            }
            if tracksConcurrency {
                registration.activeRequests += 1
                registrations[paneID] = registration
            }
            return .success(registration.source)
        }
    }

    func finishRequest(token: String) {
        let tokenHash = Self.hash(token)
        lock.withLock {
            guard let paneID = tokenToPane[tokenHash], var registration = registrations[paneID] else { return }
            registration.activeRequests = max(0, registration.activeRequests - 1)
            registrations[paneID] = registration
        }
    }

    func bind(sessionID: String, token: String, limits: AgentControlLimits) -> Bool {
        let tokenHash = Self.hash(token)
        return lock.withLock {
            guard let paneID = tokenToPane[tokenHash], var registration = registrations[paneID] else { return false }
            guard sessionToPane[sessionID] == nil,
                registration.sessionIDs.count < limits.maxSessionsPerCredential
            else { return false }
            sessionToPane[sessionID] = paneID
            registration.sessionIDs.insert(sessionID)
            registrations[paneID] = registration
            return true
        }
    }

    func source(forSessionID sessionID: String) -> AgentControlSource? {
        lock.withLock {
            guard let paneID = sessionToPane[sessionID] else { return nil }
            return registrations[paneID]?.source
        }
    }

    func unbind(sessionID: String) {
        lock.withLock {
            guard let paneID = sessionToPane.removeValue(forKey: sessionID),
                var registration = registrations[paneID]
            else { return }
            registration.sessionIDs.remove(sessionID)
            registrations[paneID] = registration
        }
    }

    func revoke(paneID: UUID) {
        lock.withLock {
            guard let registration = registrations.removeValue(forKey: paneID) else { return }
            tokenToPane.removeValue(forKey: registration.tokenHash)
            for sessionID in registration.sessionIDs {
                sessionToPane.removeValue(forKey: sessionID)
            }
        }
    }

    func updateScope(_ scope: AgentControlScope) {
        lock.withLock {
            for paneID in registrations.keys {
                registrations[paneID]?.source.scope = scope
            }
        }
    }

    func clear() {
        lock.withLock {
            registrations.removeAll()
            tokenToPane.removeAll()
            sessionToPane.removeAll()
        }
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(result == errSecSuccess, "Unable to create Agent Session Manager control credential")
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func hash(_ token: String) -> Data {
        Data(SHA256.hash(data: Data(token.utf8)))
    }
}

struct AgentControlRequestValidator: HTTPRequestValidator {
    let tokenStore: AgentControlTokenStore
    let expectedHost: String
    let expectedOrigin: String
    let limits: AgentControlLimits
    var tracksConcurrency = true

    func validate(_ request: HTTPRequest, context: HTTPValidationContext) -> HTTPResponse? {
        if let body = request.body, body.count > limits.maxRequestBodyBytes {
            return .error(statusCode: 413, .invalidRequest(AgentControlAuthorizationFailure.requestTooLarge.message))
        }
        guard request.header(HTTPHeaderName.host) == expectedHost else {
            return .error(statusCode: 403, .invalidRequest(AgentControlAuthorizationFailure.invalidHost.message))
        }
        if let origin = request.header(HTTPHeaderName.origin), origin != expectedOrigin {
            return .error(statusCode: 403, .invalidRequest(AgentControlAuthorizationFailure.invalidOrigin.message))
        }
        guard let authorization = request.header(HTTPHeaderName.authorization) else {
            return .error(statusCode: 401, .invalidRequest(AgentControlAuthorizationFailure.missingToken.message))
        }
        guard authorization.hasPrefix("Bearer ") else {
            return .error(statusCode: 400, .invalidRequest(AgentControlAuthorizationFailure.malformedToken.message))
        }
        let token = String(authorization.dropFirst("Bearer ".count))
        guard !token.isEmpty, !token.contains(where: \.isWhitespace) else {
            return .error(statusCode: 400, .invalidRequest(AgentControlAuthorizationFailure.malformedToken.message))
        }
        switch tokenStore.source(
            for: token,
            sessionID: context.sessionID,
            limits: limits,
            tracksConcurrency: tracksConcurrency
        ) {
        case .success:
            return nil
        case .failure(let failure):
            return .error(statusCode: failure.statusCode, .invalidRequest(failure.message))
        }
    }
}

@MainActor
final class AgentControlService {
    static let shared = AgentControlService()

    private let tokenStore: AgentControlTokenStore
    private let limits: AgentControlLimits
    private let httpApplication: AgentControlHTTPApplication
    private var resourceRouter: AgentControlResourceRouter?
    private(set) var state: AgentControlServerState = .stopped
    private(set) var endpoint: URL?

    init(limits: AgentControlLimits = .default) {
        self.limits = limits
        tokenStore = AgentControlTokenStore()
        httpApplication = AgentControlHTTPApplication(tokenStore: tokenStore, limits: limits)
    }

    func start() async {
        guard case .stopped = state else { return }
        state = .starting
        TracingService.shared.record("agent_control.server.starting")
        do {
            let port = try await httpApplication.start()
            let url = URL(string: "http://127.0.0.1:\(port)/mcp")!
            endpoint = url
            state = .ready(endpoint: url)
            TracingService.shared.record(
                "agent_control.server.started",
                attributes: ["endpoint": "http://127.0.0.1:\(port)/mcp", "result": "ready"]
            )
        } catch {
            state = .failed(error.localizedDescription)
            TracingService.shared.record(
                "agent_control.server.start_failed",
                attributes: ["result": "failed", "error": error.localizedDescription]
            )
        }
    }

    func configure(appState: AppState, appSettings: AppSettings) async {
        let router = AgentControlResourceRouter(appState: appState, appSettings: appSettings)
        resourceRouter = router
        await httpApplication.setResourceRouter(router)
    }

    func stop() async {
        guard !isStopped else { return }
        await httpApplication.stop()
        tokenStore.clear()
        endpoint = nil
        state = .stopped
        TracingService.shared.record("agent_control.server.stopped", attributes: ["result": "stopped"])
    }

    func register(source: AgentControlSource) throws -> AgentControlCredential {
        guard case .ready(let endpoint) = state else {
            throw NSError(
                domain: "AgentControlService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Agent Session Manager control server is unavailable."])
        }
        let previousTokenHash = tokenStore.tokenHash(forPaneID: source.paneID)
        let credential = try tokenStore.register(source: source, limits: limits)
        if let previousTokenHash {
            Task {
                await httpApplication.disconnectSessions(
                    forPaneID: source.paneID, tokenHash: previousTokenHash)
            }
        }
        let resolved = AgentControlCredential(endpoint: endpoint, bearerToken: credential.bearerToken, source: source)
        TracingService.shared.record(
            "agent_control.credential.registered",
            attributes: [
                "pane.id": source.paneID.uuidString,
                "pane.name": source.paneName,
                "tab.id": source.tabID.uuidString,
                "tab.name": source.tabName,
                "scope": source.scope.rawValue,
                "result": "registered",
            ]
        )
        return resolved
    }

    func revoke(paneID: UUID, paneName: String? = nil, tabID: UUID? = nil, tabName: String? = nil) {
        tokenStore.revoke(paneID: paneID)
        Task {
            await httpApplication.disconnectSessions(forPaneID: paneID)
        }
        guard let paneName, let tabID, let tabName else { return }
        TracingService.shared.record(
            "agent_control.credential.revoked",
            attributes: [
                "pane.id": paneID.uuidString,
                "pane.name": paneName,
                "tab.id": tabID.uuidString,
                "tab.name": tabName,
                "result": "revoked",
            ]
        )
    }

    func updateScope(_ scope: AgentControlScope) {
        tokenStore.updateScope(scope)
        TracingService.shared.record("agent_control.scope.updated", attributes: ["scope": scope.rawValue])
    }

    private var isStopped: Bool {
        if case .stopped = state { return true }
        return false
    }
}
