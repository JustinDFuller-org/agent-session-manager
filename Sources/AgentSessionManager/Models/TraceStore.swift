import Foundation
import Observation

struct StoredSpan: Identifiable {
    let id: UUID
    let name: String
    let traceId: String
    let spanId: String
    let parentSpanId: String?
    let startEpochMs: Int64
    let endEpochMs: Int64
    let durationMs: Int64
    let attributes: [String: String]

    init(
        name: String,
        traceId: String,
        spanId: String,
        parentSpanId: String?,
        startEpochMs: Int64,
        endEpochMs: Int64,
        attributes: [String: String]
    ) {
        self.id = UUID()
        self.name = name
        self.traceId = traceId
        self.spanId = spanId
        self.parentSpanId = parentSpanId
        self.startEpochMs = startEpochMs
        self.endEpochMs = endEpochMs
        self.durationMs = endEpochMs - startEpochMs
        self.attributes = attributes
    }
}

@Observable
@MainActor
final class TraceStore {
    static let shared = TraceStore()

    private(set) var spans: [StoredSpan] = []
    var maxSpans: Int = 500

    private init() {}

    func append(contentsOf newSpans: [StoredSpan]) {
        spans.append(contentsOf: newSpans)
        if spans.count > maxSpans {
            spans.removeFirst(spans.count - maxSpans)
        }
    }

    func clear() {
        spans = []
    }
}
