import Foundation
import MCP
@preconcurrency import NIOCore
@preconcurrency import NIOHTTP1
@preconcurrency import NIOPosix

actor AgentControlHTTPApplication {
    private struct SessionContext {
        let server: Server
        let transport: StatefulHTTPServerTransport
    }

    private struct FixedSessionIDGenerator: SessionIDGenerator {
        let sessionID: String

        func generateSessionID() -> String { sessionID }
    }

    private let host = "127.0.0.1"
    private let endpointPath = "/mcp"
    private let tokenStore: AgentControlTokenStore
    private let limits: AgentControlLimits
    private var resourceRouter: AgentControlResourceRouter?
    private var channel: Channel?
    private var group: MultiThreadedEventLoopGroup?
    private var sessions: [String: SessionContext] = [:]
    private var boundPort: Int?

    init(
        tokenStore: AgentControlTokenStore,
        limits: AgentControlLimits,
        resourceRouter: AgentControlResourceRouter? = nil
    ) {
        self.tokenStore = tokenStore
        self.limits = limits
        self.resourceRouter = resourceRouter
    }

    func setResourceRouter(_ router: AgentControlResourceRouter?) {
        resourceRouter = router
    }

    func start() async throws -> Int {
        if let boundPort { return boundPort }

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 128)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(AgentControlHTTPHandler(application: self, limits: self.limits))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        do {
            let channel = try await bootstrap.bind(host: host, port: 0).get()
            guard let port = channel.localAddress?.port else {
                try? await channel.close()
                try? await group.shutdownGracefully()
                throw NSError(
                    domain: "AgentControlHTTPApplication", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "The control listener did not report a port."])
            }
            self.group = group
            self.channel = channel
            boundPort = port
            return port
        } catch {
            try? await group.shutdownGracefully()
            throw error
        }
    }

    func stop() async {
        for session in sessions.values {
            await session.server.stop()
            await session.transport.disconnect()
        }
        sessions.removeAll()
        try? await channel?.close()
        channel = nil
        boundPort = nil
        if let group {
            try? await group.shutdownGracefully()
            self.group = nil
        }
    }

    func handle(request: HTTPRequest) async -> HTTPResponse {
        guard request.path == endpointPath else {
            return .error(statusCode: 404, .invalidRequest("Not Found"))
        }

        let sessionID = request.header(HTTPHeaderName.sessionID)
        let isInitialization = isInitializationRequest(request)
        let expectedPort = boundPort.map(String.init) ?? "0"
        let fixedValidator = AgentControlRequestValidator(
            tokenStore: tokenStore,
            expectedHost: "127.0.0.1:\(expectedPort)",
            expectedOrigin: "http://127.0.0.1:\(expectedPort)",
            limits: limits
        )
        let sessionValidator = AgentControlRequestValidator(
            tokenStore: tokenStore,
            expectedHost: fixedValidator.expectedHost,
            expectedOrigin: fixedValidator.expectedOrigin,
            limits: limits,
            tracksConcurrency: false
        )
        if let error = fixedValidator.validate(
            request,
            context: HTTPValidationContext(
                httpMethod: request.method,
                sessionID: sessionID,
                isInitializationRequest: isInitialization
            )
        ) {
            return error
        }
        let requestToken = bearerToken(from: request)
        defer {
            if let requestToken {
                tokenStore.finishRequest(token: requestToken)
            }
        }
        if let sessionID, let session = sessions[sessionID] {
            let response = await session.transport.handleRequest(request)
            if request.method.uppercased() == "DELETE", response.statusCode == 200 {
                sessions.removeValue(forKey: sessionID)
            }
            return response
        }

        guard isInitialization else {
            return .error(statusCode: 404, .invalidRequest("MCP session not found"))
        }

        let newSessionID = UUID().uuidString
        let pipeline = StandardValidationPipeline(validators: [
            sessionValidator,
            AcceptHeaderValidator(mode: .sseRequired),
            ContentTypeValidator(),
            ProtocolVersionValidator(),
            SessionValidator(),
        ])
        let transport = StatefulHTTPServerTransport(
            sessionIDGenerator: FixedSessionIDGenerator(sessionID: newSessionID),
            validationPipeline: pipeline
        )
        let server = Server(
            name: "Agent Session Manager",
            version: "1.0",
            capabilities: .init(
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)),
            configuration: .strict
        )
        do {
            let router = resourceRouter
            let tokenStore = self.tokenStore
            await server.withMethodHandler(ListResources.self) { _ in
                .init(resources: await router?.resources() ?? [])
            }
            await server.withMethodHandler(ListResourceTemplates.self) { _ in
                .init(templates: await router?.resourceTemplates() ?? [])
            }
            await server.withMethodHandler(ListTools.self) { _ in
                .init(tools: await router?.tools() ?? [])
            }
            await server.withMethodHandler(ReadResource.self) { params in
                guard let router, let source = tokenStore.source(forSessionID: newSessionID) else {
                    throw MCPError.invalidRequest("Agent Session Manager resource session is unavailable")
                }
                let content = try await router.read(uri: params.uri, source: source)
                return .init(contents: [.text(content, uri: params.uri, mimeType: "application/json")])
            }
            await server.withMethodHandler(CallTool.self) { params in
                guard let router, let source = tokenStore.source(forSessionID: newSessionID) else {
                    throw MCPError.invalidRequest("Agent Session Manager tool session is unavailable")
                }
                return try await router.callTool(
                    name: params.name, arguments: params.arguments, source: source)
            }
            try await server.start(transport: transport)
            let response = await transport.handleRequest(request)
            guard response.statusCode < 400 else {
                await server.stop()
                await transport.disconnect()
                return response
            }
            guard let token = bearerToken(from: request), tokenStore.bind(sessionID: newSessionID, token: token) else {
                await server.stop()
                await transport.disconnect()
                return .error(statusCode: 401, .invalidRequest("Unable to bind MCP session"))
            }
            sessions[newSessionID] = SessionContext(server: server, transport: transport)
            return response
        } catch {
            await transport.disconnect()
            return .error(statusCode: 500, .internalError("Unable to start MCP session"))
        }
    }

    private func isInitializationRequest(_ request: HTTPRequest) -> Bool {
        guard request.method.uppercased() == "POST", let body = request.body else { return false }
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        return object["method"] as? String == "initialize"
    }

    private func bearerToken(from request: HTTPRequest) -> String? {
        guard let authorization = request.header(HTTPHeaderName.authorization), authorization.hasPrefix("Bearer ")
        else {
            return nil
        }
        return String(authorization.dropFirst("Bearer ".count))
    }
}

