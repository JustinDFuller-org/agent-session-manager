import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter

/// Output target for span data.
enum TracingOutputTarget: String, Codable, CaseIterable {
    case stdout
    case file

    var displayName: String { rawValue.capitalized }
}

/// Thin wrapper around the OpenTelemetry Swift SDK. Thread-safe; callers on any actor may use it.
final class TracingService: @unchecked Sendable {
    static let shared = TracingService()

    private let lock = NSLock()
    private var _isEnabled = false
    private var _tracer: (any Tracer)?

    private init() {}

    var isEnabled: Bool {
        lock.withLock { _isEnabled }
    }

    /// Call on startup and whenever tracing settings change. Must be called from the main actor
    /// (AppSettings is @MainActor), but reconfigures the underlying SDK on whatever thread called it.
    @MainActor
    func configure(from settings: AppSettings) {
        guard settings.tracingEnabled else {
            lock.withLock {
                _isEnabled = false
                _tracer = nil
            }
            return
        }

        let exporter: any SpanExporter
        switch settings.tracingOutputTarget {
        case .stdout:
            exporter = StdoutExporter(isDebug: false)
        case .file:
            exporter = FileSpanExporter(
                fileURL: settings.resolvedTracingFileURL,
                maxBytes: settings.tracingFileMaxBytes
            )
        }

        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let memoryProcessor = SimpleSpanProcessor(spanExporter: MemorySpanExporter())
        let provider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .add(spanProcessor: memoryProcessor)
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

    /// Emits a zero-duration span (instantaneous event).
    func record(_ name: String, attributes: [String: String] = [:]) {
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else { return }
        var span = tracer.spanBuilder(spanName: name).startSpan()
        for (key, value) in attributes {
            span.setAttribute(key: key, value: value)
        }
        span.end()
    }

    /// Wraps a synchronous throwing body in a span.
    @discardableResult
    func withSpan<T>(
        _ name: String,
        attributes: [String: String] = [:],
        _ body: () throws -> T
    ) rethrows -> T {
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else {
            return try body()
        }
        var span = tracer.spanBuilder(spanName: name).startSpan()
        defer { span.end() }
        for (key, value) in attributes {
            span.setAttribute(key: key, value: value)
        }
        return try body()
    }

    /// Wraps an async throwing body in a span.
    @discardableResult
    func withSpan<T>(
        _ name: String,
        attributes: [String: String] = [:],
        _ body: () async throws -> T
    ) async rethrows -> T {
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else {
            return try await body()
        }
        var span = tracer.spanBuilder(spanName: name).startSpan()
        defer { span.end() }
        for (key, value) in attributes {
            span.setAttribute(key: key, value: value)
        }
        return try await body()
    }

    /// Emits a span with explicit start and end times, for callback-based async operations
    /// where the span cannot wrap the body directly.
    func recordSpan(_ name: String, startTime: Date, endTime: Date, attributes: [String: String] = [:]) {
        guard let tracer = lock.withLock({ _isEnabled ? _tracer : nil }) else { return }
        var span = tracer.spanBuilder(spanName: name)
            .setStartTime(time: startTime)
            .startSpan()
        for (key, value) in attributes {
            span.setAttribute(key: key, value: value)
        }
        span.end(time: endTime)
    }
}
