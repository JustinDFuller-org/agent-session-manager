import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

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

        let exporter: any SpanExporter = PerPaneSpanExporter(
            tracesDirectory: settings.resolvedTracingDirectoryURL,
            maxBytesPerFile: AppSettings.debugFileMaxBytes
        )

        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let provider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()

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
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else { return nil }
        let span = tracer.spanBuilder(spanName: name).startSpan()
        for (key, value) in attributes { span.setAttribute(key: key, value: value) }
        return SpanHandle(span)
    }

    /// Ends a span previously started with ``startSpan(_:attributes:)``.
    /// Passing `nil` is a no-op, so callers can hold optional handles without guarding.
    func end(handle: SpanHandle?, attributes: [String: String] = [:]) {
        guard let handle else { return }
        for (key, value) in attributes { handle.span.setAttribute(key: key, value: value) }
        handle.span.end()
    }

    // MARK: - Instant events

    /// Emits a zero-duration span (instantaneous event). Pass a `parent` handle to make
    /// this span a child of an in-progress trace.
    func record(_ name: String, parent: SpanHandle? = nil, attributes: [String: String] = [:]) {
        let (tracer, captureEnabled) = lock.withLock { (_isEnabled ? _tracer : nil, _testCaptureEnabled) }
        if captureEnabled {
            lock.withLock { _recordedEventsForTesting.append((name: name, attributes: attributes)) }
        }
        guard let tracer else { return }
        let builder = tracer.spanBuilder(spanName: name)
        if let parent { _ = builder.setParent(parent.span.context) }
        let span = builder.startSpan()
        for (key, value) in attributes { span.setAttribute(key: key, value: value) }
        span.end()
    }

    // MARK: - Scoped spans

    /// Wraps a synchronous throwing body in a span. Pass a `parent` handle to make this
    /// span a child of an in-progress trace.
    @discardableResult
    func withSpan<T>(
        _ name: String,
        parent: SpanHandle? = nil,
        attributes: [String: String] = [:],
        _ body: () throws -> T
    ) rethrows -> T {
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
    func withSpan<T>(
        _ name: String,
        parent: SpanHandle? = nil,
        attributes: [String: String] = [:],
        _ body: () async throws -> T
    ) async rethrows -> T {
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else {
            return try await body()
        }
        let builder = tracer.spanBuilder(spanName: name)
        if let parent { _ = builder.setParent(parent.span.context) }
        return try await builder.withActiveSpan { span in
            for (key, value) in attributes { span.setAttribute(key: key, value: value) }
            return try await body()
        }
    }

    // MARK: - Explicit-timing spans

    /// Emits a span with explicit start and end times, for callback-based async operations
    /// where the span cannot wrap the body directly. Pass a `parent` handle to make this
    /// span a child of an in-progress trace.
    func recordSpan(
        _ name: String,
        parent: SpanHandle? = nil,
        startTime: Date,
        endTime: Date,
        attributes: [String: String] = [:]
    ) {
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else { return }
        let builder = tracer.spanBuilder(spanName: name).setStartTime(time: startTime)
        if let parent { _ = builder.setParent(parent.span.context) }
        let span = builder.startSpan()
        for (key, value) in attributes { span.setAttribute(key: key, value: value) }
        span.end(time: endTime)
    }
}
