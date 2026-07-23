import Foundation
import MCP
import XCTest

@testable import AgentSessionManager

final class AgentControlLifecycleTests: XCTestCase {
    func testTokenStoreEnforcesConcurrencyAndRevocation() throws {
        let store = AgentControlTokenStore()
        let source = AgentControlSource(
            paneID: UUID(),
            paneName: "Pane",
            tabID: UUID(),
            tabName: "Tab",
            scope: .pane
        )
        let limits = AgentControlLimits(
            maxRequestBodyBytes: 1_024,
            maxResponseBodyBytes: 1_024,
            maxConcurrentRequestsPerCredential: 1,
            requestTimeout: .seconds(1),
            maxRegisteredCredentials: 1
        )
        let credential = try store.register(source: source, limits: limits)

        XCTAssertEqual(
            store.source(for: credential.bearerToken, sessionID: nil, limits: limits),
            .success(source)
        )
        XCTAssertEqual(
            store.source(for: credential.bearerToken, sessionID: nil, limits: limits),
            .failure(.tooManyRequests)
        )

        store.finishRequest(token: credential.bearerToken)
        XCTAssertEqual(
            store.source(for: credential.bearerToken, sessionID: nil, limits: limits),
            .success(source)
        )

        store.revoke(paneID: source.paneID)
        XCTAssertEqual(
            store.source(for: credential.bearerToken, sessionID: nil, limits: limits),
            .failure(.invalidToken)
        )
    }

    func testValidatorRejectsUntrustedHostAndOrigin() throws {
        let store = AgentControlTokenStore()
        let source = AgentControlSource(
            paneID: UUID(), paneName: "Pane", tabID: UUID(), tabName: "Tab", scope: .pane)
        let limits = AgentControlLimits.default
        let credential = try store.register(source: source, limits: limits)
        let validator = AgentControlRequestValidator(
            tokenStore: store,
            expectedHost: "127.0.0.1:1234",
            expectedOrigin: "http://127.0.0.1:1234",
            limits: limits
        )

        let hostRequest = HTTPRequest(
            method: "POST",
            headers: [
                HTTPHeaderName.host: "localhost:1234",
                HTTPHeaderName.authorization: "Bearer \(credential.bearerToken)",
            ],
            body: Data("{}".utf8),
            path: "/mcp"
        )
        XCTAssertEqual(
            validator.validate(
                hostRequest, context: .init(httpMethod: "POST", sessionID: nil, isInitializationRequest: true))?
                .statusCode,
            403
        )
        store.finishRequest(token: credential.bearerToken)

        let originRequest = HTTPRequest(
            method: "POST",
            headers: [
                HTTPHeaderName.host: "127.0.0.1:1234",
                HTTPHeaderName.origin: "http://localhost:1234",
                HTTPHeaderName.authorization: "Bearer \(credential.bearerToken)",
            ],
            body: Data("{}".utf8),
            path: "/mcp"
        )
        XCTAssertEqual(
            validator.validate(
                originRequest, context: .init(httpMethod: "POST", sessionID: nil, isInitializationRequest: true))?
                .statusCode,
            403
        )
    }

    func testHTTPApplicationBindsLoopbackEndpointAndRejectsUnauthorizedRequest() async throws {
        let store = AgentControlTokenStore()
        let application = AgentControlHTTPApplication(tokenStore: store, limits: .default)
        let port = try await application.start()
        defer { Task { await application.stop() } }

        let response = await application.handle(
            request: HTTPRequest(
                method: "POST",
                headers: [
                    HTTPHeaderName.host: "127.0.0.1:\(port)",
                    HTTPHeaderName.contentType: "application/json",
                ],
                body: Data("{\"method\":\"initialize\"}".utf8),
                path: "/mcp"
            ))

        XCTAssertEqual(response.statusCode, 401)
    }
}
