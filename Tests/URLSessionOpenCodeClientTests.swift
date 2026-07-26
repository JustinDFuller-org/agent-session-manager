import XCTest

@testable import AgentSessionManager

final class URLSessionOpenCodeClientTests: XCTestCase {
    private var originalProtocolClasses: [AnyClass]?

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testHealthReturnsHealthyAndVersion() async throws {
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/global/health")

            let data = Data(
                """
                {"healthy":true,"version":"1.17.20"}
                """.utf8)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }

        let client = URLSessionOpenCodeClient(port: 12345, session: stubbedSession())
        let (healthy, version) = try await client.health()
        XCTAssertTrue(healthy)
        XCTAssertEqual(version, "1.17.20")
    }

    func testAuthenticatedRequestsUseBasicAuthAndLongSSETimeout() throws {
        let client = URLSessionOpenCodeClient(
            port: 12345,
            environment: ["OPENCODE_SERVER_USERNAME": "user", "OPENCODE_SERVER_PASSWORD": "secret"],
            session: stubbedSession())

        let request = try client.makeRequest(path: "/event", method: "GET", body: nil, timeout: 90)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic dXNlcjpzZWNyZXQ=")
        XCTAssertEqual(request.timeoutInterval, 90)
    }

    func testCurrentStatusEventSchemaIsDecoded() {
        let busy = URLSessionOpenCodeClient.parseEvent(
            type: "message",
            data:
                #"{"directory":"/tmp","payload":{"type":"session.status","properties":{"sessionID":"ses_current","status":{"type":"busy"}}}}"#
        )
        let idle = URLSessionOpenCodeClient.parseEvent(
            type: "session.status",
            data: #"{"type":"session.status","properties":{"sessionID":"ses_current","status":{"type":"idle"}}}"#)

        guard case .sessionBusy(let busyID) = busy else {
            XCTFail("Expected current structured busy status")
            return
        }
        guard case .sessionIdle(let idleID) = idle else {
            XCTFail("Expected current structured idle status")
            return
        }
        XCTAssertEqual(busyID, "ses_current")
        XCTAssertEqual(idleID, "ses_current")

        let updated = URLSessionOpenCodeClient.parseEvent(
            type: "session.updated",
            data: #"{"type":"session.updated","properties":{"info":{"id":"ses_current"}}}"#)
        guard case .sessionUpdated(let updatedID) = updated else {
            XCTFail("Expected current session.updated metadata event")
            return
        }
        XCTAssertEqual(updatedID, "ses_current")
    }

    func testHealthThrowsOnNon200() async {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let client = URLSessionOpenCodeClient(port: 12345, session: stubbedSession())
        do {
            _ = try await client.health()
            XCTFail("Expected unexpectedStatus error")
        } catch let error as OpenCodeServerClientError {
            if case .unexpectedStatus(let code) = error {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Unexpected error kind: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTUIEndpointGuardRejectsSubmitPrompt() async {
        StubURLProtocol.requestHandler = { request in
            XCTFail("Request should not be sent for /tui/submit-prompt")
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let client = URLSessionOpenCodeClient(port: 12345, session: stubbedSession())
        do {
            let request = try client.makeRequest(path: "/tui/submit-prompt", method: "POST", body: Data())
            _ = try await client.perform(request: request)
            XCTFail("Expected forbiddenTUIEndpoint error")
        } catch let error as OpenCodeServerClientError {
            if case .forbiddenTUIEndpoint(let path) = error {
                XCTAssertEqual(path, "/tui/submit-prompt")
            } else {
                XCTFail("Unexpected error kind: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTUIEndpointGuardVariants() throws {
        let client = URLSessionOpenCodeClient(port: 12345, session: stubbedSession())
        let forbiddenPaths = ["/tui/submit-prompt", "//tui/foo", "/TUI/foo", "/tui/"]
        for path in forbiddenPaths {
            do {
                _ = try client.makeRequest(path: path, method: "POST", body: nil)
                XCTFail("Expected forbiddenTUIEndpoint for \(path)")
            } catch let error as OpenCodeServerClientError {
                if case .forbiddenTUIEndpoint = error {
                    // expected
                } else {
                    XCTFail("Expected forbiddenTUIEndpoint for \(path), got \(error)")
                }
            }
        }
    }

    func testRedirectIsRejected() async {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": "http://example.com/"]
            )!
            return (Data(), response)
        }

        let client = URLSessionOpenCodeClient(port: 12345, session: stubbedSession())
        do {
            _ = try await client.health()
            XCTFail("Expected unexpectedStatus error after redirect rejection")
        } catch let error as OpenCodeServerClientError {
            if case .unexpectedStatus(let code) = error {
                XCTAssertEqual(code, 302)
            } else {
                XCTFail("Unexpected error kind: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func stubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (Data, URLResponse))?

    override static func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = StubURLProtocol.requestHandler else {
            fatalError("No request handler set")
        }
        let (data, response) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
