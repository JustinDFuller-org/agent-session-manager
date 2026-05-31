import Foundation
import OpenTelemetrySdk

/// Routes spans to per-pane JSONL files under `tracesDirectory`.
///
/// Spans with a `pane.id` attribute go to
///   `<tracesDirectory>/<tab.name>-<tab.id[..<8]>/<pane.name>-<pane.id[..<8]>.jsonl`
/// Spans without `pane.id` go to `<tracesDirectory>/_global/global.jsonl`.
///
/// Each file begins with a JSON metadata line (written once), followed by one span JSON
/// object per line. Files are trimmed from the top when they exceed `maxBytesPerFile`.
final class PerPaneSpanExporter: SpanExporter {
    let tracesDirectory: URL
    private let maxBytesPerFile: Int
    private let queue = DispatchQueue(
        label: "com.justinfuller.agent-session-manager.per-pane-exporter",
        qos: .utility
    )
    // paneId (or "_global") → (fileURL, metadataWritten)
    private var writers: [String: (fileURL: URL, metadataWritten: Bool)] = [:]

    init(tracesDirectory: URL, maxBytesPerFile: Int) {
        self.tracesDirectory = tracesDirectory
        self.maxBytesPerFile = max(1_048_576, maxBytesPerFile)
    }

    @discardableResult
    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        // Group spans by pane.id attribute (or "_global" bucket)
        var groups: [String: [SpanData]] = [:]
        for span in spans {
            let key: String
            if case .string(let id) = span.attributes["pane.id"] {
                key = id
            } else {
                key = "_global"
            }
            groups[key, default: []].append(span)
        }

        for (key, groupSpans) in groups {
            let representative = groupSpans[0]
            let fileURL = resolveFileURL(for: key, span: representative)

            let needsMetadata = writers[key] == nil || !writers[key]!.metadataWritten
            let metadataLine: String? = needsMetadata ? makeMetadataLine(key: key, span: representative) : nil

            if writers[key] == nil {
                writers[key] = (fileURL: fileURL, metadataWritten: false)
            }
            writers[key]!.metadataWritten = true

            let spanLines = groupSpans.compactMap { spanToJSON($0) }
            guard !spanLines.isEmpty || metadataLine != nil else { continue }

            var payload = ""
            if let meta = metadataLine { payload += meta + "\n" }
            if !spanLines.isEmpty { payload += spanLines.joined(separator: "\n") + "\n" }
            let data = Data(payload.utf8)
            let maxBytes = maxBytesPerFile

            queue.async { [fileURL] in
                Self.writeSync(data: data, to: fileURL, maxBytes: maxBytes)
            }
        }
        return .success
    }

    @discardableResult
    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode { .success }

    func shutdown(explicitTimeout: TimeInterval?) {}

    // MARK: - Private helpers

    private func resolveFileURL(for key: String, span: SpanData) -> URL {
        if let existing = writers[key] { return existing.fileURL }

        if key == "_global" {
            return
                tracesDirectory
                .appendingPathComponent("_global", isDirectory: true)
                .appendingPathComponent("global.jsonl")
        }

        let paneId = key
        let tabId: String
        let tabName: String
        let paneName: String

        if case .string(let val) = span.attributes["tab.id"] { tabId = val } else { tabId = "unknown" }
        if case .string(let val) = span.attributes["tab.name"] { tabName = val } else { tabName = "unknown" }
        if case .string(let val) = span.attributes["pane.name"] { paneName = val } else { paneName = "unknown" }

        let tabDirName = sanitize("\(tabName)-\(String(tabId.prefix(8)))")
        let fileName = sanitize("\(paneName)-\(String(paneId.prefix(8))).jsonl")

        return
            tracesDirectory
            .appendingPathComponent(tabDirName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private func makeMetadataLine(key: String, span: SpanData) -> String {
        let now = ISO8601DateFormatter().string(from: Date())

        if key == "_global" {
            return """
                {"_type":"metadata","paneId":"_global","paneName":"global","tabId":"_global","tabName":"_global","createdAt":"\(now)"}
                """
        }

        let paneId = key
        let tabId = attributeString(span, "tab.id") ?? ""
        let tabName = attributeString(span, "tab.name") ?? ""
        let paneName = attributeString(span, "pane.name") ?? ""

        return """
            {"_type":"metadata","paneId":"\(jsonEscape(paneId))","paneName":"\(jsonEscape(paneName))","tabId":"\(jsonEscape(tabId))","tabName":"\(jsonEscape(tabName))","createdAt":"\(now)"}
            """
    }

    private func attributeString(_ span: SpanData, _ key: String) -> String? {
        guard case .string(let val) = span.attributes[key] else { return nil }
        return val
    }

    private func sanitize(_ str: String) -> String {
        str.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.")).inverted)
            .joined(separator: "_")
    }

    private func spanToJSON(_ span: SpanData) -> String? {
        let startMs = span.startTime.timeIntervalSince1970 * 1000
        let endMs = span.endTime.timeIntervalSince1970 * 1000
        let durationMs = endMs - startMs

        var attrs: [String: String] = [:]
        for (key, value) in span.attributes {
            switch value {
            case .string(let str): attrs[key] = str
            case .bool(let bool): attrs[key] = String(bool)
            case .int(let i): attrs[key] = String(i)
            case .double(let double): attrs[key] = String(double)
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

        let parentSpanId = span.parentSpanId?.hexString ?? ""
        let parentField = parentSpanId.isEmpty ? "" : ",\"parentSpanId\":\"\(parentSpanId)\""

        return """
            {"name":"\(jsonEscape(span.name))","traceId":"\(span.traceId.hexString)","spanId":"\(span.spanId.hexString)"\(parentField),"startEpochMs":\(Int64(startMs)),"endEpochMs":\(Int64(endMs)),"durationMs":\(Int64(durationMs)),"attributes":\(attrsJSON)}
            """
    }

    private func jsonEscape(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
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
        try? JSONLTrimmer.trimIfNeeded(
            at: url,
            maxBytes: maxBytes,
            marker: "--- [truncated older trace entries] ---"
        )
    }

    static func trimIfNeeded(at url: URL, maxBytes: Int) {
        try? JSONLTrimmer.trimIfNeeded(
            at: url,
            maxBytes: maxBytes,
            marker: "--- [truncated older trace entries] ---"
        )
    }
}
