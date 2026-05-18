import Foundation
import OpenTelemetrySdk

/// Captures exported spans into `TraceStore.shared` for the in-app observability dashboard.
final class MemorySpanExporter: SpanExporter {
    @discardableResult
    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        let stored = spans.map { spanData -> StoredSpan in
            let startMs = Int64(spanData.startTime.timeIntervalSince1970 * 1000)
            let endMs = Int64(spanData.endTime.timeIntervalSince1970 * 1000)
            var attrs: [String: String] = [:]
            for (key, value) in spanData.attributes {
                switch value {
                case .string(let s): attrs[key] = s
                case .bool(let b): attrs[key] = String(b)
                case .int(let i): attrs[key] = String(i)
                case .double(let d): attrs[key] = String(d)
                default: attrs[key] = value.description
                }
            }
            return StoredSpan(
                name: spanData.name,
                traceId: spanData.traceId.hexString,
                spanId: spanData.spanId.hexString,
                startEpochMs: startMs,
                endEpochMs: endMs,
                attributes: attrs
            )
        }
        DispatchQueue.main.async {
            TraceStore.shared.append(contentsOf: stored)
        }
        return .success
    }

    @discardableResult
    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode { .success }

    func shutdown(explicitTimeout: TimeInterval?) {}
}
