import Foundation
import OpenTelemetrySdk

/// Writes spans as JSON-Lines to a bounded file. When the file exceeds `maxBytes`,
/// the oldest content is trimmed from the beginning on a newline boundary.
final class FileSpanExporter: SpanExporter {
    private let fileURL: URL
    private let maxBytes: Int
    private let queue = DispatchQueue(
        label: "com.justinfuller.agent-session-manager.trace-file",
        qos: .utility
    )

    init(fileURL: URL, maxBytes: Int) {
        self.fileURL = fileURL
        self.maxBytes = max(1_048_576, maxBytes)
    }

    @discardableResult
    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        let lines = spans.compactMap { spanToJSON($0) }
        guard !lines.isEmpty else { return .success }
        let payload = lines.joined(separator: "\n") + "\n"
        let data = Data(payload.utf8)
        queue.async { [fileURL, maxBytes] in
            Self.writeSync(data: data, to: fileURL, maxBytes: maxBytes)
        }
        return .success
    }

    @discardableResult
    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode { .success }

    func shutdown(explicitTimeout: TimeInterval?) {}

    private func spanToJSON(_ span: SpanData) -> String? {
        let startMs = span.startTime.timeIntervalSince1970 * 1000
        let endMs = span.endTime.timeIntervalSince1970 * 1000
        let durationMs = endMs - startMs

        var attrs: [String: String] = [:]
        for (key, value) in span.attributes {
            switch value {
            case .string(let s): attrs[key] = s
            case .bool(let b): attrs[key] = String(b)
            case .int(let i): attrs[key] = String(i)
            case .double(let d): attrs[key] = String(d)
            default: attrs[key] = value.description
            }
        }

        let attrsJSON: String
        if attrs.isEmpty {
            attrsJSON = "{}"
        } else {
            let pairs = attrs.sorted { $0.key < $1.key }
                .map { "\"\(jsonEscape($0.key))\":\"\(jsonEscape($0.value))\"" }
                .joined(separator: ",")
            attrsJSON = "{\(pairs)}"
        }

        return """
            {"name":"\(jsonEscape(span.name))","traceId":"\(span.traceId.hexString)","spanId":"\(span.spanId.hexString)","startEpochMs":\(Int64(startMs)),"endEpochMs":\(Int64(endMs)),"durationMs":\(Int64(durationMs)),"attributes":\(attrsJSON)}
            """
    }

    private func jsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private static func writeSync(data: Data, to url: URL, maxBytes: Int) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            return
        }
        trimIfNeeded(at: url, maxBytes: maxBytes)
    }

    private static func trimIfNeeded(at url: URL, maxBytes: Int) {
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = (attrs[.size] as? NSNumber)?.intValue,
            size > maxBytes
        else { return }
        guard let existing = try? Data(contentsOf: url), !existing.isEmpty else { return }

        let targetKeep = maxBytes - 512
        let dropCount = max(0, existing.count - targetKeep)
        var cut = dropCount
        while cut < existing.count, existing[cut] != UInt8(ascii: "\n") { cut += 1 }
        if cut < existing.count { cut += 1 }

        var newData = Data("--- [truncated older trace entries] ---\n".utf8)
        if cut < existing.count { newData.append(existing[cut...]) }
        try? newData.write(to: url, options: .atomic)
    }
}
