import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension
import SignPostIntegration

/// Opaque handle to a live span. Callers hold this to add child spans or end the span
/// at a time they control — necessary for callback-based async flows where withSpan
/// cannot wrap the body (e.g., Process terminationHandler).
final class SpanHandle: @unchecked Sendable {
    fileprivate let span: any Span

    fileprivate init(_ span: any Span) {
        self.span = span
    }
}

/// Thin wrapper around the OpenTelemetry Swift SDK. Thread-safe; callers on any actor may use it.
final class TracingService: @unchecked Sendable {
    static let shared = TracingService()

    private let lock = NSLock()
    private var _isEnabled = false
    private var _tracer: (any Tracer)?
    private var _testCaptureEnabled = false
    private var _recordedEventsForTesting: [(name: String, attributes: [String: String])] = []

    private init() {}

    // MARK: - Test Capture

    var recordedEventsForTesting: [(name: String, attributes: [String: String])] {
        lock.withLock { _recordedEventsForTesting }
    }

    func enableTestCapture() {
        lock.withLock { _testCaptureEnabled = true }
    }

    func resetForTesting() {
        lock.withLock {
            _testCaptureEnabled = false
            _recordedEventsForTesting = []
        }
    }

    var isEnabled: Bool {
        lock.withLock { _isEnabled }
    }

    private static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    /// Call on startup and whenever tracing settings change. Must be called from the main actor
    /// (AppSettings is @MainActor), but reconfigures the underlying SDK on whatever thread called it.
    @MainActor
    func configure(from settings: AppSettings) {
        guard settings.debugModeEnabled else {
            lock.withLock {
                _isEnabled = false
                _tracer = nil
            }
            return
        }

        let resource = DefaultResources().get().merging(
            other: Resource(attributes: [
                ResourceAttributes.serviceName.rawValue: .string("AgentSessionManager"),
                ResourceAttributes.serviceVersion.rawValue: .string(Self.appVersion),
            ])
        )

        let exporter: any SpanExporter = PerPaneSpanExporter(
            tracesDirectory: settings.resolvedTracingDirectoryURL,
            maxBytesPerFile: AppSettings.debugFileMaxBytes,
            resourceAttributes: resource.attributes.mapValues(\.description)
        )

        // SimpleSpanProcessor (not BatchSpanProcessor) is intentional: the trace dashboard
        // live-tails JSONL via DispatchSource and record(...) models instant events, so spans
        // must land on disk immediately rather than sit in a batch buffer.
        var builder = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))

        if #available(macOS 12, *) {
            builder = builder.add(spanProcessor: OSSignposterIntegration())
        } else {
            builder = builder.add(spanProcessor: SignPostIntegration())
        }

        let provider = builder.build()

        let tracer = provider.get(
            instrumentationName: "AgentSessionManager",
            instrumentationVersion: "1.0.0"
        )

        lock.withLock {
            _isEnabled = true
            _tracer = tracer
        }
    }

    // MARK: - Long-lived spans

    /// Starts a span and returns a handle. The caller must call ``end(handle:attributes:)``
    /// when the work completes. Use this for callback-based flows where ``withSpan`` cannot
    /// wrap the body (e.g., Process terminationHandler chains).
    func startSpan(_ name: String, attributes: [String: String] = [:]) -> SpanHandle? {
        AppLog.log(name, level: .debug, attributes: attributes)
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else { return nil }
        let span = tracer.spanBuilder(spanName: name).startSpan()
        for (key, value) in attributes { span.setAttribute(key: key, value: value) }
        return SpanHandle(span)
    }

    /// Ends a span previously started with ``startSpan(_:attributes:)``.
    /// Passing `nil` is a no-op, so callers can hold optional handles without guarding.
    func end(handle: SpanHandle?, attributes: [String: String] = [:]) {
        guard let handle else { return }
        AppLog.log(handle.span.name, level: .debug, attributes: attributes)
        for (key, value) in attributes { handle.span.setAttribute(key: key, value: value) }
        handle.span.end()
    }

    // MARK: - Instant events

    /// Emits a zero-duration span (instantaneous event). Pass a `parent` handle to make
    /// this span a child of an in-progress trace.
    func record(
        _ name: String,
        parent: SpanHandle? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        attributes: [String: String] = [:]
    ) {
        AppLog.log(name, level: .debug, attributes: attributes)
        let (tracer, captureEnabled) = lock.withLock { (_isEnabled ? _tracer : nil, _testCaptureEnabled) }
        if captureEnabled {
            lock.withLock { _recordedEventsForTesting.append((name: name, attributes: attributes)) }
        }
        guard let tracer else { return }
        let builder = tracer.spanBuilder(spanName: name)
        if let startTime { _ = builder.setStartTime(time: startTime) }
        if let parent { _ = builder.setParent(parent.span.context) }
        let span = builder.startSpan()
        for (key, value) in attributes { span.setAttribute(key: key, value: value) }
        if let endTime {
            span.end(time: endTime)
        } else {
            span.end()
        }
    }

    // MARK: - Scoped spans

    /// Wraps a synchronous throwing body in a span. Pass a `parent` handle to make this
    /// span a child of an in-progress trace.
    @discardableResult
    func withSpan<T: Sendable>(
        _ name: String,
        parent: SpanHandle? = nil,
        attributes: [String: String] = [:],
        _ body: () throws -> T
    ) rethrows -> T {
        AppLog.log(name, level: .debug, attributes: attributes)
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else {
            return try body()
        }
        let builder = tracer.spanBuilder(spanName: name)
        if let parent { _ = builder.setParent(parent.span.context) }
        return try builder.withActiveSpan { span in
            for (key, value) in attributes { span.setAttribute(key: key, value: value) }
            return try body()
        }
    }

    /// Wraps an async throwing body in a span. Pass a `parent` handle to make this
    /// span a child of an in-progress trace.
    @discardableResult
    @MainActor
    func withSpan<T: Sendable>(
        _ name: String,
        parent: SpanHandle? = nil,
        attributes: [String: String] = [:],
        _ body: @MainActor @Sendable () async throws -> T
    ) async rethrows -> T {
        AppLog.log(name, level: .debug, attributes: attributes)
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else {
            return try await body()
        }
        let builder = tracer.spanBuilder(spanName: name)
        if let parent { _ = builder.setParent(parent.span.context) }
        let span = builder.startSpan()
        for (key, value) in attributes { span.setAttribute(key: key, value: value) }
        do {
            let result = try await body()
            span.end()
            return result
        } catch {
            span.end()
            throw error
        }
    }
}