private final class AgentControlHTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let application: AgentControlHTTPApplication
    private let limits: AgentControlLimits
    private var head: HTTPRequestHead?
    private var body = ByteBuffer()
    private var bodyTooLarge = false

    init(application: AgentControlHTTPApplication, limits: AgentControlLimits) {
        self.application = application
        self.limits = limits
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            self.head = head
            body = context.channel.allocator.buffer(capacity: 0)
            bodyTooLarge = false
        case .body(var buffer):
            if body.readableBytes + buffer.readableBytes > limits.maxRequestBodyBytes {
                bodyTooLarge = true
            } else if !bodyTooLarge {
                body.writeBuffer(&buffer)
            }
        case .end:
            guard let head else { return }
            let request = makeRequest(head: head)
            let requestTooLarge = bodyTooLarge
            self.head = nil
            body = ByteBuffer()
            Task {
                let response: HTTPResponse
                if requestTooLarge {
                    response = .error(statusCode: 413, .invalidRequest("Request body exceeds the configured limit"))
                } else {
                    response = await withTaskGroup(of: HTTPResponse.self) { group in
                        group.addTask {
                            await self.application.handle(request: request)
                        }
                        group.addTask {
                            do {
                                try await Task.sleep(for: self.limits.requestTimeout)
                            } catch {
                                return .error(statusCode: 499, .invalidRequest("Request cancelled"))
                            }
                            TracingService.shared.record(
                                "agent_control.request.timed_out", attributes: ["result": "timed_out"])
                            return .error(statusCode: 504, .internalError("Request timed out"))
                        }
                        let response = await group.next()!
                        group.cancelAll()
                        return response
                    }
                }
                await write(response, version: head.version, context: context)
            }
        }
    }

    private func makeRequest(head: HTTPRequestHead) -> HTTPRequest {
        var headers: [String: String] = [:]
        for (name, value) in head.headers {
            headers[name] = headers[name].map { "\($0), \(value)" } ?? value
        }
        let bytes = body.readableBytes > 0 ? body.getBytes(at: body.readerIndex, length: body.readableBytes) : nil
        return HTTPRequest(
            method: head.method.rawValue,
            headers: headers,
            body: bytes.map { Data($0) },
            path: head.uri.split(separator: "?").first.map(String.init)
        )
    }

    private func write(_ response: HTTPResponse, version: HTTPVersion, context: ChannelHandlerContext) async {
        let eventLoop = context.eventLoop
        switch response {
        case .stream(let stream, let headers):
            eventLoop.execute {
                var head = HTTPResponseHead(
                    version: version, status: HTTPResponseStatus(statusCode: response.statusCode))
                for (name, value) in headers { head.headers.add(name: name, value: value) }
                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                context.flush()
            }
            var responseBytes = 0
            do {
                for try await chunk in stream {
                    responseBytes += chunk.count
                    guard responseBytes <= limits.maxResponseBodyBytes else {
                        TracingService.shared.record(
                            "agent_control.request.response_too_large", attributes: ["result": "rejected"])
                        break
                    }
                    eventLoop.execute {
                        var buffer = context.channel.allocator.buffer(capacity: chunk.count)
                        buffer.writeBytes(chunk)
                        context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                    }
                }
            } catch {
                TracingService.shared.record(
                    "agent_control.request.stream_failed", attributes: ["result": "failed"])
            }
            eventLoop.execute { context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil) }
        default:
            let responseBody = response.bodyData
            let responseTooLarge = responseBody.map { $0.count > limits.maxResponseBodyBytes } ?? false
            let bodyData: Data?
            if responseTooLarge {
                TracingService.shared.record(
                    "agent_control.request.response_too_large", attributes: ["result": "rejected"])
                bodyData = Data("Response exceeds the configured limit".utf8)
            } else {
                bodyData = responseBody
            }
            let statusCode = responseTooLarge ? 500 : response.statusCode
            eventLoop.execute {
                var head = HTTPResponseHead(version: version, status: HTTPResponseStatus(statusCode: statusCode))
                for (name, value) in response.headers { head.headers.add(name: name, value: value) }
                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                if let bodyData {
                    var buffer = context.channel.allocator.buffer(capacity: bodyData.count)
                    buffer.writeBytes(bodyData)
                    context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                }
                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            }
        }
    }
}
